import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../services/pdf_import_service.dart';
import '../services/pdf_export_service.dart';
import '../models/class_model.dart';
import '../models/student_model.dart';
import '../models/homework_assignment_model.dart';
import '../models/participation_model.dart';
import '../models/quiz_model.dart';
import '../models/portfolio_item_model.dart';

// ── Theme ───────────────────────────────────────────────────────────────────

class ThemeNotifier extends Notifier<ThemeMode> {
  final ThemeMode _initial;
  ThemeNotifier(this._initial);

  static const _key = 'theme_mode';

  @override
  ThemeMode build() => _initial;

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  void toggle() =>
      setTheme(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
}

final themeModeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(
  () => ThemeNotifier(ThemeMode.system),
);

// ── Services ───────────────────────────────────────────────────────────────

final authServiceProvider = Provider((_) => AuthService());
final firestoreServiceProvider = Provider((_) => FirestoreService());
final storageServiceProvider = Provider((_) => StorageService());
final pdfImportServiceProvider = Provider((_) => PdfImportService());
final pdfExportServiceProvider = Provider((_) => PdfExportService());

// ── Auth State ─────────────────────────────────────────────────────────────

final authStateProvider = StreamProvider<User?>(
    (ref) => ref.watch(authServiceProvider).authStateChanges);

final currentRoleProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('role') ?? 'teacher';
});

final studentSessionProvider = FutureProvider<Map<String, String?>>((ref) async {
  final auth = ref.watch(authServiceProvider);
  return auth.getStudentSession();
});

// ── Class Params ────────────────────────────────────────────────────────────

// Passed down through routes via [ClassParams]
class ClassParams {
  final String teacherId;
  final String classId;
  const ClassParams({required this.teacherId, required this.classId});

  @override
  bool operator ==(Object other) =>
      other is ClassParams &&
      teacherId == other.teacherId &&
      classId == other.classId;

  @override
  int get hashCode => Object.hash(teacherId, classId);
}

// ── Classes ────────────────────────────────────────────────────────────────

final classesProvider = StreamProvider.family<List<ClassModel>, String>(
    (ref, teacherId) =>
        ref.watch(firestoreServiceProvider).streamClasses(teacherId));

// ── Students ───────────────────────────────────────────────────────────────

final studentsProvider =
    StreamProvider.family<List<StudentModel>, ClassParams>((ref, params) =>
        ref.watch(firestoreServiceProvider).streamStudents(
            params.teacherId, params.classId));

/// FutureProvider version — use this on Windows for reliable one-shot fetching
final studentsFutureProvider =
    FutureProvider.family<List<StudentModel>, ClassParams>((ref, params) =>
        ref.watch(firestoreServiceProvider).fetchStudents(
            params.teacherId, params.classId));

// ── Homework ───────────────────────────────────────────────────────────────

final homeworkAssignmentsProvider =
    StreamProvider.family<List<HomeworkAssignment>, ClassParams>(
        (ref, params) => ref
            .watch(firestoreServiceProvider)
            .streamHomeworkAssignments(params.teacherId, params.classId));

final homeworkGradesProvider =
    StreamProvider.family<List<HomeworkGrade>, ClassParams>(
        (ref, params) => ref
            .watch(firestoreServiceProvider)
            .streamHomeworkGrades(params.teacherId, params.classId));

// ── Participation ──────────────────────────────────────────────────────────

final participationProvider =
    StreamProvider.family<List<ParticipationEntry>, ClassParams>(
        (ref, params) => ref
            .watch(firestoreServiceProvider)
            .streamParticipation(params.teacherId, params.classId));

// ── Quizzes ────────────────────────────────────────────────────────────────

final quizzesProvider =
    StreamProvider.family<List<QuizModel>, ClassParams>((ref, params) =>
        ref.watch(firestoreServiceProvider).streamQuizzes(
            params.teacherId, params.classId));

final quizScoresProvider =
    StreamProvider.family<List<QuizScore>, ClassParams>((ref, params) =>
        ref.watch(firestoreServiceProvider).streamQuizScores(
            params.teacherId, params.classId));

// ── Portfolio ──────────────────────────────────────────────────────────────

class PortfolioParams {
  final String teacherId;
  final String classId;
  final String studentId;
  const PortfolioParams(
      {required this.teacherId,
      required this.classId,
      required this.studentId});

  @override
  bool operator ==(Object other) =>
      other is PortfolioParams &&
      teacherId == other.teacherId &&
      classId == other.classId &&
      studentId == other.studentId;

  @override
  int get hashCode => Object.hash(teacherId, classId, studentId);
}

final portfolioProvider =
    StreamProvider.family<List<PortfolioItem>, PortfolioParams>(
        (ref, params) => ref
            .watch(firestoreServiceProvider)
            .streamPortfolioItems(
                params.teacherId, params.classId, params.studentId));

// Weekly schedule: key = 'monday_1', value = classId ('' = empty)
final scheduleProvider =
    StreamProvider.family<Map<String, String>, String>((ref, teacherId) {
  return ref.read(firestoreServiceProvider).scheduleStream(teacherId);
});
