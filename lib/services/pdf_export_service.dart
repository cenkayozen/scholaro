import 'dart:io';
import 'dart:math' show min;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/student_model.dart';
import '../models/homework_assignment_model.dart';
import '../models/participation_model.dart';
import '../models/quiz_model.dart';
import '../utils/grade_calculator.dart';

// ── Brand colours ──────────────────────────────────────────────────────────
const _kPrimary   = PdfColor.fromInt(0xFF1565C0); // deep blue
const _kPrimaryLt = PdfColor.fromInt(0xFFE3F2FD); // light blue tint
const _kAccent    = PdfColor.fromInt(0xFF0288D1); // accent blue
const _kGreen     = PdfColor.fromInt(0xFF2E7D32);
const _kGreenBg   = PdfColor.fromInt(0xFFE8F5E9);
const _kRed       = PdfColor.fromInt(0xFFC62828);
const _kRedBg     = PdfColor.fromInt(0xFFFFEBEE);
const _kOrange    = PdfColor.fromInt(0xFFE65100);
const _kOrangeBg  = PdfColor.fromInt(0xFFFFF3E0);
const _kGrey      = PdfColor.fromInt(0xFF546E7A);
const _kGreyLight = PdfColor.fromInt(0xFFF5F5F5);
const _kDivider   = PdfColor.fromInt(0xFFCFD8DC);
const _kWhite     = PdfColors.white;

class PdfExportService {
  Future<pw.Font> _font()     => PdfGoogleFonts.notoSansRegular();
  Future<pw.Font> _fontBold() => PdfGoogleFonts.notoSansBold();
  Future<pw.Font> _fontItalic() => PdfGoogleFonts.notoSansItalic();

