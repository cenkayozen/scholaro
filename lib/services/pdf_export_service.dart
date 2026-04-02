import 'dart:math' as math;
import 'dart:math' show min;
import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/native_io.dart' as nio;

import '../models/student_model.dart';
import '../models/homework_assignment_model.dart';
import '../models/participation_model.dart';
import '../models/quiz_model.dart';
import '../utils/grade_calculator.dart';

// ── Brand colours ──────────────────────────────────────────────────────────
const _kPrimary    = PdfColor.fromInt(0xFF1565C0);
const _kPrimaryLt  = PdfColor.fromInt(0xFFE3F2FD);
const _kPrimaryMid = PdfColor.fromInt(0xFF1976D2);
const _kAccent     = PdfColor.fromInt(0xFF0288D1);
const _kGreen      = PdfColor.fromInt(0xFF2E7D32);
const _kGreenBg    = PdfColor.fromInt(0xFFE8F5E9);
const _kGreenMid   = PdfColor.fromInt(0xFF558B2F);
const _kGreenMidBg = PdfColor.fromInt(0xFFDCEDC8);
const _kRed        = PdfColor.fromInt(0xFFC62828);
const _kRedBg      = PdfColor.fromInt(0xFFFFEBEE);
const _kOrange     = PdfColor.fromInt(0xFFE65100);
const _kOrangeBg   = PdfColor.fromInt(0xFFFFF3E0);
const _kPurple     = PdfColor.fromInt(0xFF6A1B9A);
const _kPurpleBg   = PdfColor.fromInt(0xFFF3E5F5);
const _kGrey       = PdfColor.fromInt(0xFF546E7A);
const _kGreyLight  = PdfColor.fromInt(0xFFF5F5F5);
const _kGreyMid    = PdfColor.fromInt(0xFFECEFF1);
const _kDivider    = PdfColor.fromInt(0xFFCFD8DC);
const _kAvgRowBg   = PdfColor.fromInt(0xFFE8EAF6);
const _kAvgFg      = PdfColor.fromInt(0xFF283593);
const _kWhite      = PdfColors.white;

class PdfExportService {
  Future<bool> _saveToFile(List<int> bytes, String defaultName) async {
    final fileName = '$defaultName.pdf';
    final uint8 = Uint8List.fromList(bytes);

    if (kIsWeb) {
      // On web: open PDF in browser via printing package (triggers download)
      await Printing.sharePdf(bytes: uint8, filename: fileName);
      return true;
    }

    if (nio.isAndroid || nio.isIOS) {
      final dir  = await getTemporaryDirectory();
      final path = await nio.writeTempFile(dir.path, fileName, bytes);
      await Share.shareXFiles(
        [XFile(path, mimeType: 'application/pdf')],
        subject: fileName,
      );
      return true;
    }

    // Desktop (Windows/macOS/Linux): show save dialog
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save PDF',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (savePath == null) return false;
    await nio.writeFileBytes(savePath, bytes);
    return true;
  }

  // ── Public exports ──────────────────────────────────────────────────────
  static const _kHwPerPage = 15;

