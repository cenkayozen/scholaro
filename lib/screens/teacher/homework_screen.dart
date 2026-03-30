import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../models/homework_assignment_model.dart';
import '../../models/monitor_grade_model.dart';
import '../../models/student_model.dart';
import '../../utils/grade_calculator.dart';
import '../../widgets/grade_mark_widget.dart';
import '../../widgets/student_avatar.dart';

class HomeworkScreen extends ConsumerStatefulWidget {
  final String teacherId;
  final String classId;
  final String className;

  const HomeworkScreen({
    super.key,
    required this.teacherId,
    required this.classId,
    required this.className,
  });

  @override
  ConsumerState<HomeworkScreen> createState() => _HomeworkScreenState();
}

// Provider for pending monitor submission count
final _pendingMonitorCountProvider =
    StreamProvider.family<int, ClassParams>((ref, params) => ref
        .watch(firestoreServiceProvider)
        .streamPendingMonitorCount(params.teacherId, params.classId));

// Provider for monitor submissions stream
final _monitorSubmissionsTeacherProvider =
    StreamProvider.family<List<MonitorSubmission>, ClassParams>((ref, params) =>
        ref
            .watch(firestoreServiceProvider)
            .streamMonitorSubmissions(params.teacherId, params.classId));

class _HomeworkScreenState extends ConsumerState<HomeworkScreen> {
  final _leftVertCtrl = ScrollController();
  final _rightVertCtrl = ScrollController();
  final _horizBodyCtrl = ScrollController();
  final _horizHeaderCtrl = ScrollController();
  bool _syncing = false;

