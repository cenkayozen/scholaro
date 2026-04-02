import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/class_model.dart';
import '../models/student_model.dart';
import '../models/homework_assignment_model.dart';
import '../models/participation_model.dart';
import '../models/quiz_model.dart';
import '../models/portfolio_item_model.dart';
import '../models/monitor_grade_model.dart';

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

  CollectionReference _monitorGrades(String teacherId, String classId) =>
      _classes(teacherId).doc(classId).collection('monitorGrades');

  CollectionReference _monitorSubmissions(String teacherId, String classId) =>
      _classes(teacherId).doc(classId).collection('monitorSubmissions');

  CollectionReference get _teacherFcmTokens => _db.collection('teacherFcmTokens');

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

  Future<void> deleteStudent(StudentModel student) async {
    // Remove student document
    await _students(student.teacherId, student.classId)
        .doc(student.id)
        .delete();
    // Remove login account lookup
    await _studentAccounts.doc(student.username).delete();
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
              final na = int.tryParse(a.schoolNumber);
              final nb = int.tryParse(b.schoolNumber);
              if (na != null && nb != null) return na.compareTo(nb);
              return a.schoolNumber.compareTo(b.schoolNumber);
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
      final na = int.tryParse(a.schoolNumber);
      final nb = int.tryParse(b.schoolNumber);
      if (na != null && nb != null) return na.compareTo(nb);
      return a.schoolNumber.compareTo(b.schoolNumber);
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

  Future<List<HomeworkAssignment>> fetchHomeworkAssignments(
      String teacherId, String classId) async {
    final snap = await _homeworkAssignments(teacherId, classId)
        .orderBy('order')
        .get();
    return snap.docs
        .map((d) =>
            HomeworkAssignment.fromMap(d.data() as Map<String, dynamic>))
        .toList();
  }

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

  // ── Monitor Role Assignment ──────────────────────────────────────────────────

  Future<void> setStudentMonitorRole(
      String teacherId, String classId, String studentId,
      {required bool isMonitor, required List<String> assignmentIds}) async {
    await _students(teacherId, classId).doc(studentId).update({
      'isHomeworkMonitor': isMonitor,
      'monitorAssignmentIds': assignmentIds,
    });
  }

  /// Returns student doc + account doc if the student is a valid homework monitor.
  /// Throws if not found or not a monitor.
  Future<Map<String, dynamic>> verifyHomeworkMonitor(
      String username, String password) async {
    final accountSnap =
        await _studentAccounts.doc(username).get();
    if (!accountSnap.exists) throw Exception('Username not found');

    final account = accountSnap.data()! as Map<String, dynamic>;
    if (account['password'] as String != password) {
      throw Exception('Incorrect password');
    }

    final studentId = account['studentId'] as String;
    final classId = account['classId'] as String;

    final studentSnap =
        await _students(account['teacherId'] as String, classId)
            .doc(studentId)
            .get();
    if (!studentSnap.exists) throw Exception('Student not found');

    final student = studentSnap.data()! as Map<String, dynamic>;
    if (student['isHomeworkMonitor'] != true) {
      throw Exception('No Homework Monitor access');
    }

    return {
      'account': account,
      'student': student,
    };
  }

  // ── Monitor Grades ───────────────────────────────────────────────────────────

  Future<List<MonitorGrade>> fetchMonitorGradesForSubmission(
      String teacherId, String classId,
      String monitorStudentId, String assignmentId) async {
    final snap = await _monitorGrades(teacherId, classId)
        .where('monitorStudentId', isEqualTo: monitorStudentId)
        .where('assignmentId', isEqualTo: assignmentId)
        .get();
    return snap.docs
        .map((d) => MonitorGrade.fromMap(d.data() as Map<String, dynamic>))
        .toList();
  }

  Stream<List<MonitorGrade>> streamMonitorGrades(
          String teacherId, String classId) =>
      _monitorGrades(teacherId, classId).snapshots().map((snap) => snap.docs
          .map((d) => MonitorGrade.fromMap(d.data() as Map<String, dynamic>))
          .toList());

  Future<void> setMonitorGrade(MonitorGrade grade) async {
    final existing = await _monitorGrades(grade.teacherId, grade.classId)
        .where('monitorStudentId', isEqualTo: grade.monitorStudentId)
        .where('studentId', isEqualTo: grade.studentId)
        .where('assignmentId', isEqualTo: grade.assignmentId)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      await existing.docs.first.reference
          .update({'mark': grade.mark, 'gradedAt': Timestamp.fromDate(grade.gradedAt)});
    } else {
      await _monitorGrades(grade.teacherId, grade.classId)
          .doc(grade.id)
          .set(grade.toMap());
    }
  }

  Future<void> deleteMonitorGrade(String teacherId, String classId,
      String monitorStudentId, String studentId, String assignmentId) async {
    final existing = await _monitorGrades(teacherId, classId)
        .where('monitorStudentId', isEqualTo: monitorStudentId)
        .where('studentId', isEqualTo: studentId)
        .where('assignmentId', isEqualTo: assignmentId)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      await existing.docs.first.reference.delete();
    }
  }

  // ── Monitor Submissions ──────────────────────────────────────────────────────

  Stream<List<MonitorSubmission>> streamMonitorSubmissions(
          String teacherId, String classId) =>
      _monitorSubmissions(teacherId, classId)
          .orderBy('submittedAt', descending: true)
          .snapshots()
          .map((snap) => snap.docs
              .map((d) =>
                  MonitorSubmission.fromMap(d.data() as Map<String, dynamic>))
              .toList());

  /// Returns the existing submission for this monitor + assignment, or null.
  Future<MonitorSubmission?> getMonitorSubmission(String teacherId,
      String classId, String monitorStudentId, String assignmentId) async {
    final snap = await _monitorSubmissions(teacherId, classId)
        .where('monitorStudentId', isEqualTo: monitorStudentId)
        .where('assignmentId', isEqualTo: assignmentId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return MonitorSubmission.fromMap(
        snap.docs.first.data() as Map<String, dynamic>);
  }

  Future<void> submitMonitorGrades(MonitorSubmission submission) async {
    // Upsert the submission
    final existing = await _monitorSubmissions(
            submission.teacherId, submission.classId)
        .where('monitorStudentId', isEqualTo: submission.monitorStudentId)
        .where('assignmentId', isEqualTo: submission.assignmentId)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      await existing.docs.first.reference.update({
        'status': 'pending',
        'submittedAt': Timestamp.fromDate(submission.submittedAt),
        'approvedAt': null,
      });
    } else {
      await _monitorSubmissions(submission.teacherId, submission.classId)
          .doc(submission.id)
          .set(submission.toMap());
    }
    // Write notification for teacher
    await _db
        .collection('teachers')
        .doc(submission.teacherId)
        .collection('notifications')
        .doc(submission.id)
        .set({
      'type': 'monitor_submission',
      'classId': submission.classId,
      'monitorStudentId': submission.monitorStudentId,
      'assignmentId': submission.assignmentId,
      'submittedAt': Timestamp.fromDate(submission.submittedAt),
      'read': false,
    });
  }

  Stream<int> streamPendingMonitorCount(String teacherId, String classId) =>
      _monitorSubmissions(teacherId, classId)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .map((s) => s.docs.length);

  /// Approve a submission: copies monitorGrades → homeworkGrades and marks approved.
  Future<void> approveMonitorSubmission(
      String submissionId, MonitorSubmission submission) async {
    // 1. Fetch monitor grades for this assignment by this monitor
    final gradeSnap = await _monitorGrades(submission.teacherId, submission.classId)
        .where('monitorStudentId', isEqualTo: submission.monitorStudentId)
        .where('assignmentId', isEqualTo: submission.assignmentId)
        .get();

    // 2. Copy each grade to homeworkGrades (upsert)
    final batch = _db.batch();
    for (final doc in gradeSnap.docs) {
      final mg = MonitorGrade.fromMap(doc.data() as Map<String, dynamic>);
      if (mg.mark.isEmpty) continue;
      // Find existing homeworkGrade for same student+assignment
      final existing = await _homeworkGrades(submission.teacherId, submission.classId)
          .where('studentId', isEqualTo: mg.studentId)
          .where('assignmentId', isEqualTo: mg.assignmentId)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        batch.update(existing.docs.first.reference, {
          'mark': mg.mark,
          'gradedAt': Timestamp.fromDate(mg.gradedAt),
        });
      } else {
        final ref = _homeworkGrades(submission.teacherId, submission.classId)
            .doc(generateId());
        batch.set(ref, {
          'id': ref.id,
          'studentId': mg.studentId,
          'assignmentId': mg.assignmentId,
          'classId': submission.classId,
          'teacherId': submission.teacherId,
          'mark': mg.mark,
          'gradedAt': Timestamp.fromDate(mg.gradedAt),
        });
      }
    }

    // 3. Mark submission as approved
    final subRef =
        _monitorSubmissions(submission.teacherId, submission.classId).doc(submissionId);
    batch.update(subRef, {
      'status': 'approved',
      'approvedAt': Timestamp.fromDate(DateTime.now()),
    });

    await batch.commit();
  }
}