  Future<void> exportHomework({
    required String className,
    required List<StudentModel> students,
    required List<HomeworkAssignment> assignments,
    required List<HomeworkGrade> grades,
  }) async {
    final fonts = await _loadFonts();
    final doc   = pw.Document();

    final allRows = await _buildHwRows(students, assignments, grades);
    final avgPct  = _classHwAvg(students, assignments, grades);
    final stats   = [
      _Stat('Students', '${students.length}'),
      _Stat('Assignments', '${assignments.length}'),
      _Stat('Class Avg.', '${avgPct.toStringAsFixed(1)}%'),
    ];

    _addHwPages(
      doc: doc, fonts: fonts, className: className,
      assignments: assignments, allRows: allRows, stats: stats,
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

    final countMap    = {for (final s in students) s.id: entries.where((e) => e.studentId == s.id).length};
    final maxCount    = countMap.values.isEmpty ? 1 : countMap.values.reduce((a, b) => a > b ? a : b);
    final totalEntries= countMap.values.fold(0, (a, b) => a + b);
    final avgCount    = students.isEmpty ? 0.0 : totalEntries / students.length;

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
      header: (ctx) => _pageHeader(fonts, className, 'Participation Tracker', ctx.pageNumber, ctx.pagesCount),
      footer: (ctx) => _pageFooter(fonts, ctx.pageNumber, ctx.pagesCount),
      build: (ctx) => [
        pw.SizedBox(height: 10),
        _statsRow(fonts, stats),
        pw.SizedBox(height: 14),
        _buildSimpleTable(
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
        .where((v) => v != null).cast<double>().toList();
    final classAvg = allAvgs.isEmpty ? null : allAvgs.reduce((a, b) => a + b) / allAvgs.length;

    final rows = students.map((s) {
      final scoreMap = {for (var sc in scores.where((sc) => sc.studentId == s.id)) sc.quizId: sc};
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
      _Stat('Quizzes', '${quizzes.length}'),
      _Stat('Class Avg.', classAvg == null ? '–' : classAvg.toStringAsFixed(1)),
    ];

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
      header: (ctx) => _pageHeader(fonts, className, 'Quiz / Exam Results', ctx.pageNumber, ctx.pagesCount),
      footer: (ctx) => _pageFooter(fonts, ctx.pageNumber, ctx.pagesCount),
      build: (ctx) => [
        pw.SizedBox(height: 10),
        _statsRow(fonts, stats),
        pw.SizedBox(height: 14),
        _buildSimpleTable(
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

    // ── Homework pages ───────────────────────────────────────────────────
    final hwAvg  = _classHwAvg(students, assignments, hwGrades);
    final hwRows = await _buildHwRows(students, assignments, hwGrades);
    _addHwPages(
      doc: doc, fonts: fonts, className: className,
      assignments: assignments, allRows: hwRows,
      stats: [
        _Stat('Students', '${students.length}'),
        _Stat('Assignments', '${assignments.length}'),
        _Stat('Class Avg.', '${hwAvg.toStringAsFixed(1)}%'),
      ],
    );

    // ── Participation page ───────────────────────────────────────────────
    final cntMap  = {for (final s in students) s.id: participation.where((e) => e.studentId == s.id).length};
    final maxCnt  = cntMap.values.isEmpty ? 1 : cntMap.values.reduce((a, b) => a > b ? a : b);
    final totalP  = cntMap.values.fold(0, (a, b) => a + b);

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
      header: (ctx) => _pageHeader(fonts, className, 'Participation Tracker', ctx.pageNumber, ctx.pagesCount),
      footer: (ctx) => _pageFooter(fonts, ctx.pageNumber, ctx.pagesCount),
      build: (ctx) {
        final rows = students.map((s) {
          final cnt = cntMap[s.id] ?? 0;
          final pct = maxCnt == 0 ? 0.0 : (cnt / maxCnt) * 100;
          return _RowData(
            cells: [s.fullName, s.schoolNumber, '$cnt', '${pct.toStringAsFixed(1)}%'],
            highlight: _pctColor(pct),
          );
        }).toList();
        return [
          pw.SizedBox(height: 10),
          _statsRow(fonts, [
            _Stat('Students', '${students.length}'),
            _Stat('Total Stars', '$totalP'),
            _Stat('Avg. per Student', students.isEmpty ? '–' : (totalP / students.length).toStringAsFixed(1)),
          ]),
          pw.SizedBox(height: 14),
          _buildSimpleTable(
            fonts: fonts,
            headers: ['Student', 'School No', 'Star Count', 'Percentage (%)'],
            rows: rows,
            colWidths: {0: 3.0, 1: 1.2, 2: 1.2, 3: 1.2},
            fontSize: 10,
          ),
        ];
      },
    ));

    // ── Quiz page ────────────────────────────────────────────────────────
    final allQAvgs = students
        .map((s) => GradeCalculator.quizAverage(s.id, quizzes, quizScores))
        .where((v) => v != null).cast<double>().toList();
    final classQAvg = allQAvgs.isEmpty ? null : allQAvgs.reduce((a, b) => a + b) / allQAvgs.length;

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold),
      header: (ctx) => _pageHeader(fonts, className, 'Quiz / Exam Results', ctx.pageNumber, ctx.pagesCount),
      footer: (ctx) => _pageFooter(fonts, ctx.pageNumber, ctx.pagesCount),
      build: (ctx) {
        final rows = students.map((s) {
          final sm  = {for (var sc in quizScores.where((sc) => sc.studentId == s.id)) sc.quizId: sc};
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
            _Stat('Quizzes', '${quizzes.length}'),
            _Stat('Class Avg.', classQAvg == null ? '–' : classQAvg.toStringAsFixed(1)),
          ]),
          pw.SizedBox(height: 14),
          _buildSimpleTable(
            fonts: fonts,
            headers: ['Student', 'No', ...quizzes.map((q) => q.name), 'Average'],
            rows: rows,
            colWidths: _quizColWidths(quizzes.length),
            fontSize: 9,
          ),
        ];
      },
    ));

    await _saveToFile(await doc.save(), '$className-all-scales');
  }