  // Responsive dimensions – calculated in build() based on screen width
  late double _rowHeight;
  late double _headerHeight;
  late double _hwColWidth;
  late double _noColWidth;
  late double _leftPanelWidth;
  late double _nameFontSize;
  late double _pctFontSize;
  late double _avatarRadius;
  late double _pctColWidth;
  late bool _showHeaderIcons;

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
    _pctFontSize = narrow ? 9.0 : 11.0;
    _avatarRadius = narrow ? 10.0 : 14.0;
    _pctColWidth = narrow ? 38.0 : 46.0;
    _showHeaderIcons = !narrow;
  }

  @override
  Widget build(BuildContext context) {
    _initDimensions(context);
    final params =
        ClassParams(teacherId: widget.teacherId, classId: widget.classId);
    final assignmentsAsync = ref.watch(homeworkAssignmentsProvider(params));
    final studentsAsync = ref.watch(studentsProvider(params));
    final gradesAsync = ref.watch(homeworkGradesProvider(params));
    final pendingCountAsync = ref.watch(_pendingMonitorCountProvider(params));
    final pendingCount = pendingCountAsync.value ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.className} – Homework'),
        leading: BackButton(onPressed: () => context.pop()),
        actions: [
          // Monitor approval badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.how_to_reg_outlined),
                tooltip: 'Monitor approvals',
                onPressed: () => _showMonitorApprovals(
                    context, ref, assignmentsAsync.value ?? [],
                    studentsAsync.value ?? []),
              ),
              if (pendingCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text('$pendingCount',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add_task),
            tooltip: 'Add assignment',
            onPressed: () => _addAssignment(
                context, ref, assignmentsAsync.value?.length ?? 0),
          ),
          IconButton(
            icon: const Icon(Icons.list_alt_outlined),
            tooltip: 'Manage assignments',
            onPressed: () => _manageAssignments(
                context, ref, assignmentsAsync.value ?? []),
          ),
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Home',
            onPressed: () => context.go('/teacher/home'),
          ),
        ],
      ),
      body: assignmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (assignments) => studentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (students) => gradesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (grades) =>
                _buildTable(context, assignments, students, grades),
          ),
        ),
      ),
    );
  }

  Widget _buildTable(
    BuildContext context,
    List<HomeworkAssignment> assignments,
    List<StudentModel> students,
    List<HomeworkGrade> grades,
  ) {
    if (assignments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('No assignments yet',
                style: TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Assignment'),
              onPressed: () => _addAssignment(context, ref, 0),
            ),
          ],
        ),
      );
    }

    final headerBg = Theme.of(context).colorScheme.surfaceContainerHighest;
    final stripeBg = Theme.of(context).colorScheme.surfaceContainerLowest;
    final dividerColor = Theme.of(context).dividerColor;
    final rightWidth = _noColWidth + _hwColWidth * assignments.length;

    return Column(
      children: [
        // Legend bar – horizontally scrollable so it never overflows on narrow screens
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Row(
              children: [
                const Text('Grades: ',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
                const _LegendChip(mark: 'plus'),
                const _LegendChip(mark: 'halfPlus'),
                const _LegendChip(mark: 'minus'),
                const _LegendChip(mark: 'absent'),
                const _LegendChip(mark: 'exempt'),
                const SizedBox(width: 12),
                Icon(Icons.format_paint_outlined,
                    size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text('= apply to all',
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey.shade500)),
              ],
            ),
          ),
        ),
        // Table body
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── LEFT FIXED PANEL ──
              Container(
                width: _leftPanelWidth,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: dividerColor.withValues(alpha: 0.5),
                      blurRadius: 4,
                      offset: const Offset(2, 0),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      height: _headerHeight,
                      color: headerBg,
                      child: Row(
                        children: [
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text('Student',
                                style: TextStyle(fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                          ),
                          Container(
                            width: _pctColWidth,
                            alignment: Alignment.center,
                            child: const Text('%',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                    // Student rows
                    Expanded(
                      child: ListView.builder(
                        controller: _leftVertCtrl,
                        itemExtent: _rowHeight,
                        itemCount: students.length,
                        itemBuilder: (_, i) {
                          final student = students[i];
                          final pct = GradeCalculator.homeworkPercentage(
                              student.id, assignments, grades);
                          return Container(
                            height: _rowHeight,
                            color: i.isOdd ? stripeBg : null,
                            child: Row(
                              children: [
                                const SizedBox(width: 6),
                                StudentAvatar(
                                    photoUrl: student.photoUrl,
                                    name: student.fullName,
                                    radius: _avatarRadius,
                                    tappable: true),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Tooltip(
                                    message: student.fullName,
                                    triggerMode: TooltipTriggerMode.tap,
                                    preferBelow: false,
                                    child: Text(
                                      student.fullName,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: _nameFontSize),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: _pctColWidth,
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${pct.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: _pctFontSize,
                                      color: pct >= 70
                                          ? Colors.green
                                          : pct >= 50
                                              ? Colors.orange
                                              : Colors.red,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // ── RIGHT SCROLLABLE PANEL ──
              Expanded(
                child: Column(
                  children: [
                    // Header (syncs horizontally with body, not user-draggable)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      controller: _horizHeaderCtrl,
                      physics: const NeverScrollableScrollPhysics(),
                      child: SizedBox(
                        width: rightWidth,
                        height: _headerHeight,
                        child: Container(
                          clipBehavior: Clip.hardEdge,
                          decoration: BoxDecoration(color: headerBg),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // "No" column header
                              SizedBox(
                                width: _noColWidth,
                                child: const Center(
                                  child: Text('No',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                              // Assignment column headers
                              ...assignments.map((a) => SizedBox(
                                    width: _hwColWidth,
                                    height: _headerHeight,
                                    child: _showHeaderIcons
                                        // ── Desktop: title + 3 icons ──
                                        ? Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              GestureDetector(
                                                onTap: () => _renameAssignment(
                                                    context, ref, a),
                                                child: Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(horizontal: 4),
                                                  child: Text(a.title,
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 11,
                                                          decoration:
                                                              TextDecoration
                                                                  .underline,
                                                          decorationStyle:
                                                              TextDecorationStyle
                                                                  .dotted),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      maxLines: 2,
                                                      textAlign:
                                                          TextAlign.center),
                                                ),
                                              ),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  InkWell(
                                                    onTap: () =>
                                                        _applyToAllDialog(
                                                            context,
                                                            ref,
                                                            a,
                                                            students,
                                                            grades),
                                                    child: const Padding(
                                                      padding:
                                                          EdgeInsets.all(3),
                                                      child: Icon(
                                                          Icons
                                                              .format_paint_outlined,
                                                          size: 14,
                                                          color: Colors.indigo),
                                                    ),
                                                  ),
                                                  InkWell(
                                                    onTap: () =>
                                                        _renameAssignment(
                                                            context, ref, a),
                                                    child: const Padding(
                                                      padding:
                                                          EdgeInsets.all(3),
                                                      child: Icon(
                                                          Icons.edit_outlined,
                                                          size: 14,
                                                          color: Colors.teal),
                                                    ),
                                                  ),
                                                  InkWell(
                                                    onTap: () =>
                                                        _deleteAssignment(
                                                            context, ref, a),
                                                    child: const Padding(
                                                      padding:
                                                          EdgeInsets.all(3),
                                                      child: Icon(
                                                          Icons.delete_outline,
                                                          size: 14,
                                                          color: Colors.red),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          )
                                        // ── Mobile: tap → bottom-sheet menu ──
                                        : InkWell(
                                            onTap: () => _headerMenu(
                                                context, ref, a, students,
                                                grades),
                                            child: Center(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 3),
                                                child: Text(a.title,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 10),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 2,
                                                    textAlign:
                                                        TextAlign.center),
                                              ),
                                            ),
                                          ),
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Data rows (horizontally + vertically scrollable)
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        controller: _horizBodyCtrl,
                        child: SizedBox(
                          width: rightWidth,
                          child: ListView.builder(
                            controller: _rightVertCtrl,
                            itemExtent: _rowHeight,
                            itemCount: students.length,
                            itemBuilder: (_, i) {
                              final student = students[i];
                              final gradeMap = {
                                for (var g in grades.where(
                                    (g) => g.studentId == student.id))
                                  g.assignmentId: g
                              };
                              return Container(
                                height: _rowHeight,
                                color: i.isOdd ? stripeBg : null,
                                child: Row(
                                  children: [
                                    // "No" cell
                                    SizedBox(
                                      width: _noColWidth,
                                      child: Center(
                                        child: Text(student.schoolNumber,
                                            style: TextStyle(
                                                fontSize: _nameFontSize)),
                                      ),
                                    ),
                                    // Grade cells
                                    ...assignments.map((a) {
                                      final existing = gradeMap[a.id];
                                      return SizedBox(
                                        width: _hwColWidth,
                                        child: Center(
                                          child: GradeMarkButton(
                                            mark: existing?.mark ?? '',
                                            onChanged: (newMark) {
                                              _setGrade(ref, student.id, a.id,
                                                  newMark, existing?.id);
                                            },
                                          ),
                                        ),
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
          ),
        ),
      ],
    );
  }

  Future<void> _headerMenu(
    BuildContext context,
    WidgetRef ref,
    HomeworkAssignment a,
    List<StudentModel> students,
    List<HomeworkGrade> grades,
  ) async {
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(a.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const Divider(height: 1),
            ListTile(
              leading:
                  const Icon(Icons.format_paint_outlined, color: Colors.indigo),
              title: const Text('Apply grade to all students'),
              onTap: () {
                Navigator.pop(ctx);
                _applyToAllDialog(context, ref, a, students, grades);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.teal),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(ctx);
                _renameAssignment(context, ref, a);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title:
                  const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteAssignment(context, ref, a);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyToAllDialog(
    BuildContext context,
    WidgetRef ref,
    HomeworkAssignment assignment,
    List<StudentModel> students,
    List<HomeworkGrade> grades,
  ) async {
    final mark = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Apply to ALL – ${assignment.title}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Choose a grade to apply to all ${students.length} students:',
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: kMarkLabels.entries
                  .where((e) => e.key.isNotEmpty)
                  .map((e) {
                final color = kMarkColors[e.key]!;
                return InkWell(
                  onTap: () => Navigator.pop(ctx, e.key),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      border: Border.all(color: color, width: 1.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(e.value,
                            style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(GradeMarkButton.markDescription(e.key),
                            style: TextStyle(color: color)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
        ],
      ),
    );
    if (mark == null) return;
    await _applyToAll(ref, assignment.id, mark, students, grades);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${kMarkLabels[mark]} applied to all ${students.length} students'),
        backgroundColor: kMarkColors[mark],
      ));
    }
  }

  Future<void> _applyToAll(
    WidgetRef ref,
    String assignmentId,
    String mark,
    List<StudentModel> students,
    List<HomeworkGrade> grades,
  ) async {
    final fs = ref.read(firestoreServiceProvider);
    for (final student in students) {
      final existing = grades
          .where((g) =>
              g.studentId == student.id && g.assignmentId == assignmentId)
          .firstOrNull;
      await fs.setHomeworkGrade(HomeworkGrade(
        id: existing?.id ?? fs.generateId(),
        studentId: student.id,
        assignmentId: assignmentId,
        classId: widget.classId,
        teacherId: widget.teacherId,
        mark: mark,
        gradedAt: DateTime.now(),
      ));
    }
  }

  Future<void> _addAssignment(
      BuildContext context, WidgetRef ref, int currentCount) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Assignment'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Assignment name / description',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add')),
        ],
      ),
    );
    if (confirmed != true || ctrl.text.trim().isEmpty) return;

    final fs = ref.read(firestoreServiceProvider);
    await fs.addHomeworkAssignment(HomeworkAssignment(
      id: fs.generateId(),
      title: ctrl.text.trim(),
      classId: widget.classId,
      teacherId: widget.teacherId,
      order: currentCount,
      createdAt: DateTime.now(),
    ));
  }

  Future<void> _renameAssignment(
      BuildContext context, WidgetRef ref, HomeworkAssignment a) async {
    final ctrl = TextEditingController(text: a.title);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Assignment'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Assignment name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (confirmed != true) return;
    final newTitle = ctrl.text.trim();
    if (newTitle.isEmpty || newTitle == a.title) return;
    await ref.read(firestoreServiceProvider).renameHomeworkAssignment(
        widget.teacherId, widget.classId, a.id, newTitle);
  }

  Future<void> _deleteAssignment(
      BuildContext context, WidgetRef ref, HomeworkAssignment a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Assignment'),
        content: Text('Delete "${a.title}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(firestoreServiceProvider)
        .deleteHomeworkAssignment(widget.teacherId, widget.classId, a.id);
  }

  Future<void> _manageAssignments(
    BuildContext context,
    WidgetRef ref,
    List<HomeworkAssignment> assignments,
  ) async {
    if (assignments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No assignments yet.')),
      );
      return;
    }
    final local = List<HomeworkAssignment>.from(assignments);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                child: Row(
                  children: [
                    const Text('Manage Assignments',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  itemCount: local.length,
                  onReorder: (oldIndex, newIndex) async {
                    if (newIndex > oldIndex) newIndex--;
                    setState(() {
                      final item = local.removeAt(oldIndex);
                      local.insert(newIndex, item);
                    });
                    await ref
                        .read(firestoreServiceProvider)
                        .reorderHomeworkAssignments(
                            widget.teacherId, widget.classId, local);
                  },
                  itemBuilder: (_, i) {
                    final a = local[i];
                    return ListTile(
                      key: ValueKey(a.id),
                      leading: const Icon(Icons.drag_handle, color: Colors.grey),
                      title: Text(a.title),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (dctx) => AlertDialog(
                              title: const Text('Delete Assignment'),
                              content: Text('Delete "${a.title}"?'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dctx, false),
                                    child: const Text('Cancel')),
                                FilledButton(
                                    style: FilledButton.styleFrom(
                                        backgroundColor: Colors.red),
                                    onPressed: () =>
                                        Navigator.pop(dctx, true),
                                    child: const Text('Delete')),
                              ],
                            ),
                          );
                          if (confirm != true) return;
                          await ref
                              .read(firestoreServiceProvider)
                              .deleteHomeworkAssignment(
                                  widget.teacherId, widget.classId, a.id);
                          setState(() => local.remove(a));
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showMonitorApprovals(
    BuildContext context,
    WidgetRef ref,
    List<HomeworkAssignment> assignments,
    List<StudentModel> students,
  ) async {
    final params =
        ClassParams(teacherId: widget.teacherId, classId: widget.classId);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, sc) => Consumer(
          builder: (ctx, r, _) {
            final subsAsync =
                r.watch(_monitorSubmissionsTeacherProvider(params));
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.how_to_reg_outlined,
                          color: Color(0xFF1565C0)),
                      SizedBox(width: 8),
                      Text('Monitor Submissions',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: subsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (subs) {
                      if (subs.isEmpty) {
                        return const Center(
                            child: Text('No submissions yet.',
                                style: TextStyle(color: Colors.grey)));
                      }
                      return ListView.builder(
                        controller: sc,
                        itemCount: subs.length,
                        itemBuilder: (_, i) {
                          final sub = subs[i];
                          final assignment = assignments
                              .where((a) => a.id == sub.assignmentId)
                              .firstOrNull;
                          final monitor = students
                              .where((s) => s.id == sub.monitorStudentId)
                              .firstOrNull;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: sub.isApproved
                                  ? Colors.green
                                  : Colors.orange,
                              child: Icon(
                                sub.isApproved
                                    ? Icons.check
                                    : Icons.pending,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            title: Text(
                                assignment?.title ?? sub.assignmentId),
                            subtitle: Text(
                              'Monitor: ${monitor?.fullName ?? sub.monitorStudentId}\n'
                              'Submitted: ${_fmt(sub.submittedAt)}'
                              '${sub.isApproved ? '\nApproved: ${_fmt(sub.approvedAt!)}' : ''}',
                            ),
                            trailing: sub.isPending
                                ? FilledButton(
                                    style: FilledButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF2E7D32),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12)),
                                    onPressed: () async {
                                      await r
                                          .read(firestoreServiceProvider)
                                          .approveMonitorSubmission(
                                              sub.id, sub);
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx)
                                            .showSnackBar(const SnackBar(
                                          content: Text('Grades approved!'),
                                          backgroundColor:
                                              Color(0xFF2E7D32),
                                        ));
                                      }
                                    },
                                    child: const Text('Approve',
                                        style: TextStyle(fontSize: 12)),
                                  )
                                : const Chip(
                                    label: Text('Approved',
                                        style: TextStyle(fontSize: 11)),
                                    backgroundColor: Color(0xFFE8F5E9),
                                  ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Future<void> _setGrade(WidgetRef ref, String studentId, String assignmentId,
      String mark, String? existingId) async {
    final fs = ref.read(firestoreServiceProvider);
    if (mark.isEmpty) {
      await fs.deleteHomeworkGrade(
          widget.teacherId, widget.classId, studentId, assignmentId);
    } else {
      await fs.setHomeworkGrade(HomeworkGrade(
        id: existingId ?? fs.generateId(),
        studentId: studentId,
        assignmentId: assignmentId,
        classId: widget.classId,
        teacherId: widget.teacherId,
        mark: mark,
        gradedAt: DateTime.now(),
      ));
    }
  }
}

class _LegendChip extends StatelessWidget {
  final String mark;
  const _LegendChip({required this.mark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GradeMarkBadge(mark: mark),
    );
  }
}
