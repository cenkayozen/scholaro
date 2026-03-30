import 'dart:async';
import 'dart:io' show File, zlib;
import 'dart:math' show max;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfImportResult {
  final String fullName;
  final String schoolNumber;
  final Uint8List? photo; // image bytes extracted from PDF, may be null

  PdfImportResult({
    required this.fullName,
    required this.schoolNumber,
    this.photo,
  });
}

class PdfImportService {
  /// Extracts all raw text from a PDF, page by page.
  Future<String> extractRawText(File file) async {
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);
    final buffer = StringBuffer();

    for (int i = 0; i < document.pages.count; i++) {
      final text = extractor.extractText(startPageIndex: i, endPageIndex: i);
      buffer.writeln(text);
    }

    document.dispose();
    return buffer.toString();
  }

  /// Tries to auto-parse students from PDF text and matches their photos.
  Future<List<PdfImportResult>> importStudentsFromPdf(File file) async {
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);

    // ── Text extraction ──────────────────────────────────────────
    final extractor = PdfTextExtractor(document);
    final buffer = StringBuffer();
    for (int i = 0; i < document.pages.count; i++) {
      buffer.writeln(extractor.extractText(startPageIndex: i, endPageIndex: i));
    }
    final students = parseText(buffer.toString());

    document.dispose();

    // ── Image extraction: find FlateDecode image streams in raw PDF bytes ──
    final photos = await _extractPhotos(bytes, students.length);

    // ── Merge: match photo[i] → student[i] by position order ─────
    return List.generate(students.length, (i) {
      final s = students[i];
      return PdfImportResult(
        fullName: s.fullName,
        schoolNumber: s.schoolNumber,
        photo: i < photos.length ? photos[i] : null,
      );
    });
  }

  // ── PDF FlateDecode image extraction ───────────────────────────────────────
  //
  // E-okul PDFs store student photos as FlateDecode (zlib-compressed raw pixel)
  // XObject Image streams — there are no JPEG/PNG markers in the raw bytes.
  // This method:
  //   1. Finds every PDF stream object that has /Subtype /Image + /FlateDecode
  //   2. Extracts width, height, channels, predictor from its dictionary
  //   3. Decompresses the stream with dart:io's zlib decoder
  //   4. Applies the PNG row-filter (predictor ≥ 10) to recover raw pixels
  //   5. Converts the RGBA pixel array to a PNG via dart:ui
  // Results are returned in file-offset order (= top-to-bottom page order).

  Future<List<Uint8List>> _extractPhotos(
      Uint8List pdfBytes, int expectedCount) async {
    // ── Step 1: Build ColorSpace-object → RGB-palette cache ──────────────
    // E-okul PDFs use /Indexed /DeviceRGB color spaces.
    // The image dict says  /ColorSpace 16 0 R
    // Object 16 says       [ /Indexed /DeviceRGB 255 17 0 R ]
    // Object 17 holds the  FlateDecode-compressed 256×3-byte palette.
    final paletteCache = _buildPaletteCache(pdfBytes);

    // ── Step 2: Find every FlateDecode image stream ───────────────────────
    final infos = <_PdfImageInfo>[];
    int pos = 0;

    while (pos < pdfBytes.length - 10) {
      final sPos = _findSeq(pdfBytes, _kStream, pos);
      if (sPos == -1) break;

      // 'stream' must be followed by \n or \r\n
      int dataStart;
      if (sPos + 6 < pdfBytes.length && pdfBytes[sPos + 6] == 10) {
        dataStart = sPos + 7;
      } else if (sPos + 7 < pdfBytes.length &&
          pdfBytes[sPos + 6] == 13 &&
          pdfBytes[sPos + 7] == 10) {
        dataStart = sPos + 8;
      } else {
        pos = sPos + 6;
        continue;
      }

      final esPos = _findSeq(pdfBytes, _kEndStream, dataStart);
      if (esPos == -1) break;

      // Dictionary text immediately before 'stream'
      final dictFrom = max(0, sPos - 1500);
      final dictStr = String.fromCharCodes(
          pdfBytes.sublist(dictFrom, sPos).map((b) => (b >= 32 && b < 128) ? b : 32));

      if (dictStr.contains('Image') && dictStr.contains('FlateDecode')) {
        final width = _dictInt(dictStr, 'Width');
        final height = _dictInt(dictStr, 'Height');

        if (width != null && height != null && width >= 20 && height >= 20) {
          final predictor = _dictInt(dictStr, 'Predictor') ?? 1;
          final bpc = _dictInt(dictStr, 'BitsPerComponent') ?? 8;

          // ── Detect color space ──
          int channels = 3; // default DeviceRGB
          List<int>? palette;

          final csRef = _dictInt(dictStr, 'ColorSpace'); // numeric obj ref
          if (csRef != null && paletteCache.containsKey(csRef)) {
            // Indexed color: each pixel is a 1-byte palette index
            channels = 1;
            palette = paletteCache[csRef];
          } else if (dictStr.contains('DeviceGray') ||
              dictStr.contains('CalGray')) {
            channels = 1;
          } else if (dictStr.contains('DeviceCMYK')) {
            channels = 4;
          }

          // Trim trailing whitespace from stream data
          int dataEnd = esPos;
          while (dataEnd > dataStart &&
              (pdfBytes[dataEnd - 1] == 10 ||
                  pdfBytes[dataEnd - 1] == 13 ||
                  pdfBytes[dataEnd - 1] == 32)) {
            dataEnd--;
          }

          infos.add(_PdfImageInfo(
            fileOffset: sPos,
            width: width,
            height: height,
            channels: channels,
            palette: palette,
            predictor: predictor,
            bpc: bpc,
            compressed:
                Uint8List.fromList(pdfBytes.sublist(dataStart, dataEnd)),
          ));
        }
      }

      pos = esPos + _kEndStream.length;
    }

    infos.sort((a, b) => a.fileOffset.compareTo(b.fileOffset));
    debugPrint(
        'PDF photo extraction: ${infos.length} image streams found');

    // ── Step 3: Decode each image to PNG bytes ────────────────────────────
    final photos = <Uint8List>[];
    for (final info in infos) {
      try {
        final png = await _flatDecodeImageToPng(info);
        if (png != null) photos.add(png);
      } catch (e) {
        debugPrint(
            'Image decode failed (${info.width}×${info.height}): $e');
      }
    }
    return photos;
  }

  /// Scans the PDF for Indexed color-space objects and returns a map of
  /// colorspace-object-number → decompressed RGB palette bytes (256 × 3).
  Map<int, List<int>> _buildPaletteCache(Uint8List pdfBytes) {
    final cache = <int, List<int>>{};

    // Find all "N 0 obj" declarations
    int pos = 0;
    while (pos < pdfBytes.length - 10) {
      // Locate " 0 obj" (space zero space obj)
      final declPos =
          _findSeq(pdfBytes, [32, 48, 32, 111, 98, 106], pos); // ' 0 obj'
      if (declPos == -1) break;

      // Extract object number (digits immediately before the space)
      int numEnd = declPos - 1;
      int numStart = numEnd;
      while (numStart > 0 &&
          pdfBytes[numStart - 1] >= 48 &&
          pdfBytes[numStart - 1] <= 57) {
        numStart--;
      }
      final objNum =
          int.tryParse(String.fromCharCodes(pdfBytes.sublist(numStart, numEnd + 1)));

      if (objNum != null) {
        // Read up to 300 bytes of object content
        final contentEnd = (declPos + 6 + 300).clamp(0, pdfBytes.length);
        final content = String.fromCharCodes(pdfBytes
            .sublist(declPos + 6, contentEnd)
            .map((b) => (b >= 32 && b < 128) ? b : 32));

        // Is this an Indexed color space definition?
        // Looks like: [ /Indexed /DeviceRGB 255 17 0 R ]
        final m = RegExp(
                r'/Indexed\s+/DeviceRGB\s+\d+\s+(\d+)\s+0\s+R')
            .firstMatch(content);
        if (m != null) {
          final palObjNum = int.tryParse(m.group(1)!);
          if (palObjNum != null) {
            final palette = _extractStreamBytes(pdfBytes, palObjNum);
            if (palette != null) cache[objNum] = palette;
          }
        }
      }

      pos = declPos + 6;
    }

    debugPrint('PDF palette cache: ${cache.length} indexed color spaces');
    return cache;
  }

  /// Extracts and decompresses the stream data from object [objNum].
  List<int>? _extractStreamBytes(Uint8List pdfBytes, int objNum) {
    // Find "objNum 0 obj"
    final marker = '$objNum 0 obj';
    final mBytes = marker.codeUnits;
    final objPos = _findSeq(pdfBytes, mBytes, 0);
    if (objPos == -1) return null;

    // Find 'stream' after this object declaration
    final sPos = _findSeq(pdfBytes, _kStream, objPos);
    if (sPos == -1 || sPos > objPos + 500) return null;

    int dataStart;
    if (sPos + 6 < pdfBytes.length && pdfBytes[sPos + 6] == 10) {
      dataStart = sPos + 7;
    } else if (sPos + 7 < pdfBytes.length &&
        pdfBytes[sPos + 6] == 13 &&
        pdfBytes[sPos + 7] == 10) {
      dataStart = sPos + 8;
    } else {
      return null;
    }

    final esPos = _findSeq(pdfBytes, _kEndStream, dataStart);
    if (esPos == -1) return null;

    int dataEnd = esPos;
    while (dataEnd > dataStart &&
        (pdfBytes[dataEnd - 1] == 10 ||
            pdfBytes[dataEnd - 1] == 13 ||
            pdfBytes[dataEnd - 1] == 32)) {
      dataEnd--;
    }

    final data = pdfBytes.sublist(dataStart, dataEnd);

    // Check for FlateDecode filter
    final dictStr = String.fromCharCodes(
        pdfBytes
            .sublist(max(0, sPos - 300), sPos)
            .map((b) => (b >= 32 && b < 128) ? b : 32));

    if (dictStr.contains('FlateDecode')) {
      try {
        return zlib.decoder.convert(data);
      } catch (_) {
        return null;
      }
    }
    return List<int>.from(data);
  }

  Future<Uint8List?> _flatDecodeImageToPng(_PdfImageInfo info) async {
    // Decompress FlateDecode (zlib)
    late List<int> raw;
    try {
      raw = zlib.decoder.convert(info.compressed);
    } catch (e) {
      debugPrint('zlib fail: $e');
      return null;
    }

    final w = info.width;
    final h = info.height;
    final c = info.channels;

    // Apply PNG row-filter unfiltering when predictor ≥ 10
    final List<int> pixels =
        info.predictor >= 10 ? _pngUnfilter(raw, w, h, c) : raw;

    // Convert to RGBA (4 bytes per pixel)
    final rgba = Uint8List(w * h * 4);

    if (info.palette != null) {
      // ── Indexed color: pixel = palette index ──────────────────────────
      final pal = info.palette!;
      for (int i = 0; i < w * h; i++) {
        if (i >= pixels.length) break;
        final idx = pixels[i] & 0xFF;
        final base = idx * 3;
        rgba[i * 4] = base < pal.length ? pal[base] & 0xFF : 0;
        rgba[i * 4 + 1] = base + 1 < pal.length ? pal[base + 1] & 0xFF : 0;
        rgba[i * 4 + 2] = base + 2 < pal.length ? pal[base + 2] & 0xFF : 0;
        rgba[i * 4 + 3] = 255;
      }
    } else {
      // ── Direct color: DeviceRGB / DeviceGray / DeviceCMYK ────────────
      for (int i = 0; i < w * h; i++) {
        final src = i * c;
        if (src + c > pixels.length) break;
        if (c == 1) {
          final v = pixels[src] & 0xFF;
          rgba[i * 4] = v;
          rgba[i * 4 + 1] = v;
          rgba[i * 4 + 2] = v;
          rgba[i * 4 + 3] = 255;
        } else if (c == 3) {
          rgba[i * 4] = pixels[src] & 0xFF;
          rgba[i * 4 + 1] = pixels[src + 1] & 0xFF;
          rgba[i * 4 + 2] = pixels[src + 2] & 0xFF;
          rgba[i * 4 + 3] = 255;
        } else if (c == 4) {
          final cm = pixels[src] / 255.0;
          final m = pixels[src + 1] / 255.0;
          final y = pixels[src + 2] / 255.0;
          final k = pixels[src + 3] / 255.0;
          rgba[i * 4] = ((1 - cm) * (1 - k) * 255).round().clamp(0, 255);
          rgba[i * 4 + 1] = ((1 - m) * (1 - k) * 255).round().clamp(0, 255);
          rgba[i * 4 + 2] = ((1 - y) * (1 - k) * 255).round().clamp(0, 255);
          rgba[i * 4 + 3] = 255;
        }
      }
    }

    // Encode to PNG via dart:ui
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
        rgba, w, h, ui.PixelFormat.rgba8888, completer.complete);
    final image = await completer.future;
    final bd = await image.toByteData(format: ui.ImageByteFormat.png);
    return bd?.buffer.asUint8List();
  }

  /// PNG row-filter "unfilter" — strips the leading filter-type byte from
  /// each row and reconstructs the original pixel values.
  List<int> _pngUnfilter(List<int> data, int w, int h, int c) {
    final bpr = w * c; // bytes per row (assuming 8 bpc)
    final result = List<int>.filled(bpr * h, 0);
    final prev = List<int>.filled(bpr, 0);
    int pos = 0;

    for (int y = 0; y < h; y++) {
      if (pos >= data.length) break;
      final ft = data[pos++]; // filter type byte
      final curr = List<int>.filled(bpr, 0);

      for (int x = 0; x < bpr; x++) {
        if (pos >= data.length) break;
        final raw = data[pos++] & 0xFF;
        final a = x < c ? 0 : curr[x - c];
        final b = prev[x];
        final cc = x < c ? 0 : prev[x - c];
        curr[x] = switch (ft) {
          0 => raw,
          1 => (raw + a) & 0xFF,
          2 => (raw + b) & 0xFF,
          3 => (raw + ((a + b) >> 1)) & 0xFF,
          4 => (raw + _paeth(a, b, cc)) & 0xFF,
          _ => raw,
        };
      }
      result.setRange(y * bpr, (y + 1) * bpr, curr);
      prev.setAll(0, curr);
    }
    return result;
  }

  int _paeth(int a, int b, int c) {
    final p = a + b - c;
    final pa = (p - a).abs();
    final pb = (p - b).abs();
    final pc = (p - c).abs();
    if (pa <= pb && pa <= pc) return a;
    if (pb <= pc) return b;
    return c;
  }

  // ── Byte-search helpers ──────────────────────────────────────────────────
  static final _kStream = [115, 116, 114, 101, 97, 109]; // 'stream'
  static final _kEndStream = [
    101, 110, 100, 115, 116, 114, 101, 97, 109
  ]; // 'endstream'

  int _findSeq(Uint8List data, List<int> seq, int from) {
    outer:
    for (int i = from; i <= data.length - seq.length; i++) {
      for (int j = 0; j < seq.length; j++) {
        if (data[i + j] != seq[j]) continue outer;
      }
      return i;
    }
    return -1;
  }

  int? _dictInt(String dict, String key) {
    final m = RegExp('/$key\\s+(\\d+)').firstMatch(dict);
    return m != null ? int.tryParse(m.group(1)!) : null;
  }

  /// Parses raw text into student records.
  /// Supports multiple formats from e-okul / Turkish school PDFs.
  List<PdfImportResult> parseText(String text) {
    final results = <PdfImportResult>[];

    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // Strategy 1: try to parse line by line
    for (final line in lines) {
      if (_isHeaderLine(line)) {
        // Even if it's a header line, the student name might be
        // appended at the end (e.g. "PROGRAMI)MUSTAFA ÇETİN933")
        // Try to extract the trailing part after ) or last keyword
        final cleaned = line
            .replaceAll(RegExp(r'^.*[)\]]'), '')
            .replaceAll(RegExp(
                r'^.*(PROGRAMI|MÜDÜRLÜ|LİSESİ|VALİLİĞİ|OKULU|SINIFI|ŞUBESİ)',
                caseSensitive: false), '')
            .trim();
        if (cleaned.isNotEmpty) {
          final parsed = _parseLine(cleaned);
          if (parsed != null) results.add(parsed);
        }
        continue;
      }
      final parsed = _parseLine(line);
      if (parsed != null) results.add(parsed);
    }

    // Strategy 2: if Strategy 1 found nothing,
    // try pairing consecutive lines (name line + number line)
    if (results.isEmpty) {
      final filtered = lines.where((l) => !_isHeaderLine(l)).toList();
      for (int i = 0; i < filtered.length - 1; i++) {
        final a = filtered[i];
        final b = filtered[i + 1];
        // name on one line, number on next
        if (_isAllCapsName(a) && RegExp(r'^\d{2,10}$').hasMatch(b)) {
          if (_isValidName(a)) {
            results.add(PdfImportResult(fullName: _cleanName(a), schoolNumber: b));
            i++; // skip next line
          }
        }
        // number on one line, name on next
        else if (RegExp(r'^\d{2,10}$').hasMatch(a) && _isAllCapsName(b)) {
          if (_isValidName(b)) {
            results.add(PdfImportResult(fullName: _cleanName(b), schoolNumber: a));
            i++;
          }
        }
      }
    }

    // Remove duplicates
    final seen = <String>{};
    return results.where((r) {
      final key = '${r.schoolNumber}_${r.fullName}';
      return seen.add(key);
    }).toList();
  }

  PdfImportResult? _parseLine(String line) {
    // ── Format A: "1  MUSTAFA ÇETİN  933"
    // row_index + ALL-CAPS name + number at end  ← e-okul fotoğraflı liste
    final pA = RegExp(
      r'^\d{1,3}\s+([A-ZÇĞİÖŞÜ][A-ZÇĞİÖŞÜa-zçğışöüI]+(?:\s+[A-ZÇĞİÖŞÜ][A-ZÇĞİÖŞÜa-zçğışöüI]+)+)\s+(\d{2,10})\s*$',
    );
    final mA = pA.firstMatch(line);
    if (mA != null) {
      final name = _cleanName(mA.group(1)!);
      final number = mA.group(2)!;
      if (_isValidName(name)) {
        return PdfImportResult(fullName: name, schoolNumber: number);
      }
    }

    // ── Format B: "MUSTAFA ÇETİN  933"
    // ALL-CAPS name + number at end (no row index)
    final pB = RegExp(
      r'^([A-ZÇĞİÖŞÜ][A-ZÇĞİÖŞÜa-zçğışöüI]+(?:\s+[A-ZÇĞİÖŞÜ][A-ZÇĞİÖŞÜa-zçğışöüI]+)+)\s+(\d{2,10})\s*$',
    );
    final mB = pB.firstMatch(line);
    if (mB != null) {
      final name = _cleanName(mB.group(1)!);
      final number = mB.group(2)!;
      if (_isValidName(name)) {
        return PdfImportResult(fullName: name, schoolNumber: number);
      }
    }

    // ── Format C: "933  MUSTAFA ÇETİN"
    // number at start + name
    final pC = RegExp(
      r'^(\d{2,10})\s+([A-ZÇĞİÖŞÜ][A-ZÇĞİÖŞÜa-zçğışöüI]+(?:\s+[A-ZÇĞİÖŞÜ][A-ZÇĞİÖŞÜa-zçğışöüI]+)+)\s*$',
    );
    final mC = pC.firstMatch(line);
    if (mC != null) {
      final number = mC.group(1)!;
      final name = _cleanName(mC.group(2)!);
      if (_isValidName(name)) {
        return PdfImportResult(fullName: name, schoolNumber: number);
      }
    }

    // ── Format D: "1  933  MUSTAFA ÇETİN"
    // row_index + number + name
    final pD = RegExp(
      r'^\d{1,3}\s+(\d{2,10})\s+([A-ZÇĞİÖŞÜ][A-ZÇĞİÖŞÜa-zçğışöüI]+(?:\s+[A-ZÇĞİÖŞÜ][A-ZÇĞİÖŞÜa-zçğışöüI]+)+)\s*$',
    );
    final mD = pD.firstMatch(line);
    if (mD != null) {
      final number = mD.group(1)!;
      final name = _cleanName(mD.group(2)!);
      if (_isValidName(name)) {
        return PdfImportResult(fullName: name, schoolNumber: number);
      }
    }

    // ── Format E: "MUSTAFA ÇETİN933" — name glued directly to number (no space)
    // This happens when e-okul PDF columns are extracted without separator
    final pE2 = RegExp(
      r'^([A-ZÇĞİÖŞÜ][A-ZÇĞİÖŞÜa-zçğışöüI]+(?:\s+[A-ZÇĞİÖŞÜ][A-ZÇĞİÖŞÜa-zçğışöüI]+)*)(\d{2,10})$',
    );
    final mE2 = pE2.firstMatch(line);
    if (mE2 != null) {
      final name = _cleanName(mE2.group(1)!);
      final number = mE2.group(2)!;
      if (_isValidName(name)) {
        return PdfImportResult(fullName: name, schoolNumber: number);
      }
    }

    // ── Format F: tab-separated
    if (line.contains('\t')) {
      final parts =
          line.split('\t').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
      for (int i = 0; i < parts.length; i++) {
        if (RegExp(r'^\d{2,10}$').hasMatch(parts[i])) {
          final others = [...parts]..removeAt(i);
          final name = _cleanName(others.join(' '));
          if (_isValidName(name)) {
            return PdfImportResult(fullName: name, schoolNumber: parts[i]);
          }
        }
      }
    }

    return null;
  }

  bool _isAllCapsName(String s) {
    return RegExp(
      r'^[A-ZÇĞİÖŞÜ][A-ZÇĞİÖŞÜa-zçğışöüI]+(?:\s+[A-ZÇĞİÖŞÜ][A-ZÇĞİÖŞÜa-zçğışöüI]+)+$',
    ).hasMatch(s);
  }

  bool _isHeaderLine(String line) {
    final skipPatterns = [
      RegExp(r'T\.C\.', caseSensitive: false),
      RegExp(r'VALİLİĞİ', caseSensitive: false),
      RegExp(r'MÜDÜRLÜ', caseSensitive: false),
      RegExp(r'LİSESİ', caseSensitive: false),
      RegExp(r'OKULU', caseSensitive: false),
      RegExp(r'PROGRAMI', caseSensitive: false),
      RegExp(r'ŞUBESİ', caseSensitive: false),
      RegExp(r'SINIFI', caseSensitive: false),
      RegExp(r'HAZİRLIK', caseSensitive: false),
      RegExp(r'AİHL', caseSensitive: false),
      RegExp(r'^\d{2}/\d{2}/\d{4}'),
      RegExp(r'^Sayfa\s*\d+', caseSensitive: false),
      RegExp(r'^Page\s*\d+', caseSensitive: false),
      RegExp(r'^No\s+Ad', caseSensitive: false),
      RegExp(r'^Sıra', caseSensitive: false),
    ];
    return skipPatterns.any((p) => p.hasMatch(line));
  }

  String _cleanName(String name) {
    return name.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  bool _isValidName(String name) {
    final words = name
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 2)
        .toList();
    return words.length >= 2 && name.length >= 5 && name.length <= 70;
  }
}

// ── Internal data class for a detected PDF image stream ──────────────────────
class _PdfImageInfo {
  final int fileOffset;
  final int width;
  final int height;
  final int channels;       // 1=Gray/Indexed, 3=RGB, 4=CMYK
  final List<int>? palette; // non-null → Indexed color space (256×3 RGB bytes)
  final int predictor;
  final int bpc;
  final Uint8List compressed;

  const _PdfImageInfo({
    required this.fileOffset,
    required this.width,
    required this.height,
    required this.channels,
    required this.predictor,
    required this.bpc,
    required this.compressed,
    this.palette,
  });
}

