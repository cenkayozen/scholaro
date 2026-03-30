import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/providers.dart';
import '../../models/quiz_model.dart';
import '../../models/student_model.dart';
import '../../utils/grade_calculator.dart';
import '../../widgets/student_avatar.dart';

class QuizScreen extends ConsumerStatefulWidget {
  final String teacherId;
  final String classId;
  final String className;

  const QuizScreen({
    super.key,
    required this.teacherId,
    required this.classId,
    required this.className,
  });

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  final _leftVertCtrl = ScrollController();
  final _rightVertCtrl = ScrollController();
  final _horizBodyCtrl = ScrollController();
  final _horizHeaderCtrl = ScrollController();
  bool _syncing = false;

  static const double _rowHeight = 52.0;
  static const double _headerHeight = 60.0;
  static const double _quizColWidth = 80.0;
  static const double _leftPanelWidth = 200.0;

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

  @override
  Widget build(BuildContext context) {
    final params =
        ClassParams(teacherId: widget.teacherId, classId: widget.classId);
    final quizzesAsync = ref.watch(quizzesProvider(params));
    final studentsAsync = ref.watch(studentsProvider(params));
    final scoresAsync = ref.watch(quizScoresProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.className} – Quizzes'),
        leading: BackButton(onPressed: () => context.pop()),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add quiz',
            onPressed: () => _addQuiz(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Home',
            onPressed: () => context.go('/teacher/home'),
          ),
        ],
      ),
      body: quizzesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (quizzes) => studentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (students) => scoresAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (scores) =>
                _buildTable(context, ref, quizzes, students, scores),
          ),
        ),
      ),
    );
  }

  Widget _buildTable(
    BuildContext context,
    WidgetRef ref,
    List<QuizModel> quizzes,
    List<StudentModel> students,
    List<QuizScore> scores,
  ) {
    if (quizzes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.quiz_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('No quizzes yet',
                style: TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Quiz'),
              onPressed: () => _addQuiz(context, ref),
            ),
          ],
        ),
      );
    }

    final headerBg = Theme.of(context).colorScheme.surfaceContainerHighest;
    final stripeBg = Theme.of(context).colorScheme.surfaceContainerLowest;
    final dividerColor = Theme.of(context).dividerColor;
    final rightWidth = _quizColWidth * quizzes.length;

    return Row(
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
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Student',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Container(
                      width: 46,
                      alignment: Alignment.center,
                      child: const Text('Avg',
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
                    final avg = GradeCalculator.quizAverage(
                        student.id, quizzes, scores);
                    return Container(
                      height: _rowHeight,
                      color: i.isOdd ? stripeBg : null,
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          StudentAvatar(
                              photoUrl: student.photoUrl,
                              name: student.fullName,
                              radius: 14,
                              tappable: true),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Tooltip(
                              message: student.fullName,
                              triggerMode: TooltipTriggerMode.tap,
                              preferBelow: false,
                              child: Text(
                                student.fullName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                          Container(
                            width: 46,
                            alignment: Alignment.center,
                            child: Text(
                              avg == null ? '–' : avg.toStringAsFixed(1),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: avg == null
                                    ? Colors.grey
                                    : _scoreColor(avg),
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
              // Header (synced horizontally, not user-draggable)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: _horizHeaderCtrl,
                physics: const NeverScrollableScrollPhysics(),
                child: SizedBox(
                  width: rightWidth,
                  height: _headerHeight,
                  child: Container(
                    color: headerBg,
                    child: Row(
                      children: quizzes
                          .map((q) => SizedBox(
                                width: _quizColWidth,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4),
                                      child: Text(q.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                          textAlign: TextAlign.center),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          size: 14, color: Colors.red),
                                      onPressed: () =>
                                          _deleteQuiz(context, ref, q),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
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
                        final scoreMap = {
                          for (var s
                              in scores.where((s) => s.studentId == student.id))
                            s.quizId: s
                        };
                        return Container(
                          height: _rowHeight,
                          color: i.isOdd ? stripeBg : null,
                          child: Row(
                            children: quizzes.map((q) {
                              final existing = scoreMap[q.id];
                              return SizedBox(
                                width: _quizColWidth,
                                child: Center(
                                  child: InkWell(
                                    onTap: () => _editScore(context, ref,
                                        student, q, existing?.score),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: existing != null
                                            ? _scoreColor(existing.score)
                                                .withValues(alpha: 0.1)
                                            : Colors.grey.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: existing != null
                                              ? _scoreColor(existing.score)
                                              : Colors.grey.shade300,
                                        ),
                                      ),
                                      child: Text(
                                        existing != null
                                            ? existing.score.toStringAsFixed(0)
                                            : '–',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: existing != null
                                              ? _scoreColor(existing.score)
                                              : Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
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

  Color _scoreColor(double score) {
    if (score >= 85) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  Future<void> _addQuiz(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Quiz / Test'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Quiz name (e.g. Quiz 1, Midterm)',
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
    await fs.addQuiz(QuizModel(
      id: fs.generateId(),
      name: ctrl.text.trim(),
      classId: widget.classId,
      teacherId: widget.teacherId,
      createdAt: DateTime.now(),
    ));
  }

  Future<void> _deleteQuiz(
      BuildContext context, WidgetRef ref, QuizModel quiz) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Quiz'),
        content: Text('Delete "${quiz.name}"?'),
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
        .deleteQuiz(widget.teacherId, widget.classId, quiz.id);
  }

  Future<void> _editScore(BuildContext context, WidgetRef ref,
      StudentModel student, QuizModel quiz, double? existing) async {
    final ctrl =
        TextEditingController(text: existing?.toStringAsFixed(0) ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${student.fullName} – ${quiz.name}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Score (0–100)',
            border: OutlineInputBorder(),
          ),
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

    final score = double.tryParse(ctrl.text);
    if (score == null || score < 0 || score > 100) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter a valid score (0–100)')));
      }
      return;
    }

    final fs = ref.read(firestoreServiceProvider);
    await fs.setQuizScore(QuizScore(
      id: fs.generateId(),
      studentId: student.id,
      quizId: quiz.id,
      classId: widget.classId,
      teacherId: widget.teacherId,
      score: score,
      gradedAt: DateTime.now(),
    ));
  }
}
