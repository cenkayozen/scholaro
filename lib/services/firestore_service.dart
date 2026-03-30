import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/class_model.dart';
import '../models/student_model.dart';
import '../models/homework_assignment_model.dart';
import '../models/participation_model.dart';
import '../models/quiz_model.dart';
import '../models/portfolio_item_model.dart';

const _uuid = Uuid();

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Paths ──────────────────────────────────────────────────────────────────

  CollectionReference get _teachers => _db.collection('teachers');
  CollectionReference get _studentAccounts => _db.collection('studentAccounts');

  CollectionReference _classes(String teacherId) =>
      _teachers.doc(teacherId).collection('classes');

  CollectionReference _students(String teacherId, String classId) =>
      _classes(teacherId).doc(classId).collection('students');

  CollectionReference _homeworkAssignments(String teacherId, String classId) =>
      _classes(teacherId).doc(classId).collection('homeworkAssignments');

  CollectionReference _homeworkGrades(String teacherId, String classId) =>
      _classes(teacherId).doc(classId).collection('homeworkGrades');

  CollectionReference _participationEntries(
          String teacherId, String classId) =>
      _classes(teacherId).doc(classId).collection('participationEntries');

  CollectionReference _quizzes(String teacherId, String classId) =>
      _classes(teacherId).doc(classId).collection('quizzes');

  CollectionReference _quizScores(String teacherId, String classId) =>
      _classes(teacherId).doc(classId).collection('quizScores');

  CollectionReference _portfolioItems(String teacherId, String classId) =>
      _classes(teacherId).doc(classId).collection('portfolioItems');

  // ── Classes ────────────────────────────────────────────────────────────────

  Future<void> createClass(ClassModel cls) async {
    await _classes(cls.teacherId).doc(cls.id).set(cls.toMap());
  }

  Stream<List<ClassModel>> streamClasses(String teacherId) =>
      _classes(teacherId).orderBy('createdAt', descending: true).snapshots().map(
            (snap) => snap.docs
                .map((d) => ClassModel.fromMap(d.data() as Map<String, dynamic>))
                .toList(),
          );

  Future<void> deleteClass(String teacherId, String classId) async {
    await _classes(teacherId).doc(classId).delete();
  }

  // ── Students ───────────────────────────────────────────────────────────────

  Future<void> saveStudent(StudentModel student) async {
    await _students(student.teacherId, student.classId)
        .doc(student.id)
        .set(student.toMap());

    // Also save lookup record in /studentAccounts/{username}
    await _studentAccounts.doc(student.username).set({
      'username': student.username,
      'password': student.password,
      'firebaseEmail': student.firebaseEmail,
      'studentId': student.id,
      'classId': student.classId,
      'teacherId': student.teacherId,
    });
  }

  Future<void> updateStudentCredentials({
    required StudentModel student,
    required String oldUsername,
    required String newUsername,
    required String newPassword,
  }) async {
    final updated = student.copyWith(
      username: newUsername,
      password: newPassword,
    );
    await _students(student.teacherId, student.classId)
        .doc(student.id)
        .update({'username': newUsername, 'password': newPassword});
    // Remove old account lookup, add new one
    await _studentAccounts.doc(oldUsername).delete();
    await _studentAccounts.doc(newUsername).set({
      'username': newUsername,
      'password': newPassword,
      'firebaseEmail': student.firebaseEmail,
      'studentId': student.id,
      'classId': student.classId,
      'teacherId': student.teacherId,
    });
  }

  Future<void> updateStudentPhoto(
      StudentModel student, String photoUrl) async {
    await _students(student.teacherId, student.classId)
        .doc(student.id)
        .update({'photoUrl': photoUrl});
  }

  Stream<List<StudentModel>> streamStudents(
          String teacherId, String classId) =>
      _students(teacherId, classId)
          .snapshots()
          .map((snap) {
            final list = snap.docs
                .map((d) => StudentModel.fromMap(d.data() as Map<String, dynamic>))
                .toList();
            list.sort((a, b) {
              final cmp = a.order.compareTo(b.order);
              if (cmp != 0) return cmp;
              return a.fullName.compareTo(b.fullName);
            });
            return list;
          });

  /// One-shot fetch — more reliable on Windows than streams
  Future<List<StudentModel>> fetchStudents(
      String teacherId, String classId) async {
    final snap = await _students(teacherId, classId)
        .get(const GetOptions(source: Source.serverAndCache))
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw Exception(
              'Connection timed out. Check your internet connection.'),
        );
    final list = snap.docs
        .map((d) => StudentModel.fromMap(d.data() as Map<String, dynamic>))
        .toList();
    list.sort((a, b) {
      final cmp = a.order.compareTo(b.order);
      if (cmp != 0) return cmp;
      return a.fullName.compareTo(b.fullName);
    });
    return list;
  }

  Future<void> reorderStudents(
      String teacherId, String classId, List<StudentModel> students) async {
    final batch = _db.batch();
    for (int i = 0; i < students.length; i++) {
      batch.update(
        _students(teacherId, classId).doc(students[i].id),
        {'order': i},
      );
    }
    await batch.commit();
  }

  Future<StudentModel?> getStudent(
      String teacherId, String classId, String studentId) async {
    final doc =
        await _students(teacherId, classId).doc(studentId).get();
    if (!doc.exists) return null;
    return StudentModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  // ── Homework Assignments ───────────────────────────────────────────────────

  Future<void> addHomeworkAssignment(HomeworkAssignment assignment) async {
    await _homeworkAssignments(assignment.teacherId, assignment.classId)
        .doc(assignment.id)
        .set(assignment.toMap());
    // Update student count in class
    await _classes(assignment.teacherId)
        .doc(assignment.classId)
        .update({'studentCount': FieldValue.increment(0)});
  }

  Future<void> deleteHomeworkAssignment(
      String teacherId, String classId, String assignmentId) async {
    await _homeworkAssignments(teacherId, classId).doc(assignmentId).delete();
  }

  Future<void> reorderHomeworkAssignments(
      String teacherId, String classId, List<HomeworkAssignment> assignments) async {
    final batch = _db.batch();
    for (int i = 0; i < assignments.length; i++) {
      batch.update(
        _homeworkAssignments(teacherId, classId).doc(assignments[i].id),
        {'order': i},
      );
    }
    await batch.commit();
  }

  Future<void> renameHomeworkAssignment(
      String teacherId, String classId, String assignmentId, String newTitle) async {
    await _homeworkAssignments(teacherId, classId)
        .doc(assignmentId)
        .update({'title': newTitle});
  }

  Stream<List<HomeworkAssignment>> streamHomeworkAssignments(
          String teacherId, String classId) =>
      _homeworkAssignments(teacherId, classId)
          .orderBy('order')
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => HomeworkAssignment.fromMap(
                  d.data() as Map<String, dynamic>))
              .toList());

  // ── Homework Grades ────────────────────────────────────────────────────────

  Future<void> setHomeworkGrade(HomeworkGrade grade) async {
    // Upsert: key is studentId + assignmentId
    final existing = await _homeworkGrades(grade.teacherId, grade.classId)
        .where('studentId', isEqualTo: grade.studentId)
        .where('assignmentId', isEqualTo: grade.assignmentId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      await existing.docs.first.reference.update({
        'mark': grade.mark,
        'gradedAt': Timestamp.fromDate(grade.gradedAt),
      });
    } else {
      await _homeworkGrades(grade.teacherId, grade.classId)
          .doc(grade.id)
          .set(grade.toMap());
    }
  }

  Future<void> deleteHomeworkGrade(
      String teacherId, String classId, String studentId, String assignmentId) async {
    final existing = await _homeworkGrades(teacherId, classId)
        .where('studentId', isEqualTo: studentId)
        .where('assignmentId', isEqualTo: assignmentId)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      await existing.docs.first.reference.delete();
    }
  }

  Stream<List<HomeworkGrade>> streamHomeworkGrades(
          String teacherId, String classId) =>
      _homeworkGrades(teacherId, classId).snapshots().map((snap) => snap.docs
          .map(
              (d) => HomeworkGrade.fromMap(d.data() as Map<String, dynamic>))
          .toList());

  // ── Participation ──────────────────────────────────────────────────────────

  Future<void> addParticipation(ParticipationEntry entry) async {
    await _participationEntries(entry.teacherId, entry.classId)
        .doc(entry.id)
        .set(entry.toMap());
  }

  Future<void> deleteParticipation(
      String teacherId, String classId, String entryId) async {
    await _participationEntries(teacherId, classId).doc(entryId).delete();
  }

  Stream<List<ParticipationEntry>> streamParticipation(
          String teacherId, String classId) =>
      _participationEntries(teacherId, classId)
          .orderBy('date', descending: true)
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => ParticipationEntry.fromMap(
                  d.data() as Map<String, dynamic>))
              .toList());

  // ── Quizzes ────────────────────────────────────────────────────────────────

  Future<void> addQuiz(QuizModel quiz) async {
    await _quizzes(quiz.teacherId, quiz.classId).doc(quiz.id).set(quiz.toMap());
  }

  Future<void> deleteQuiz(
      String teacherId, String classId, String quizId) async {
    await _quizzes(teacherId, classId).doc(quizId).delete();
  }

  Stream<List<QuizModel>> streamQuizzes(String teacherId, String classId) =>
      _quizzes(teacherId, classId)
          .orderBy('createdAt')
          .snapshots()
          .map((snap) => snap.docs
              .map(
                  (d) => QuizModel.fromMap(d.data() as Map<String, dynamic>))
              .toList());

  Future<void> setQuizScore(QuizScore score) async {
    final existing = await _quizScores(score.teacherId, score.classId)
        .where('studentId', isEqualTo: score.studentId)
        .where('quizId', isEqualTo: score.quizId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      await existing.docs.first.reference.update({
        'score': score.score,
        'gradedAt': Timestamp.fromDate(score.gradedAt),
      });
    } else {
      await _quizScores(score.teacherId, score.classId)
          .doc(score.id)
          .set(score.toMap());
    }
  }

  Stream<List<QuizScore>> streamQuizScores(
          String teacherId, String classId) =>
      _quizScores(teacherId, classId).snapshots().map((snap) => snap.docs
          .map((d) => QuizScore.fromMap(d.data() as Map<String, dynamic>))
          .toList());

  // ── Portfolio ──────────────────────────────────────────────────────────────

  Future<void> addPortfolioItem(PortfolioItem item) async {
    await _portfolioItems(item.teacherId, item.classId)
        .doc(item.id)
        .set(item.toMap());
  }

  Future<void> deletePortfolioItem(
      String teacherId, String classId, String itemId) async {
    await _portfolioItems(teacherId, classId).doc(itemId).delete();
  }

  Stream<List<PortfolioItem>> streamPortfolioItems(
          String teacherId, String classId, String studentId) =>
      _portfolioItems(teacherId, classId)
          .where('studentId', isEqualTo: studentId)
          .snapshots()
          .map((snap) {
            final items = snap.docs
                .map((d) =>
                    PortfolioItem.fromMap(d.data() as Map<String, dynamic>))
                .toList();
            items.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
            return items;
          });

  // ── Helper ─────────────────────────────────────────────────────────────────

  FirebaseFirestore get firestoreInstance => _db;

  String generateId() => _uuid.v4();

  // ── Weekly Schedule ──────────────────────────────────────────────────────────
  Stream<Map<String, String>> scheduleStream(String teacherId) {
    return _db
        .collection('teachers')
        .doc(teacherId)
        .collection('settings')
        .doc('schedule')
        .snapshots()
        .map((doc) {
      if (!doc.exists) return <String, String>{};
      return Map<String, String>.from(
          (doc.data() ?? {}).map((k, v) => MapEntry(k, v.toString())));
    });
  }

  Future<void> updateScheduleEntry(
      String teacherId, String key, String classId) async {
    await _db
        .collection('teachers')
        .doc(teacherId)
        .collection('settings')
        .doc('schedule')
        .set({key: classId}, SetOptions(merge: true));
  }
}
