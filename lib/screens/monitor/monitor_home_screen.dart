import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import '../../models/homework_assignment_model.dart';
import '../../models/student_model.dart';
import '../../models/monitor_grade_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/grade_mark_widget.dart';
import '../../widgets/student_avatar.dart';
import '../../widgets/scholaro_logo.dart';

// ── Providers ──────────────────────────────────────────────────────────────

final _monitorSessionProvider = FutureProvider<Map<String, dynamic>>((ref) =>
    ref.watch(authServiceProvider).getMonitorSession());

final _monitorGradesProvider =
    StreamProvider.family<List<MonitorGrade>, ClassParams>((ref, params) =>
        ref
            .watch(firestoreServiceProvider)
            .streamMonitorGrades(params.teacherId, params.classId));

final _monitorSubmissionsProvider =
    StreamProvider.family<List<MonitorSubmission>, ClassParams>((ref, params) =>
        ref
            .watch(firestoreServiceProvider)
            .streamMonitorSubmissions(params.teacherId, params.classId));

// ── Screen ────────────────────────────────────────────────────────────────

class MonitorHomeScreen extends ConsumerStatefulWidget {
  const MonitorHomeScreen({super.key});

  @override
  ConsumerState<MonitorHomeScreen> createState() => _MonitorHomeScreenState();
}

class _MonitorHomeScreenState extends ConsumerState<MonitorHomeScreen> {
  final _leftVertCtrl = ScrollController();
  final _rightVertCtrl = ScrollController();
  final _horizBodyCtrl = ScrollController();
  final _horizHeaderCtrl = ScrollController();
  bool _syncing = false;

  late double _rowHeight;
  late double _headerHeight;
  late double _hwColWidth;
  late double _noColWidth;
  late double _leftPanelWidth;
  late double _nameFontSize;
  late double _avatarRadius;

  @override
  void initState() {
    super.initState();
    _rightVertCtrl.addListener(_syncFromRight);
    _leftVertCtrl.addListener(_syncFromLeft);
    _horizBodyCtrl.addListener(_syncHorizFromBody);
  }

  void _syncFromRight() {
    if (_syncing) return;
    if (!_leftVertCtrl.hasClients) return;
    _syncing = true;
    _leftVertCtrl.jumpTo(_rightVertCtrl.offset);
    _syncing = false;
  }

  void _syncFromLeft() {
    if (_syncing) return;
    if (!_rightVertCtrl.hasClients) return;
    _syncing = true;
    _rightVertCtrl.jumpTo(_leftVertCtrl.offset);
    _syncing = false;
  }

  void _syncHorizFromBody() {
    if (!_horizHeaderCtrl.hasClients) return;
    _horizHeaderCtrl.jumpTo(_horizBodyCtrl.offset);
  }

  @override
  void dispose() {
    _leftVertCtrl.dispose();
    _rightVertCtrl.dispose();
    _horizBodyCtrl.dispose();
    _horizHeaderCtrl.dispose();
    super.dispose();
  }

  void _initDimensions(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final narrow = w < 600;
    _rowHeight = narrow ? 44.0 : 52.0;
    _headerHeight = narrow ? 62.0 : 60.0;
    _hwColWidth = narrow ? 48.0 : 88.0;
    _noColWidth = narrow ? 36.0 : 56.0;
    _leftPanelWidth = narrow ? 140.0 : 200.0;
    _nameFontSize = narrow ? 11.0 : 13.0;
    _avatarRadius = narrow ? 10.0 : 14.0;
  }

  Future<void> _setMonitorGrade(
    WidgetRef ref,
    String teacherId,
    String classId,
    String monitorStudentId,
    String studentId,
    String assignmentId,
    String mark,
  ) async {
    final fs = ref.read(firestoreServiceProvider);
    if (mark.isEmpty) {
      await fs.deleteMonitorGrade(
          teacherId, classId, monitorStudentId, studentId, assignmentId);
    } else {
      await fs.setMonitorGrade(MonitorGrade(
        id: fs.generateId(),
        teacherId: teacherId,
        classId: classId,
        monitorStudentId: monitorStudentId,
        studentId: studentId,
        assignmentId: assignmentId,
        mark: mark,
        gradedAt: DateTime.now(),
      ));
    }
  }

