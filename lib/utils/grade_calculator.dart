import '../models/homework_assignment_model.dart';
import '../models/quiz_model.dart';

class GradeCalculator {
  /// Returns homework completion percentage for a student.
  /// Exempt assignments and absent days are excluded from denominator.
  static double homeworkPercentage(
    String studentId,
    List<HomeworkAssignment> assignments,
    List<HomeworkGrade> grades,
  ) {
    if (assignments.isEmpty) return 0.0;
    final studentGrades = {
      for (var g in grades.where((g) => g.studentId == studentId))
        g.assignmentId: g
    };

    double earned = 0;
    int denominator = 0;

    for (final assignment in assignments) {
      final grade = studentGrades[assignment.id];
      if (grade == null) {
        // ungraded ("?"): skip entirely, does not affect average
      } else if (grade.mark == 'exempt' || grade.mark == 'absent') {
        // exclude from denominator
      } else {
        denominator++;
        earned += grade.numericValue;
      }
    }

    if (denominator == 0) return 0.0;
    return (earned / denominator) * 100;
  }

  /// Returns participation percentage: (student count / max count) * 100
  static double participationPercentage(
    String studentId,
    Map<String, int> countMap,
  ) {
    final count = countMap[studentId] ?? 0;
    final maxCount =
        countMap.values.isEmpty ? 0 : countMap.values.reduce((a, b) => a > b ? a : b);
    if (maxCount == 0) return 0.0;
    return (count / maxCount) * 100;
  }

  /// Returns quiz average for a student, or null if no scores yet.
  static double? quizAverage(
    String studentId,
    List<QuizModel> quizzes,
    List<QuizScore> scores,
  ) {
    final studentScores = scores.where((s) => s.studentId == studentId).toList();
    if (studentScores.isEmpty) return null;
    final total = studentScores.fold<double>(0, (sum, s) => sum + s.score);
    return total / studentScores.length;
  }
}
