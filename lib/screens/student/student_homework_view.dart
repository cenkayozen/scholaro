import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/providers.dart';
import '../../models/homework_assignment_model.dart';
import '../../utils/grade_calculator.dart';
import '../../widgets/grade_mark_widget.dart';

class StudentHomeworkView extends ConsumerWidget {
  final String teacherId;
  final String classId;
  final String studentId;

  const StudentHomeworkView({
    super.key,
    required this.teacherId,
    required this.classId,
    required this.studentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = ClassParams(teacherId: teacherId, classId: classId);
    final assignmentsAsync = ref.watch(homeworkAssignmentsProvider(params));
    final gradesAsync = ref.watch(homeworkGradesProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Homework'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: assignmentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (assignments) => gradesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (allGrades) {
            final myGrades = allGrades
                .where((g) => g.studentId == studentId)
                .toList();
            final gradeMap = {
              for (var g in myGrades) g.assignmentId: g
            };
            final pct = GradeCalculator.homeworkPercentage(
                studentId, assignments, allGrades);

            return Column(
              children: [
                // Summary banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _pctColor(pct).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _pctColor(pct)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${pct.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: _pctColor(pct),
                        ),
                      ),
                      const Text('Completion Rate',
                          style: TextStyle(fontSize: 16)),
                      Text(
                          '${myGrades.where((g) => g.mark == 'plus' || g.mark == 'halfPlus').length} / ${assignments.where((a) => !_isExcluded(gradeMap[a.id])).length} assignments'),
                    ],
                  ),
                ),

                // Assignment list
                Expanded(
                  child: assignments.isEmpty
                      ? const Center(
                          child: Text('No assignments yet',
                              style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: assignments.length,
                          itemBuilder: (_, i) {
                            final a = assignments[i];
                            final grade = gradeMap[a.id];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(a.title),
                                subtitle: grade != null
                                    ? Text(
                                        'Graded: ${DateFormat('dd/MM/yyyy').format(grade.gradedAt)}')
                                    : const Text('Not graded yet'),
                                trailing: GradeMarkBadge(
                                    mark: grade?.mark ?? ''),
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

  bool _isExcluded(HomeworkGrade? g) =>
      g?.mark == 'exempt' || g?.mark == 'absent';

  Color _pctColor(double pct) {
    if (pct >= 70) return Colors.green;
    if (pct >= 50) return Colors.orange;
    return Colors.red;
  }
}
