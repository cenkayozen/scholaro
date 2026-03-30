import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';
import '../../utils/grade_calculator.dart';

class StudentQuizView extends ConsumerWidget {
  final String teacherId;
  final String classId;
  final String studentId;

  const StudentQuizView({
    super.key,
    required this.teacherId,
    required this.classId,
    required this.studentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = ClassParams(teacherId: teacherId, classId: classId);
    final quizzesAsync = ref.watch(quizzesProvider(params));
    final scoresAsync = ref.watch(quizScoresProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Quizzes'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: quizzesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (quizzes) => scoresAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (allScores) {
            final myScores = allScores
                .where((s) => s.studentId == studentId)
                .toList();
            final scoreMap = {for (var s in myScores) s.quizId: s};
            final avg = GradeCalculator.quizAverage(
                studentId, quizzes, allScores);

            return Column(
              children: [
                // Average banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _scoreColor(avg ?? 0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: avg == null
                            ? Colors.grey
                            : _scoreColor(avg)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        avg == null ? '–' : avg.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: avg == null
                              ? Colors.grey
                              : _scoreColor(avg),
                        ),
                      ),
                      const Text('Quiz Average',
                          style: TextStyle(fontSize: 16)),
                      Text('${myScores.length} / ${quizzes.length} quizzes graded'),
                    ],
                  ),
                ),

                // Quiz list
                Expanded(
                  child: quizzes.isEmpty
                      ? const Center(
                          child: Text('No quizzes yet',
                              style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: quizzes.length,
                          itemBuilder: (_, i) {
                            final q = quizzes[i];
                            final score = scoreMap[q.id];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: score == null
                                      ? Colors.grey.shade200
                                      : _scoreColor(score.score)
                                          .withOpacity(0.2),
                                  child: Text(
                                    score == null
                                        ? '–'
                                        : score.score
                                            .toStringAsFixed(0),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: score == null
                                          ? Colors.grey
                                          : _scoreColor(score.score),
                                    ),
                                  ),
                                ),
                                title: Text(q.name),
                                subtitle: score != null
                                    ? Text(
                                        'Graded: ${DateFormat('dd/MM/yyyy').format(score.gradedAt)}')
                                    : const Text('Not graded yet'),
                              ),
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

  Color _scoreColor(double score) {
    if (score >= 85) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }
}