  Future<void> _submitForApproval(
    BuildContext context,
    WidgetRef ref,
    String teacherId,
    String classId,
    String monitorStudentId,
    String assignmentId,
    String assignmentTitle,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Submit for Approval'),
        content: Text(
            'Submit grades for "$assignmentTitle" to the teacher for approval?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Submit')),
        ],
      ),
    );
    if (confirmed != true) return;

    final fs = ref.read(firestoreServiceProvider);
    await fs.submitMonitorGrades(MonitorSubmission(
      id: fs.generateId(),
      teacherId: teacherId,
      classId: classId,
      monitorStudentId: monitorStudentId,
      assignmentId: assignmentId,
      status: 'pending',
      submittedAt: DateTime.now(),
    ));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Submitted for teacher approval'),
          backgroundColor: Color(0xFF1565C0),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _initDimensions(context);

    final sessionAsync = ref.watch(_monitorSessionProvider);

    return sessionAsync.when(
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
          body: Center(child: Text('Session error: $e'))),
      data: (session) {
        final teacherId = session['teacherId'] as String? ?? '';
        final classId = session['classId'] as String? ?? '';
        final monitorStudentId = session['studentId'] as String? ?? '';
        final assignedIds =
            (session['monitorAssignmentIds'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toSet() ??
                <String>{};

        if (teacherId.isEmpty || classId.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Homework Monitor')),
            body: const Center(child: Text('Session not found. Please log in again.')),
          );
        }

        final params = ClassParams(teacherId: teacherId, classId: classId);
        final assignmentsAsync = ref.watch(homeworkAssignmentsProvider(params));
        final studentsAsync = ref.watch(studentsProvider(params));
        final monitorGradesAsync = ref.watch(_monitorGradesProvider(params));
        final submissionsAsync = ref.watch(_monitorSubmissionsProvider(params));

        return assignmentsAsync.when(
          loading: () => const Scaffold(
              body: Center(child: CircularProgressIndicator())),
          error: (e, _) =>
              Scaffold(body: Center(child: Text('Error: $e'))),
          data: (assignments) => studentsAsync.when(
            loading: () => const Scaffold(
                body: Center(child: CircularProgressIndicator())),
            error: (e, _) =>
                Scaffold(body: Center(child: Text('Error: $e'))),
            data: (students) => _buildScreen(
              context,
              ref,
              teacherId: teacherId,
              classId: classId,
              monitorStudentId: monitorStudentId,
              assignedIds: assignedIds,
              assignments: assignments,
              students: students,
              monitorGrades: monitorGradesAsync.value ?? [],
              submissions: submissionsAsync.value ?? [],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScreen(
    BuildContext context,
    WidgetRef ref, {
    required String teacherId,
    required String classId,
    required String monitorStudentId,
    required Set<String> assignedIds,
    required List<HomeworkAssignment> assignments,
    required List<StudentModel> students,
    required List<MonitorGrade> monitorGrades,
    required List<MonitorSubmission> submissions,
  }) {
    // Map: assignmentId → submission (for this monitor)
    final submissionMap = {
      for (final s in submissions.where((s) => s.monitorStudentId == monitorStudentId))
        s.assignmentId: s
    };

    // Map: studentId+assignmentId → MonitorGrade
    final gradeMap = {
      for (final g in monitorGrades.where((g) => g.monitorStudentId == monitorStudentId))
        '${g.studentId}_${g.assignmentId}': g
    };

    return Scaffold(
      appBar: AppBar(
        title: const ScholaroLogo(iconSize: 28, horizontal: true),
        leading: const SizedBox.shrink(),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) context.go('/');
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: role info
          Container(
            color: const Color(0xFF1565C0).withOpacity(0.08),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.rate_review_outlined,
                    color: Color(0xFF1565C0), size: 18),
                const SizedBox(width: 8),
                const Text('Homework Monitor',
                    style: TextStyle(
                        color: Color(0xFF1565C0),
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                const SizedBox(width: 12),
                Text(
                    '${assignedIds.length} assignment(s) assigned to you',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          Expanded(
              child: _buildGrid(
            context,
            ref,
            teacherId: teacherId,
            classId: classId,
            monitorStudentId: monitorStudentId,
            assignedIds: assignedIds,
            assignments: assignments,
            students: students,
            gradeMap: gradeMap,
            submissionMap: submissionMap,
          )),
        ],
      ),
    );
  }

  Widget _buildGrid(
    BuildContext context,
    WidgetRef ref, {
    required String teacherId,
    required String classId,
    required String monitorStudentId,
    required Set<String> assignedIds,
    required List<HomeworkAssignment> assignments,
    required List<StudentModel> students,
    required Map<String, MonitorGrade> gradeMap,
    required Map<String, MonitorSubmission> submissionMap,
  }) {
    if (assignments.isEmpty) {
      return const Center(
          child: Text('No homework assignments yet.',
              style: TextStyle(color: Colors.grey)));
    }

    final noColW = _noColWidth;
    final totalGridWidth =
        noColW + assignments.length * _hwColWidth;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Left panel: student names ──────────────────────────────────
        SizedBox(
          width: _leftPanelWidth,
          child: Column(
            children: [
              // Header spacer
              Container(
                height: _headerHeight,
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0),
                  border: Border(
                      right: BorderSide(color: Colors.white24),
                      bottom: BorderSide(color: Colors.white24)),
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: const Text('Students',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _leftVertCtrl,
                  physics: const ClampingScrollPhysics(),
                  itemCount: students.length,
                  itemBuilder: (_, i) {
                    final s = students[i];
                    final isSelf = s.id == monitorStudentId;
                    return Container(
                      height: _rowHeight,
                      decoration: BoxDecoration(
                        color: isSelf
                            ? Colors.orange.withOpacity(0.08)
                            : (i.isEven
                                ? Colors.white
                                : Colors.grey.shade50),
                        border: Border(
                            bottom: BorderSide(color: Colors.grey.shade200)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          StudentAvatar(
                            photoUrl: s.photoUrl,
                            name: s.fullName,
                            radius: _avatarRadius,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              s.fullName,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                  fontSize: _nameFontSize,
                                  fontWeight: isSelf
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelf
                                      ? Colors.orange.shade800
                                      : null),
                            ),
                          ),
                          if (isSelf)
                            const Tooltip(
                              message: 'Your row – read-only',
                              child: Icon(Icons.lock_outline,
                                  size: 12, color: Colors.orange),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // ── Right panel: scrollable grid ──────────────────────────────
        Expanded(
          child: Column(
            children: [
              // Header row
              SizedBox(
                height: _headerHeight,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _horizHeaderCtrl,
                  physics: const NeverScrollableScrollPhysics(),
                  child: SizedBox(
                    width: totalGridWidth,
                    child: Row(
                      children: [
                        // # column header
                        Container(
                          width: noColW,
                          height: _headerHeight,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1565C0),
                            border: Border(
                                right:
                                    BorderSide(color: Colors.white24),
                                bottom:
                                    BorderSide(color: Colors.white24)),
                          ),
                          alignment: Alignment.center,
                          child: const Text('#',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                        // Assignment headers
                        ...assignments.map((a) {
                          final isAssigned = assignedIds.contains(a.id);
                          final submission = submissionMap[a.id];
                          return _AssignmentHeader(
                            assignment: a,
                            isAssigned: isAssigned,
                            submission: submission,
                            colWidth: _hwColWidth,
                            headerHeight: _headerHeight,
                            onSubmit: isAssigned &&
                                    (submission == null ||
                                        submission.isPending)
                                ? () async {
                                    // re-submit or first submit
                                    if (submission != null &&
                                        submission.isApproved) return;
                                    final teacherIdL =
                                        teacherId;
                                    final classIdL = classId;
                                    await _submitForApproval(
                                        context,
                                        ref,
                                        teacherIdL,
                                        classIdL,
                                        monitorStudentId,
                                        a.id,
                                        a.title);
                                  }
                                : null,
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
              // Body
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _horizBodyCtrl,
                  child: SizedBox(
                    width: totalGridWidth,
                    child: ListView.builder(
                      controller: _rightVertCtrl,
                      physics: const ClampingScrollPhysics(),
                      itemCount: students.length,
                      itemBuilder: (_, i) {
                        final s = students[i];
                        final isSelf = s.id == monitorStudentId;
                        return Container(
                          height: _rowHeight,
                          color: isSelf
                              ? Colors.orange.withOpacity(0.05)
                              : (i.isEven
                                  ? Colors.white
                                  : Colors.grey.shade50),
                          child: Row(
                            children: [
                              // Row number
                              Container(
                                width: noColW,
                                height: _rowHeight,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                    border: Border(
                                        right: BorderSide(
                                            color: Colors.grey.shade200),
                                        bottom: BorderSide(
                                            color: Colors.grey.shade200))),
                                child: Text('${i + 1}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500)),
                              ),
                              // Grade cells
                              ...assignments.map((a) {
                                final isAssigned =
                                    assignedIds.contains(a.id);
                                final submission = submissionMap[a.id];
                                final isApproved =
                                    submission?.isApproved ?? false;
                                final key = '${s.id}_${a.id}';
                                final mg = gradeMap[key];
                                final mark = mg?.mark ?? '';

                                // Editable if: assigned + not self + not approved
                                final editable =
                                    isAssigned && !isSelf && !isApproved;

                                return _GradeCell(
                                  mark: mark,
                                  editable: editable,
                                  colWidth: _hwColWidth,
                                  rowHeight: _rowHeight,
                                  isAssigned: isAssigned,
                                  isApproved: isApproved,
                                  onChanged: editable
                                      ? (newMark) async {
                                          await _setMonitorGrade(
                                              ref,
                                              teacherId,
                                              classId,
                                              monitorStudentId,
                                              s.id,
                                              a.id,
                                              newMark);
                                        }
                                      : null,
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Assignment Header ──────────────────────────────────────────────────────

class _AssignmentHeader extends StatelessWidget {
  final HomeworkAssignment assignment;
  final bool isAssigned;
  final MonitorSubmission? submission;
  final double colWidth;
  final double headerHeight;
  final VoidCallback? onSubmit;

  const _AssignmentHeader({
    required this.assignment,
    required this.isAssigned,
    required this.submission,
    required this.colWidth,
    required this.headerHeight,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Widget? badge;

    if (!isAssigned) {
      bgColor = const Color(0xFF1565C0);
    } else if (submission?.isApproved == true) {
      bgColor = const Color(0xFF2E7D32); // green – approved
      badge = const Icon(Icons.check_circle, color: Colors.white, size: 14);
    } else if (submission?.isPending == true) {
      bgColor = const Color(0xFFE65100); // orange – pending approval
      badge = const Icon(Icons.pending, color: Colors.white, size: 14);
    } else {
      bgColor = const Color(0xFF1976D2); // blue – assigned, not submitted
    }

    return Container(
      width: colWidth,
      height: headerHeight,
      decoration: BoxDecoration(
        color: bgColor,
        border: const Border(
          right: BorderSide(color: Colors.white24),
          bottom: BorderSide(color: Colors.white24),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              assignment.title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 6.5,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.clip,
            ),
          ),
          if (isAssigned)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (badge != null) ...[badge, const SizedBox(width: 2)],
                if (onSubmit != null && submission?.isApproved != true)
                  GestureDetector(
                    onTap: onSubmit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Send',
                          style:
                              TextStyle(color: Colors.white, fontSize: 8)),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Grade Cell ─────────────────────────────────────────────────────────────

class _GradeCell extends StatelessWidget {
  final String mark;
  final bool editable;
  final bool isAssigned;
  final bool isApproved;
  final double colWidth;
  final double rowHeight;
  final ValueChanged<String>? onChanged;

  const _GradeCell({
    required this.mark,
    required this.editable,
    required this.isAssigned,
    required this.isApproved,
    required this.colWidth,
    required this.rowHeight,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget inner;
    if (mark.isEmpty) {
      inner = Text('?',
          style: TextStyle(
              fontSize: 13,
              color: editable
                  ? Colors.grey.shade400
                  : Colors.grey.shade300));
    } else {
      inner = GradeMarkBadge(mark: mark);
    }

    Color? bg;
    if (!isAssigned) {
      bg = Colors.grey.shade100;
    } else if (isApproved) {
      bg = Colors.green.shade50;
    }

    return GestureDetector(
      onTap: editable
          ? () => _showPicker(context)
          : null,
      child: Container(
        width: colWidth,
        height: rowHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          border: Border(
            right: BorderSide(color: Colors.grey.shade200),
            bottom: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: inner,
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Select Grade',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final m in const [
                  'plus',
                  'halfPlus',
                  'minus',
                  'absent',
                  'exempt',
                  ''
                ])
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      onChanged?.call(m);
                    },
                    child: m.isEmpty
                        ? Chip(
                            label: const Text('?',
                                style: TextStyle(fontSize: 18)),
                            backgroundColor: Colors.grey.shade200,
                          )
                        : GradeMarkBadge(mark: m),
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