  Future<bool> _saveToFile(List<int> bytes, String defaultName) async {
    final fileName = '$defaultName.pdf';

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      // Mobile: write to temp dir then share / open with external app
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: fileName,
      );
      return true;
    }

    // Desktop / Windows: save-as dialog
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save PDF',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (path == null) return false;
    await File(path).writeAsBytes(bytes);
    return true;
  }

  // ── Public exports ──────────────────────────────────────────────────────

  static const _kHwPerPage = 15; // max students per homework page

  Future<void> exportHomework({
    required String className,
    required List<StudentModel> students,
    required List<HomeworkAssignment> assignments,
    required List<HomeworkGrade> grades,
  }) async {
    final fonts = await _loadFonts();
    final doc   = pw.Document();

    final headers = [
      'Student', 'No',
      ...assignments.map((a) => a.title),
      'Completion %',
    ];

    final allRows = students.map((s) {
      final gradeMap = {
        for (var g in grades.where((g) => g.studentId == s.id)) g.assignmentId: g
      };
      final pct = GradeCalculator.homeworkPercentage(s.id, assignments, grades);
      return _RowData(
        cells: [
          s.fullName, s.schoolNumber,
          ...assignments.map((a) => gradeMap[a.id]?.displayMark ?? ''),
          '${pct.toStringAsFixed(1)}%',
        ],
        highlight: _pctColor(pct),
      );
    }).toList();

    final avgPct = students.isEmpty ? 0.0
        : students.map((s) =>
            GradeCalculator.homeworkPercentage(s.id, assignments, grades))
            .reduce((a, b) => a + b) / students.length;

    final stats = [
      _Stat('Students', '${students.length}'),
      _Stat('Assignments', '${assignments.length}'),
      _Stat('Class Avg.', '${avgPct.toStringAsFixed(1)}%'),
    ];

    _addHwPages(
      doc: doc, fonts: fonts, className: className,
      headers: headers, allRows: allRows, stats: stats,
      hwCount: assignments.length,
    );

    await _saveToFile(await doc.save(), '$className-homework');
  }

  Future<void> exportParticipation({
    required String className,
    required List<StudentModel> students,
    required List<ParticipationEntry> entries,
  }) async {
    final fonts = await _loadFonts();
    final doc   = pw.Document();

    final countMap = {
      for (final s in students)
        s.id: entries.where((e) => e.studentId == s.id).length
    };
    final maxCount = countMap.values.isEmpty ? 1
        : countMap.values.reduce((a, b) => a > b ? a : b);
    final totalEntries = countMap.values.fold(0, (a, b) => a + b);
    final avgCount = students.isEmpty ? 0.0 : totalEntries / students.length;

    final rows = students.map((s) {
      final count = countMap[s.id] ?? 0;
      final pct   = maxCount == 0 ? 0.0 : (count / maxCount) * 100;
      return _RowData(
        cells: [s.fullName, s.schoolNumber, '$count', '${pct.toStringAsFixed(1)}%'],
        highlight: _pctColor(pct),
      );
    }).toList();

    final stats = [
      _Stat('Students', '${students.length}'),
      _Stat('Total Stars', '$totalEntries'),
      _Stat('Avg. per Student', avgCount.toStringAsFixed(1)),
    ];

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
      header: (ctx) => _pageHeader(fonts, className, 'Participation Tracker',
          ctx.pageNumber, ctx.pagesCount),
      footer: (ctx) => _pageFooter(fonts, ctx.pageNumber, ctx.pagesCount),
      build: (ctx) => [
        pw.SizedBox(height: 10),
        _statsRow(fonts, stats),
        pw.SizedBox(height: 12),
        _buildTable(
          fonts: fonts,
          headers: ['Student', 'School No', 'Star Count', 'Percentage (%)'],
          rows: rows,
          colWidths: {0: 3.0, 1: 1.2, 2: 1.2, 3: 1.2},
          fontSize: 10,
        ),
      ],
    ));

    await _saveToFile(await doc.save(), '$className-participation');
  }

  Future<void> exportQuizzes({
    required String className,
    required List<StudentModel> students,
    required List<QuizModel> quizzes,
    required List<QuizScore> scores,
  }) async {
    final fonts = await _loadFonts();
    final doc   = pw.Document();

    final allAvgs = students
        .map((s) => GradeCalculator.quizAverage(s.id, quizzes, scores))
        .where((v) => v != null)
        .cast<double>()
        .toList();
    final classAvg = allAvgs.isEmpty
        ? null
        : allAvgs.reduce((a, b) => a + b) / allAvgs.length;

    final rows = students.map((s) {
      final scoreMap = {
        for (var sc in scores.where((sc) => sc.studentId == s.id)) sc.quizId: sc
      };
      final avg = GradeCalculator.quizAverage(s.id, quizzes, scores);
      return _RowData(
        cells: [
          s.fullName, s.schoolNumber,
          ...quizzes.map((q) => scoreMap[q.id]?.score.toStringAsFixed(0) ?? '–'),
          avg == null ? '–' : avg.toStringAsFixed(1),
        ],
        highlight: avg == null ? null : _scoreColor(avg),
      );
    }).toList();

    final stats = [
      _Stat('Students', '${students.length}'),
      _Stat('Quiz', '${quizzes.length}'),
      _Stat('Class Avg.', classAvg == null ? '–' : classAvg.toStringAsFixed(1)),
    ];

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
      header: (ctx) => _pageHeader(fonts, className, 'Quiz / Exam Results',
          ctx.pageNumber, ctx.pagesCount),
      footer: (ctx) => _pageFooter(fonts, ctx.pageNumber, ctx.pagesCount),
      build: (ctx) => [
        pw.SizedBox(height: 10),
        _statsRow(fonts, stats),
        pw.SizedBox(height: 12),
        _buildTable(
          fonts: fonts,
          headers: ['Student', 'No', ...quizzes.map((q) => q.name), 'Average'],
          rows: rows,
          colWidths: _quizColWidths(quizzes.length),
          fontSize: 9,
        ),
      ],
    ));

    await _saveToFile(await doc.save(), '$className-quizzes');
  }

  Future<void> exportAllScales({
    required String className,
    required List<StudentModel> students,
    required List<HomeworkAssignment> assignments,
    required List<HomeworkGrade> hwGrades,
    required List<ParticipationEntry> participation,
    required List<QuizModel> quizzes,
    required List<QuizScore> quizScores,
  }) async {
    final fonts = await _loadFonts();
    final doc   = pw.Document();

    // ── Pages: Homework (15 students per page) ───────────────────────────
    final hwAvg = students.isEmpty ? 0.0
        : students.map((s) =>
            GradeCalculator.homeworkPercentage(s.id, assignments, hwGrades))
            .reduce((a, b) => a + b) / students.length;

    final hwHeaders = [
      'Student', ...assignments.map((a) => a.title), 'Completion %'
    ];
    final hwAllRows = students.map((s) {
      final gm = {for (var g in hwGrades.where((g) => g.studentId == s.id))
          g.assignmentId: g};
      final pct =
          GradeCalculator.homeworkPercentage(s.id, assignments, hwGrades);
      return _RowData(
        cells: [s.fullName,
          ...assignments.map((a) => gm[a.id]?.displayMark ?? ''),
          '${pct.toStringAsFixed(1)}%'],
        highlight: _pctColor(pct),
      );
    }).toList();

    _addHwPages(
      doc: doc, fonts: fonts, className: className,
      headers: hwHeaders, allRows: hwAllRows,
      stats: [
        _Stat('Students', '${students.length}'),
        _Stat('Assignments', '${assignments.length}'),
        _Stat('Class Avg.', '${hwAvg.toStringAsFixed(1)}%'),
      ],
      hwCount: assignments.length,
    );

    // ── Page 2: Participation ────────────────────────────────────────────
    final cntMap = {
      for (final s in students)
        s.id: participation.where((e) => e.studentId == s.id).length
    };
    final maxCnt = cntMap.values.isEmpty ? 1
        : cntMap.values.reduce((a, b) => a > b ? a : b);
    final totalP = cntMap.values.fold(0, (a, b) => a + b);

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
      header: (ctx) => _pageHeader(fonts, className, 'Participation Tracker',
          ctx.pageNumber, ctx.pagesCount),
      footer: (ctx) => _pageFooter(fonts, ctx.pageNumber, ctx.pagesCount),
      build: (ctx) {
        final rows = students.map((s) {
          final cnt = cntMap[s.id] ?? 0;
          final pct = maxCnt == 0 ? 0.0 : (cnt / maxCnt) * 100;
          return _RowData(
            cells: [s.fullName, s.schoolNumber, '$cnt',
                '${pct.toStringAsFixed(1)}%'],
            highlight: _pctColor(pct),
          );
        }).toList();
        return [
          pw.SizedBox(height: 10),
          _statsRow(fonts, [
            _Stat('Students', '${students.length}'),
            _Stat('Total Stars', '$totalP'),
            _Stat('Avg. per Student',
                students.isEmpty ? '–' : (totalP / students.length).toStringAsFixed(1)),
          ]),
          pw.SizedBox(height: 12),
          _buildTable(
            fonts: fonts,
            headers: ['Student', 'School No', 'Star Count', 'Percentage (%)'],
            rows: rows,
            colWidths: {0: 3.0, 1: 1.2, 2: 1.2, 3: 1.2},
            fontSize: 10,
          ),
        ];
      },
    ));

    // ── Page 3: Quizzes ──────────────────────────────────────────────────
    final allQAvgs = students
        .map((s) => GradeCalculator.quizAverage(s.id, quizzes, quizScores))
        .where((v) => v != null)
        .cast<double>()
        .toList();
    final classQAvg = allQAvgs.isEmpty
        ? null
        : allQAvgs.reduce((a, b) => a + b) / allQAvgs.length;

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
      header: (ctx) => _pageHeader(fonts, className, 'Quiz / Exam Results',
          ctx.pageNumber, ctx.pagesCount),
      footer: (ctx) => _pageFooter(fonts, ctx.pageNumber, ctx.pagesCount),
      build: (ctx) {
        final rows = students.map((s) {
          final sm = {for (var sc in quizScores.where((sc) => sc.studentId == s.id))
              sc.quizId: sc};
          final avg = GradeCalculator.quizAverage(s.id, quizzes, quizScores);
          return _RowData(
            cells: [s.fullName,
              ...quizzes.map((q) => sm[q.id]?.score.toStringAsFixed(0) ?? '–'),
              avg == null ? '–' : avg.toStringAsFixed(1)],
            highlight: avg == null ? null : _scoreColor(avg),
          );
        }).toList();
        return [
          pw.SizedBox(height: 10),
          _statsRow(fonts, [
            _Stat('Students', '${students.length}'),
            _Stat('Quiz', '${quizzes.length}'),
            _Stat('Class Avg.',
                classQAvg == null ? '–' : classQAvg.toStringAsFixed(1)),
          ]),
          pw.SizedBox(height: 12),
          _buildTable(
            fonts: fonts,
            headers: ['Student', ...quizzes.map((q) => q.name), 'Average'],
            rows: rows,
            colWidths: _quizColWidths(quizzes.length),
            fontSize: 9,
          ),
        ];
      },
    ));

    await _saveToFile(await doc.save(), '$className-all-scales');
  }

  // ── Homework paged helper ───────────────────────────────────────────────
  /// Splits [allRows] into chunks of [_kHwPerPage] and adds one pw.Page each.
  /// Stats block is shown only on the first page.
  void _addHwPages({
    required pw.Document doc,
    required _Fonts fonts,
    required String className,
    required List<String> headers,
    required List<_RowData> allRows,
    required List<_Stat> stats,
    required int hwCount,
  }) {
    final total = allRows.isEmpty
        ? 1
        : ((allRows.length - 1) ~/ _kHwPerPage) + 1;

    for (var p = 0; p < total; p++) {
      final start  = p * _kHwPerPage;
      final end    = min(start + _kHwPerPage, allRows.length);
      final chunk  = allRows.isEmpty ? <_RowData>[] : allRows.sublist(start, end);
      final pageNo = p + 1;

      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
        header: (ctx) =>
            _pageHeader(fonts, className, 'Homework Tracker', pageNo, total),
        footer: (ctx) => _pageFooter(fonts, pageNo, total),
        build: (ctx) => [
          pw.SizedBox(height: 10),
          if (pageNo == 1) ...[
            _statsRow(fonts, stats),
            pw.SizedBox(height: 12),
          ],
          _buildTable(
            fonts: fonts,
            headers: headers,
            rows: chunk,
            colWidths: _hwColWidths(hwCount),
            fontSize: 8,
            headerFontSize: 7,
            rotateHeaders: true,
            compact: true,
          ),
        ],
      ));
    }
  }

  // ── Layout helpers ──────────────────────────────────────────────────────

  /// Top header bar: coloured band with title + class + date.
  pw.Widget _pageHeader(
    _Fonts fonts,
    String className,
    String reportTitle,
    int pageNum,
    int pageCount,
  ) {
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}.'
        '${now.month.toString().padLeft(2, '0')}.'
        '${now.year}';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const pw.BoxDecoration(
            color: _kPrimary,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Scholaro',
                      style: pw.TextStyle(
                          font: fonts.bold,
                          fontSize: 11,
                          color: _kWhite,
                          letterSpacing: 1.5)),
                  pw.SizedBox(height: 2),
                  pw.Text(reportTitle,
                      style: pw.TextStyle(
                          font: fonts.regular,
                          fontSize: 9,
                          color: PdfColor.fromInt(0xFFBBDEFB))),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(className,
                      style: pw.TextStyle(
                          font: fonts.bold, fontSize: 13, color: _kWhite)),
                  pw.SizedBox(height: 2),
                  pw.Text(dateStr,
                      style: pw.TextStyle(
                          font: fonts.regular,
                          fontSize: 8,
                          color: PdfColor.fromInt(0xFFBBDEFB))),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 2),
      ],
    );
  }

  /// Bottom footer: thin line + page info.
  pw.Widget _pageFooter(_Fonts fonts, int pageNum, int pageCount) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Divider(color: _kDivider, thickness: 0.5),
        pw.SizedBox(height: 2),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Scholaro – Grade Tracking System',
                style: pw.TextStyle(
                    font: fonts.italic, fontSize: 7, color: _kGrey)),
            pw.Text('Page $pageNum / $pageCount',
                style: pw.TextStyle(
                    font: fonts.regular, fontSize: 7, color: _kGrey)),
          ],
        ),
      ],
    );
  }

  /// Summary stat boxes row.
  pw.Widget _statsRow(_Fonts fonts, List<_Stat> stats) {
    return pw.Row(
      children: stats.map((s) => pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.only(right: 8),
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: pw.BoxDecoration(
            color: _kPrimaryLt,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            border: pw.Border.all(color: _kAccent, width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(s.label,
                  style: pw.TextStyle(
                      font: fonts.regular, fontSize: 7, color: _kGrey)),
              pw.SizedBox(height: 2),
              pw.Text(s.value,
                  style: pw.TextStyle(
                      font: fonts.bold, fontSize: 13, color: _kPrimary)),
            ],
          ),
        ),
      )).toList(),
    );
  }

  /// Professional table with coloured header, zebra rows, coloured last cell.
  pw.Widget _buildTable({
    required _Fonts fonts,
    required List<String> headers,
    required List<_RowData> rows,
    required Map<int, double> colWidths, // index → flex weight
    required double fontSize,
    double? headerFontSize,   // smaller size for column-header text (optional)
    bool rotateHeaders = false, // rotate middle headers 90° for narrow columns
    bool compact = false,       // tighter rows + maxLines:1 to fit 15 per page
  }) {
    final totalFlex =
        colWidths.values.isEmpty ? 1.0 : colWidths.values.reduce((a, b) => a + b);
    final colCount = headers.length;

    pw.TableColumnWidth colW(int i) {
      final w = colWidths[i] ?? 1.0;
      return pw.FlexColumnWidth(w / totalFlex * colCount);
    }

    // Header row
    final headerCells = List.generate(colCount, (i) {
      final isEdge   = i == 0 || i == colCount - 1;
      final hSize    = (isEdge || headerFontSize == null) ? fontSize : headerFontSize;
      final doRotate = rotateHeaders && !isEdge;

      if (doRotate) {
        // No rotation – small bold font with word-wrap so any length name fits.
        const cellH = 54.0;
        return pw.Container(
          color: _kPrimary,
          height: cellH,
          padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
          alignment: pw.Alignment.center,
          child: pw.Text(
            headers[i],
            style: pw.TextStyle(
                font: fonts.bold,
                fontSize: 6.0,
                color: _kWhite),
            textAlign: pw.TextAlign.center,
            maxLines: 5,
            overflow: pw.TextOverflow.clip,
          ),
        );
      }

      // Normal (non-rotated) header
      final maxLn = isEdge ? 2 : 3;
      final edgeH = rotateHeaders ? 54.0 : null;
      return pw.Container(
        color: _kPrimary,
        height: edgeH,
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
        alignment: i == 0 ? pw.Alignment.centerLeft : pw.Alignment.center,
        child: pw.Text(
          headers[i],
          style: pw.TextStyle(
              font: fonts.bold, fontSize: hSize, color: _kWhite),
          textAlign: i == 0 ? pw.TextAlign.left : pw.TextAlign.center,
          maxLines: maxLn,
        ),
      );
    });

    // Data rows
    final dataRows = List.generate(rows.length, (ri) {
      final row   = rows[ri];
      final isOdd = ri.isOdd;
      final bg    = isOdd ? _kGreyLight : _kWhite;

      return List.generate(colCount, (ci) {
        final isLast = ci == colCount - 1;
        final text   = row.cells[ci];
        final cellBg = isLast && row.highlight != null ? row.highlight!.bg : bg;
        final textColor =
            isLast && row.highlight != null ? row.highlight!.fg : PdfColors.black;

        return pw.Container(
          color: cellBg,
          padding: pw.EdgeInsets.symmetric(
            horizontal: compact ? 3 : 4,
            vertical:   compact ? 2 : 4,
          ),
          alignment: ci == 0 ? pw.Alignment.centerLeft : pw.Alignment.center,
          child: pw.Text(
            text,
            style: pw.TextStyle(
              font: isLast ? fonts.bold : fonts.regular,
              fontSize: fontSize,
              color: textColor,
            ),
            textAlign: ci == 0 ? pw.TextAlign.left : pw.TextAlign.center,
            // In compact mode only clip grade/score cells (ci > 0),
            // never the student name column so full names always show.
            maxLines: (compact && ci > 0) ? 1 : null,
            overflow: (compact && ci > 0)
                ? pw.TextOverflow.clip
                : pw.TextOverflow.span,
          ),
        );
      });
    });

    return pw.Table(
      columnWidths: {for (var i = 0; i < colCount; i++) i: colW(i)},
      border: pw.TableBorder.all(color: _kDivider, width: 0.5),
      children: [
        pw.TableRow(children: headerCells),
        ...dataRows.map((cells) => pw.TableRow(children: cells)),
      ],
    );
  }

  // ── Column width maps ───────────────────────────────────────────────────

  Map<int, double> _hwColWidths(int hwCount) {
    // col 0 = student name (wide), col 1..hwCount = marks (narrow), last = %
    return {
      0: 2.5,
      for (var i = 1; i <= hwCount; i++) i: 0.7,
      hwCount + 1: 1.0,
    };
  }

  Map<int, double> _quizColWidths(int quizCount) {
    return {
      0: 2.5,
      for (var i = 1; i <= quizCount; i++) i: 0.9,
      quizCount + 1: 1.0,
    };
  }

  // ── Colour helpers ──────────────────────────────────────────────────────

  _Highlight? _pctColor(double pct) {
    if (pct >= 70) return _Highlight(_kGreenBg, _kGreen);
    if (pct >= 50) return _Highlight(_kOrangeBg, _kOrange);
    return _Highlight(_kRedBg, _kRed);
  }

  _Highlight? _scoreColor(double score) {
    if (score >= 85) return _Highlight(_kGreenBg, _kGreen);
    if (score >= 60) return _Highlight(_kOrangeBg, _kOrange);
    return _Highlight(_kRedBg, _kRed);
  }

  // ── Font loader ─────────────────────────────────────────────────────────
  // ── Font cache (warm-up on export screen open) ─────────────────────────
  static _Fonts? _fontCache;

  /// Call this when the export screen opens to pre-load fonts.
  /// Prevents the "first export is blank" issue caused by PdfGoogleFonts
  /// downloading fonts asynchronously on first use.
  static Future<void> warmUp() async {
    if (_fontCache != null) return;
    final regular = await PdfGoogleFonts.notoSansRegular();
    final bold    = await PdfGoogleFonts.notoSansBold();
    final italic  = await PdfGoogleFonts.notoSansItalic();
    _fontCache = _Fonts(regular: regular, bold: bold, italic: italic);
  }

  Future<_Fonts> _loadFonts() async {
    if (_fontCache == null) await warmUp();
    return _fontCache!;
  }
}

// ── Data classes ────────────────────────────────────────────────────────────

class _Fonts {
  final pw.Font regular;
  final pw.Font bold;
  final pw.Font italic;
  const _Fonts({required this.regular, required this.bold, required this.italic});
}

class _Highlight {
  final PdfColor bg;
  final PdfColor fg;
  const _Highlight(this.bg, this.fg);
}

class _RowData {
  final List<String> cells;
  final _Highlight? highlight;
  const _RowData({required this.cells, this.highlight});
}

class _Stat {
  final String label;
  final String value;
  const _Stat(this.label, this.value);
}