  // ── Homework page builder ───────────────────────────────────────────────

  Future<List<_HwRowData>> _buildHwRows(
    List<StudentModel> students,
    List<HomeworkAssignment> assignments,
    List<HomeworkGrade> grades,
  ) async {
    final rows = <_HwRowData>[];
    for (final s in students) {
      final gradeMap = {for (var g in grades.where((g) => g.studentId == s.id)) g.assignmentId: g};
      final pct = GradeCalculator.homeworkPercentage(s.id, assignments, grades);

      // Raw mark keys (not displayMark) for proper PDF rendering
      final marks = assignments.map((a) => gradeMap[a.id]?.mark ?? '').toList();

      // Count each mark type
      int plusC = 0, halfC = 0, minusC = 0, absentC = 0, exemptC = 0;
      for (final m in marks) {
        switch (m) {
          case 'plus':     plusC++;    break;
          case 'halfPlus': halfC++;    break;
          case 'minus':    minusC++;   break;
          case 'absent':   absentC++;  break;
          case 'exempt':   exemptC++;  break;
        }
      }

      pw.MemoryImage? photo;
      if (s.photoUrl.isNotEmpty) {
        for (var attempt = 0; attempt < 2; attempt++) {
          try {
            final resp = await http.get(Uri.parse(s.photoUrl))
                .timeout(const Duration(seconds: 10));
            if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
              photo = pw.MemoryImage(resp.bodyBytes);
              break;
            }
          } catch (_) {
            if (attempt == 0) await Future.delayed(const Duration(seconds: 1));
          }
        }
      }

      rows.add(_HwRowData(
        name: s.fullName,
        number: s.schoolNumber,
        marks: marks,
        completionPct: pct,
        photo: photo,
        plusCount: plusC,
        halfPlusCount: halfC,
        minusCount: minusC,
        absentCount: absentC,
        exemptCount: exemptC,
      ));
    }
    return rows;
  }

  double _classHwAvg(
    List<StudentModel> students,
    List<HomeworkAssignment> assignments,
    List<HomeworkGrade> grades,
  ) {
    if (students.isEmpty) return 0.0;
    return students
        .map((s) => GradeCalculator.homeworkPercentage(s.id, assignments, grades))
        .reduce((a, b) => a + b) / students.length;
  }

  // Min mark column width — below this, assignments overflow to next page
  static const double _kMinMarkW = 20.0;
  static const double _kUsable   = 794.0; // A4 landscape - 48pt margins

  void _addHwPages({
    required pw.Document doc,
    required _Fonts fonts,
    required String className,
    required List<HomeworkAssignment> assignments,
    required List<_HwRowData> allRows,
    required List<_Stat> stats,
  }) {
    // ── Column pagination ────────────────────────────────────────────────
    // Reserve space for stats columns (+, ½+, −, A, E, Avg%) on last col page
    const nameW = 145.0, noW = 32.0;
    const statsW = 22.0; // width per stats column (6 cols: +,½+,−,A,E,Avg%)
    const statsCount = 6;
    const statsTotal = statsW * statsCount;
    final availForMarks = _kUsable - nameW - noW;
    final availMarksNormal = availForMarks; // non-last col pages: full width for marks
    final availMarksLast   = availForMarks - statsTotal; // last col page: reserve stats space
    final maxColsNormal = (availMarksNormal / _kMinMarkW).floor().clamp(1, 9999);
    final maxColsLast   = assignments.isEmpty ? 0
        : (availMarksLast / _kMinMarkW).floor().clamp(1, assignments.length);

    // Build column chunks: last chunk may hold fewer columns (to leave room for stats)
    final colChunks = <List<HomeworkAssignment>>[];
    if (assignments.isEmpty) {
      colChunks.add([]);
    } else {
      var remaining = assignments;
      while (remaining.isNotEmpty) {
        final isLast = remaining.length <= maxColsLast;
        final maxCols = isLast ? maxColsLast : maxColsNormal;
        final take = min(maxCols, remaining.length);
        colChunks.add(remaining.sublist(0, take));
        remaining = remaining.sublist(take);
      }
    }

    // ── Row pagination ───────────────────────────────────────────────────
    final rowChunks = <List<_HwRowData>>[];
    if (allRows.isEmpty) {
      rowChunks.add([]);
    } else {
      for (var r = 0; r < allRows.length; r += _kHwPerPage) {
        rowChunks.add(allRows.sublist(r, min(r + _kHwPerPage, allRows.length)));
      }
    }

    final totalPages = colChunks.length * rowChunks.length;
    var pageNo = 0;
    var startCol = 0;

    for (var ci = 0; ci < colChunks.length; ci++) {
      final colChunk = colChunks[ci];
      final isLastColChunk = ci == colChunks.length - 1;

      for (var ri = 0; ri < rowChunks.length; ri++) {
        final rowChunk = rowChunks[ri];
        pageNo++;
        final isFirstPage = pageNo == 1;

        // Slice marks for this column chunk
        final slicedRows = rowChunk.map((r) => _HwRowData(
          name: r.name,
          number: r.number,
          marks: r.marks.sublist(
            startCol,
            min(startCol + colChunk.length, r.marks.length),
          ),
          completionPct: r.completionPct,
          photo: r.photo,
          plusCount: r.plusCount,
          halfPlusCount: r.halfPlusCount,
          minusCount: r.minusCount,
          absentCount: r.absentCount,
          exemptCount: r.exemptCount,
        )).toList();

        // Corresponding full-class rows for averages (sliced to same col chunk)
        final allSliced = allRows.map((r) => _HwRowData(
          name: r.name,
          number: r.number,
          marks: r.marks.sublist(
            startCol,
            min(startCol + colChunk.length, r.marks.length),
          ),
          completionPct: r.completionPct,
          plusCount: r.plusCount,
          halfPlusCount: r.halfPlusCount,
          minusCount: r.minusCount,
          absentCount: r.absentCount,
          exemptCount: r.exemptCount,
        )).toList();

        doc.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 28),
          theme: pw.ThemeData.withFont(base: fonts.regular, bold: fonts.bold, italic: fonts.italic),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _pageHeader(fonts, className, 'Homework Tracker', pageNo, totalPages),
              pw.SizedBox(height: 8),
              if (isFirstPage) ...[
                _statsRow(fonts, stats),
                pw.SizedBox(height: 10),
              ],
              pw.Expanded(
                child: _buildHwTable(
                  fonts: fonts,
                  assignments: colChunk,
                  rows: slicedRows,
                  allRowsForAvg: allSliced,
                  showStats: isLastColChunk,
                ),
              ),
              pw.SizedBox(height: 4),
              _pageFooter(fonts, pageNo, totalPages),
            ],
          ),
        ));
      }
      startCol += colChunk.length;
    }
  }

  // ── Professional Homework Table ─────────────────────────────────────────
  //
  // Layout (A4 landscape = 842pt, margins 24pt each side → 794pt usable):
  //   Name:  145pt fixed  (single line, no wrap)
  //   No:     32pt fixed
  //   Marks:  equal flex split of remaining space
  //   Avg %:  55pt fixed
  //
  pw.Widget _buildHwTable({
    required _Fonts fonts,
    required List<HomeworkAssignment> assignments,
    required List<_HwRowData> rows,
    required List<_HwRowData> allRowsForAvg,
    bool showStats = true, // show stats columns (+,½+,−,A,E,Avg%) on last col page
  }) {
    const nameW   = 145.0;
    const noW     =  32.0;
    const statsW  =  22.0; // each stats column width
    const statsCount = 6;  // +, ½+, −, A, E, Avg%
    final statsTotal = showStats ? statsW * statsCount : 0.0;
    final markW  = assignments.isEmpty ? 50.0
        : (_kUsable - nameW - noW - statsTotal) / assignments.length;

    final statsBase = assignments.length + 2;
    final colWidths = <int, pw.TableColumnWidth>{
      0: const pw.FixedColumnWidth(nameW),
      1: const pw.FixedColumnWidth(noW),
      for (var i = 0; i < assignments.length; i++)
        i + 2: pw.FixedColumnWidth(markW),
      if (showStats) ...{
        statsBase:     const pw.FixedColumnWidth(statsW), // +
        statsBase + 1: const pw.FixedColumnWidth(statsW), // ½+
        statsBase + 2: const pw.FixedColumnWidth(statsW), // −
        statsBase + 3: const pw.FixedColumnWidth(statsW), // A
        statsBase + 4: const pw.FixedColumnWidth(statsW), // E
        statsBase + 5: const pw.FixedColumnWidth(statsW), // Avg%
      },
    };
    final colCount = assignments.length + 2 + (showStats ? 6 : 0);

    // Stats header labels
    final statsHeaders = showStats
        ? ['+', '½+', '−', 'A', 'E', 'Avg%']
        : <String>[];

    // ── Header row ──
    final headerCells = <pw.Widget>[
      _hwHeaderCell(fonts, 'Student', align: pw.Alignment.centerLeft, width: nameW),
      _hwHeaderCell(fonts, 'No', width: noW),
      ...assignments.map((a) => _hwHeaderCell(fonts, a.title, width: markW, rotate: true)),
      ...statsHeaders.map((h) => _hwHeaderCell(fonts, h, width: statsW, rotate: true)),
    ];

    // ── Data rows ──
    final dataRows = <pw.TableRow>[];
    for (var ri = 0; ri < rows.length; ri++) {
      final row   = rows[ri];
      final isOdd = ri.isOdd;
      final bg    = isOdd ? _kGreyLight : _kWhite;

      final cells = <pw.Widget>[
        // Name – photo thumbnail + single line name
        pw.Container(
          color: bg,
          height: 22,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Photo or initials circle
              if (row.photo != null)
                pw.ClipOval(
                  child: pw.Image(row.photo!, width: 16, height: 16, fit: pw.BoxFit.cover),
                )
              else
                pw.Container(
                  width: 16,
                  height: 16,
                  decoration: const pw.BoxDecoration(
                    color: _kPrimaryLt,
                    shape: pw.BoxShape.circle,
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    row.name.isNotEmpty ? row.name[0].toUpperCase() : '?',
                    style: pw.TextStyle(font: fonts.bold, fontSize: 6, color: _kPrimary),
                  ),
                ),
              pw.SizedBox(width: 4),
              pw.Expanded(
                child: pw.Text(
                  row.name,
                  style: pw.TextStyle(font: fonts.regular, fontSize: 8),
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                ),
              ),
            ],
          ),
        ),
        // School number
        pw.Container(
          color: bg,
          height: 22,
          padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
          alignment: pw.Alignment.center,
          child: pw.Text(
            row.number,
            style: pw.TextStyle(font: fonts.regular, fontSize: 7, color: _kGrey),
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
          ),
        ),
        // Mark cells
        ...row.marks.map((mark) => _hwMarkCell(fonts, mark, bg)),
        // Stats columns (only on last col page)
        if (showStats) ...[
          _hwStatCell(fonts, '${row.plusCount}',     _kGreen,   bg),
          _hwStatCell(fonts, '${row.halfPlusCount}', const PdfColor.fromInt(0xFF66BB6A), bg),
          _hwStatCell(fonts, '${row.minusCount}',    _kRed,     bg),
          _hwStatCell(fonts, '${row.absentCount}',   _kOrange,  bg),
          _hwStatCell(fonts, '${row.exemptCount}',   _kGrey,    bg),
          _hwPctCell(fonts, row.completionPct),
        ],
      ];

      dataRows.add(pw.TableRow(children: cells));
    }

    // ── Averages row (uses full-class data for accurate averages) ──
    final avgSource = allRowsForAvg.isEmpty ? rows : allRowsForAvg;
    final avgCells = <pw.Widget>[
      pw.Container(
        color: _kAvgRowBg,
        height: 22,
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        alignment: pw.Alignment.centerLeft,
        child: pw.Text('Class Avg.',
            style: pw.TextStyle(font: fonts.bold, fontSize: 7.5, color: _kAvgFg)),
      ),
      pw.Container(color: _kAvgRowBg, height: 22), // No col
      ...List.generate(assignments.length, (ci) {
        if (avgSource.isEmpty) {
          return pw.Container(color: _kAvgRowBg, height: 22,
              alignment: pw.Alignment.center,
              child: pw.Text('–', style: pw.TextStyle(font: fonts.regular, fontSize: 7, color: _kGrey)));
        }
        final marks = avgSource
            .where((r) => ci < r.marks.length)
            .map((r) => r.marks[ci])
            .where((m) => m.isNotEmpty && m != 'exempt')
            .toList();
        if (marks.isEmpty) {
          return pw.Container(color: _kAvgRowBg, height: 22,
              alignment: pw.Alignment.center,
              child: pw.Text('–', style: pw.TextStyle(font: fonts.regular, fontSize: 7, color: _kGrey)));
        }
        final positives = marks.where((m) => m == 'plus' || m == 'halfPlus').length;
        final pct = (positives / marks.length * 100).round();
        return pw.Container(
          color: _kAvgRowBg, height: 22,
          alignment: pw.Alignment.center,
          child: pw.Text('$pct%',
              style: pw.TextStyle(font: fonts.bold, fontSize: 7.5, color: _kAvgFg)),
        );
      }),
      // Stats column averages + overall pct (last col page only)
      if (showStats) ...[
        _hwAvgStatCell(fonts, avgSource.isEmpty ? 0 : (avgSource.map((r) => r.plusCount).reduce((a, b) => a + b) / avgSource.length)),
        _hwAvgStatCell(fonts, avgSource.isEmpty ? 0 : (avgSource.map((r) => r.halfPlusCount).reduce((a, b) => a + b) / avgSource.length)),
        _hwAvgStatCell(fonts, avgSource.isEmpty ? 0 : (avgSource.map((r) => r.minusCount).reduce((a, b) => a + b) / avgSource.length)),
        _hwAvgStatCell(fonts, avgSource.isEmpty ? 0 : (avgSource.map((r) => r.absentCount).reduce((a, b) => a + b) / avgSource.length)),
        _hwAvgStatCell(fonts, avgSource.isEmpty ? 0 : (avgSource.map((r) => r.exemptCount).reduce((a, b) => a + b) / avgSource.length)),
        (() {
          if (avgSource.isEmpty) return pw.Container(color: _kAvgRowBg, height: 22);
          final avg = avgSource.map((r) => r.completionPct).reduce((a, b) => a + b) / avgSource.length;
          final hl  = _pctColor(avg);
          return pw.Container(
            color: hl?.bg ?? _kAvgRowBg, height: 22,
            alignment: pw.Alignment.center,
            child: pw.Text('${avg.toStringAsFixed(1)}%',
                style: pw.TextStyle(font: fonts.bold, fontSize: 8, color: hl?.fg ?? _kAvgFg)),
          );
        })(),
      ],
    ];

    return pw.Table(
      columnWidths: colWidths,
      border: pw.TableBorder.all(color: _kDivider, width: 0.4),
      children: [
        pw.TableRow(children: headerCells),
        ...dataRows,
        if (rows.isNotEmpty) pw.TableRow(children: avgCells),
      ],
    );
  }

  // Header height for assignment columns — tall enough for rotated text
  static const double _kHeaderH = 80.0;

  pw.Widget _hwHeaderCell(
    _Fonts fonts,
    String text, {
    pw.Alignment align = pw.Alignment.center,
    required double width,
    bool rotate = false,
  }) {
    if (rotate) {
      // Rotated -90°: inner SizedBox width → visual height, height → visual width
      // width param = physical column width = available visual width after rotation
      // _kHeaderH = physical cell height = available visual text length after rotation
      return pw.Container(
        color: _kPrimary,
        width: width,
        height: _kHeaderH,
        alignment: pw.Alignment.center,
        child: pw.Transform.rotate(
          angle: -math.pi / 2,
          child: pw.SizedBox(
            width: _kHeaderH - 10, // text length (visual height after rotation)
            height: width - 4,     // text stack depth (visual width after rotation = column width)
            child: pw.Text(
              text,
              style: pw.TextStyle(font: fonts.bold, fontSize: 7.0, color: _kWhite),
              textAlign: pw.TextAlign.center,
              maxLines: null,        // allow wrapping to use full column width
              overflow: pw.TextOverflow.clip,
            ),
          ),
        ),
      );
    }
    // Name / No / Avg% columns — normal horizontal header
    return pw.Container(
      color: _kPrimary,
      height: _kHeaderH,
      padding: pw.EdgeInsets.symmetric(horizontal: align == pw.Alignment.centerLeft ? 5 : 2, vertical: 4),
      alignment: align,
      child: pw.Text(
        text,
        style: pw.TextStyle(font: fonts.bold, fontSize: 8.0, color: _kWhite),
        textAlign: align == pw.Alignment.centerLeft ? pw.TextAlign.left : pw.TextAlign.center,
        maxLines: 2,
      ),
    );
  }

  pw.Widget _hwMarkCell(_Fonts fonts, String mark, PdfColor rowBg) {
    final style = _markStyle(mark);
    final bg    = style?.bg ?? rowBg;

    if (mark == 'halfPlus') {
      return pw.Container(
        color: bg,
        height: 22,
        alignment: pw.Alignment.center,
        child: pw.CustomPaint(
          size: const PdfPoint(9, 9),
          painter: (canvas, size) {
            const halfPlusColor = PdfColor.fromInt(0xFF66BB6A);
            final sw = size.x * 0.2;
            canvas
              ..setStrokeColor(halfPlusColor)
              ..setLineWidth(sw)
              // Horizontal bar (full width)
              ..moveTo(size.x * 0.12, size.y * 0.5)
              ..lineTo(size.x * 0.88, size.y * 0.5)
              ..strokePath()
              // Top half of vertical bar (center to top — PDF y-axis goes up)
              ..moveTo(size.x * 0.5, size.y * 0.5)
              ..lineTo(size.x * 0.5, size.y * 0.88)
              ..strokePath();
          },
        ),
      );
    }

    final displayText = switch (mark) {
      'plus'   => '+',
      'minus'  => '−',
      'absent' => 'A',
      'exempt' => 'E',
      _        => '',
    };

    return pw.Container(
      color: bg,
      height: 22,
      alignment: pw.Alignment.center,
      child: mark.isEmpty
          ? pw.SizedBox()
          : pw.Text(
              displayText,
              style: pw.TextStyle(
                font: style?.bold == true ? fonts.bold : fonts.regular,
                fontSize: style?.small == true ? 7.0 : 9.0,
                color: style?.fg ?? PdfColors.black,
              ),
              textAlign: pw.TextAlign.center,
            ),
    );
  }

  pw.Widget _hwStatCell(
    _Fonts fonts,
    String value,
    PdfColor color,
    PdfColor rowBg,
  ) {
    return pw.Container(
      color: rowBg,
      height: 22,
      alignment: pw.Alignment.center,
      child: pw.Text(
        value,
        style: pw.TextStyle(font: fonts.bold, fontSize: 7.5, color: color),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _hwAvgStatCell(_Fonts fonts, num avg) {
    final val = avg == avg.toInt() ? '${avg.toInt()}' : avg.toStringAsFixed(1);
    return pw.Container(
      color: _kAvgRowBg,
      height: 22,
      alignment: pw.Alignment.center,
      child: pw.Text(
        val,
        style: pw.TextStyle(font: fonts.bold, fontSize: 7.5, color: _kAvgFg),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _hwPctCell(_Fonts fonts, double pct) {
    final hl = _pctColor(pct);
    return pw.Container(
      color: hl?.bg ?? _kWhite,
      height: 22,
      alignment: pw.Alignment.center,
      child: pw.Text(
        '${pct.toStringAsFixed(1)}%',
        style: pw.TextStyle(font: fonts.bold, fontSize: 8, color: hl?.fg ?? PdfColors.black),
      ),
    );
  }

  // Mark colour helper — accepts raw mark keys ('plus', 'halfPlus', etc.)
  // A and E: no background, just smaller plain text
  // halfPlus uses lighter green; drawn with CustomPaint in _hwMarkCell
  _MarkStyle? _markStyle(String mark) {
    switch (mark) {
      case 'plus':     return _MarkStyle(_kGreenBg, _kGreen, true, false);
      case 'halfPlus': return _MarkStyle(_kGreenBg, const PdfColor.fromInt(0xFF66BB6A), true, false);
      case 'minus':    return _MarkStyle(_kRedBg, _kRed, false, false);
      case 'absent':   return _MarkStyle(null, _kOrange, false, true);  // no bg, small
      case 'exempt':   return _MarkStyle(null, _kGrey, false, true);    // no bg, small
      default:         return null;
    }
  }

  // ── Page header & footer ────────────────────────────────────────────────

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
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const pw.BoxDecoration(
            color: _kPrimary,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Left: logo block + app name + report title
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // Logo square
                  pw.Container(
                    width: 32,
                    height: 32,
                    decoration: pw.BoxDecoration(
                      color: _kWhite,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    ),
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      'S',
                      style: pw.TextStyle(
                        font: fonts.bold,
                        fontSize: 18,
                        color: _kPrimary,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        'Scholaro',
                        style: pw.TextStyle(
                          font: fonts.bold,
                          fontSize: 13,
                          color: _kWhite,
                          letterSpacing: 1.2,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        reportTitle,
                        style: pw.TextStyle(
                          font: fonts.regular,
                          fontSize: 8.5,
                          color: PdfColor.fromInt(0xFFBBDEFB),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Right: class name + date
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    className,
                    style: pw.TextStyle(font: fonts.bold, fontSize: 14, color: _kWhite),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    dateStr,
                    style: pw.TextStyle(
                      font: fonts.regular,
                      fontSize: 8,
                      color: PdfColor.fromInt(0xFFBBDEFB),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 4),
      ],
    );
  }

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
                style: pw.TextStyle(font: fonts.italic, fontSize: 7, color: _kGrey)),
            pw.Text('Page $pageNum / $pageCount',
                style: pw.TextStyle(font: fonts.regular, fontSize: 7, color: _kGrey)),
          ],
        ),
      ],
    );
  }

  pw.Widget _statsRow(_Fonts fonts, List<_Stat> stats) {
    return pw.Row(
      children: stats.map((s) => pw.Expanded(
        child: pw.Container(
          margin: const pw.EdgeInsets.only(right: 8),
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: pw.BoxDecoration(
            color: _kPrimaryLt,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
            border: pw.Border.all(color: _kAccent, width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(s.label,
                  style: pw.TextStyle(font: fonts.regular, fontSize: 7, color: _kGrey)),
              pw.SizedBox(height: 3),
              pw.Text(s.value,
                  style: pw.TextStyle(font: fonts.bold, fontSize: 14, color: _kPrimary)),
            ],
          ),
        ),
      )).toList(),
    );
  }

  // ── Generic simple table (for participation / quiz) ─────────────────────
  pw.Widget _buildSimpleTable({
    required _Fonts fonts,
    required List<String> headers,
    required List<_RowData> rows,
    required Map<int, double> colWidths,
    required double fontSize,
  }) {
    final totalFlex  = colWidths.values.isEmpty ? 1.0 : colWidths.values.reduce((a, b) => a + b);
    final colCount   = headers.length;

    pw.TableColumnWidth colW(int i) {
      final w = colWidths[i] ?? 1.0;
      return pw.FlexColumnWidth(w / totalFlex * colCount);
    }

    final headerCells = List.generate(colCount, (i) => pw.Container(
      color: _kPrimary,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      alignment: i == 0 ? pw.Alignment.centerLeft : pw.Alignment.center,
      child: pw.Text(
        headers[i],
        style: pw.TextStyle(font: fonts.bold, fontSize: fontSize, color: _kWhite),
        textAlign: i == 0 ? pw.TextAlign.left : pw.TextAlign.center,
        maxLines: 2,
      ),
    ));

    final dataRows = List.generate(rows.length, (ri) {
      final row  = rows[ri];
      final bg   = ri.isOdd ? _kGreyLight : _kWhite;
      return List.generate(colCount, (ci) {
        final isLast = ci == colCount - 1;
        final cellBg = isLast && row.highlight != null ? row.highlight!.bg : bg;
        final fgCol  = isLast && row.highlight != null ? row.highlight!.fg : PdfColors.black;
        return pw.Container(
          color: cellBg,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          alignment: ci == 0 ? pw.Alignment.centerLeft : pw.Alignment.center,
          child: pw.Text(
            row.cells[ci],
            style: pw.TextStyle(
              font: isLast ? fonts.bold : fonts.regular,
              fontSize: fontSize,
              color: fgCol,
            ),
            maxLines: ci == 0 ? 1 : null,
            overflow: ci == 0 ? pw.TextOverflow.clip : pw.TextOverflow.span,
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
  Map<int, double> _quizColWidths(int quizCount) => {
    0: 2.5,
    for (var i = 1; i <= quizCount; i++) i: 0.9,
    quizCount + 1: 1.0,
  };

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

  // ── Font cache ──────────────────────────────────────────────────────────
  static _Fonts? _fontCache;

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

class _MarkStyle {
  final PdfColor? bg;  // null = no background (use row bg)
  final PdfColor fg;
  final bool bold;
  final bool small;    // true = smaller font (A, E)
  const _MarkStyle(this.bg, this.fg, this.bold, this.small);
}

class _RowData {
  final List<String> cells;
  final _Highlight? highlight;
  const _RowData({required this.cells, this.highlight});
}

class _HwRowData {
  final String name;
  final String number;
  final List<String> marks; // raw mark keys: 'plus','halfPlus','minus','absent','exempt',''
  final double completionPct;
  final pw.MemoryImage? photo;
  // Counters (computed once, shown in stats columns)
  final int plusCount;
  final int halfPlusCount;
  final int minusCount;
  final int absentCount;
  final int exemptCount;

  const _HwRowData({
    required this.name,
    required this.number,
    required this.marks,
    required this.completionPct,
    this.photo,
    this.plusCount = 0,
    this.halfPlusCount = 0,
    this.minusCount = 0,
    this.absentCount = 0,
    this.exemptCount = 0,
  });
}

class _Stat {
  final String label;
  final String value;
  const _Stat(this.label, this.value);
}
