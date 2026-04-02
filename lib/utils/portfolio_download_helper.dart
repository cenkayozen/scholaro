import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../utils/native_io.dart' as nio;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/portfolio_item_model.dart';

class PortfolioDownloadHelper {
  // ── Single file ────────────────────────────────────────────────────────────
  static Future<void> download(BuildContext context, PortfolioItem item) async {
    try {
      final response = await http.get(Uri.parse(item.fileUrl));
      if (response.statusCode != 200) throw Exception('Download failed');
      await _saveBytes(context, response.bodyBytes, item.fileName);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ── All / selected as ZIP ──────────────────────────────────────────────────
  static Future<void> downloadAllAsZip(
      BuildContext context, List<PortfolioItem> items,
      {String zipName = 'portfolio'}) async {
    if (items.isEmpty) return;
    _showProgress(context, 'Creating ZIP...');
    try {
      final archive = Archive();
      final usedNames = <String, int>{};

      for (final item in items) {
        final resp = await http.get(Uri.parse(item.fileUrl));
        if (resp.statusCode != 200) continue;
        String name = item.fileName;
        if (usedNames.containsKey(name)) {
          usedNames[name] = usedNames[name]! + 1;
          final dot = name.lastIndexOf('.');
          name = dot == -1
              ? '${name}_${usedNames[name]}'
              : '${name.substring(0, dot)}_${usedNames[name]}${name.substring(dot)}';
        } else {
          usedNames[name] = 0;
        }
        archive.addFile(
            ArchiveFile(name, resp.bodyBytes.length, resp.bodyBytes));
      }

      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) throw Exception('ZIP creation failed');
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      await _saveBytes(context, zipBytes, '$zipName.zip');
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ── All / selected as PDF ──────────────────────────────────────────────────
  static Future<void> downloadAllAsPdf(
      BuildContext context, List<PortfolioItem> items,
      {String pdfName = 'portfolio'}) async {
    if (items.isEmpty) return;
    _showProgress(context, 'Creating PDF...');
    try {
      final doc = pw.Document();

      for (final item in items) {
        final resp = await http.get(Uri.parse(item.fileUrl));
        if (resp.statusCode != 200) continue;

        if (item.fileType == 'image') {
          final image = pw.MemoryImage(resp.bodyBytes);
          doc.addPage(pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(16),
            build: (_) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(item.fileName,
                    style: const pw.TextStyle(fontSize: 10), maxLines: 1),
                pw.SizedBox(height: 8),
                pw.Expanded(
                  child: pw.Center(
                      child: pw.Image(image, fit: pw.BoxFit.contain)),
                ),
              ],
            ),
          ));
        } else {
          doc.addPage(pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (_) => pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(item.fileName,
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Text(
                      '(${item.fileType.toUpperCase()} file — cannot be added to PDF)',
                      style: const pw.TextStyle(
                          fontSize: 11, color: PdfColors.grey)),
                ],
              ),
            ),
          ));
        }
      }

      final bytes = await doc.save();
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      await _saveBytes(context, bytes, '$pdfName.pdf');
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ── Internal helpers ───────────────────────────────────────────────────────
  static Future<void> _saveBytes(
      BuildContext context, List<int> bytes, String fileName) async {
    if (kIsWeb) {
      // Web: share via share_plus (triggers browser download / share sheet)
      final uint8 = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
      final ext   = fileName.contains('.') ? fileName.split('.').last : '';
      final mime  = ext == 'pdf' ? 'application/pdf'
                  : ext == 'zip' ? 'application/zip'
                  : 'application/octet-stream';
      await Share.shareXFiles(
        [XFile.fromData(uint8, name: fileName, mimeType: mime)],
        subject: fileName,
      );
      return;
    }
    if (nio.isWindows) {
      final ext = fileName.contains('.') ? fileName.split('.').last : null;
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save File',
        fileName: fileName,
        type: ext != null ? FileType.custom : FileType.any,
        allowedExtensions: ext != null ? [ext] : null,
      );
      if (path == null) return;
      await nio.writeFileBytes(path, bytes);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Saved')));
      }
    } else {
      // Android/iOS: save to temp then share
      final tmp = await getTemporaryDirectory();
      final path = await nio.writeTempFile(tmp.path, fileName, bytes);
      await Share.shareXFiles([XFile(path)], subject: fileName);
    }
  }

  static void _showProgress(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 16),
          Text(message),
        ]),
      ),
    );
  }
}
