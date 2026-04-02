import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ──────────────────────────────────────────────
  // TEACHER AUTH
  // ──────────────────────────────────────────────

  Future<UserCredential> registerTeacher({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    await cred.user!.updateDisplayName(displayName);
    await _db.collection('teachers').doc(cred.user!.uid).set({
      'uid': cred.user!.uid,
      'email': email,
      'displayName': displayName,
      'createdAt': FieldValue.serverTimestamp(),
      'role': 'teacher',
    });
    return cred;
  }

  Future<UserCredential> signInTeacher({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
        email: email, password: password);
  }

  // ──────────────────────────────────────────────
  // STUDENT AUTH
  // ──────────────────────────────────────────────

  /// Creates a Firebase Auth account for the student using the REST API.
  /// This does NOT disrupt the currently signed-in teacher session.
  Future<String> createStudentFirebaseAccount({
    required String email,
    required String password,
    required String apiKey,
  }) async {
    final url = Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'returnSecureToken': false,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      final msg = data['error']?['message'] as String? ?? 'Account creation failed';
      if (msg == 'EMAIL_EXISTS') return data['localId'] as String? ?? '';
      throw Exception(msg);
    }
    return data['localId'] as String;
  }

  /// Sign in via Firebase Auth REST API and return the ID token.
  Future<String> _restSignIn({
    required String email,
    required String password,
    required String apiKey,
  }) async {
    final url = Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'returnSecureToken': true,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['error']?['message'] ?? 'Sign-in failed');
    }
    return data['idToken'] as String;
  }

  /// Sign in as student and store session locally.
  /// Uses REST API for Firebase Auth to avoid Windows SDK limitations.
  Future<void> signInStudent({
    required String username,
    required String password,
  }) async {
    // 1. Verify credentials from Firestore
    final snap = await _db.collection('studentAccounts').doc(username).get();
    if (!snap.exists) throw Exception('Username not found');

    final doc = snap.data()!;
    if (doc['password'] as String != password) throw Exception('Incorrect password');

    final firebaseEmail = doc['firebaseEmail'] as String;
    final apiKey = Firebase.app().options.apiKey;

    // 2. Ensure Firebase Auth account exists (create if first login)
    await createStudentFirebaseAccount(
      email: firebaseEmail,
      password: password,
      apiKey: apiKey,
    );

    // 3. Sign in via SDK (account now guaranteed to exist)
    await _auth.signOut();
    await _auth.signInWithEmailAndPassword(
        email: firebaseEmail, password: password);

    // 4. Store student metadata locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('student_id', doc['studentId'] as String);
    await prefs.setString('class_id', doc['classId'] as String);
    await prefs.setString('teacher_id', doc['teacherId'] as String);
    await prefs.setString('role', 'student');
  }

  // ──────────────────────────────────────────────
  // HOMEWORK MONITOR AUTH
  // ──────────────────────────────────────────────

  /// Signs in as a Homework Monitor using student credentials.
  /// Throws if not found, wrong password, or student is not a monitor.
  Future<void> signInHomeworkMonitor({
    required String username,
    required String password,
  }) async {
    // 1. Verify credentials from Firestore
    final snap = await _db.collection('studentAccounts').doc(username).get();
    if (!snap.exists) throw Exception('Username not found');

    final doc = snap.data()!;
    if (doc['password'] as String != password) throw Exception('Incorrect password');

    final teacherId = doc['teacherId'] as String;
    final classId = doc['classId'] as String;
    final studentId = doc['studentId'] as String;

    // 2. Check isHomeworkMonitor flag on student doc
    final studentSnap = await _db
        .collection('teachers')
        .doc(teacherId)
        .collection('classes')
        .doc(classId)
        .collection('students')
        .doc(studentId)
        .get();
    if (!studentSnap.exists) throw Exception('Student not found');
    final studentData = studentSnap.data()!;
    if (studentData['isHomeworkMonitor'] != true) {
      throw Exception('Bu hesapta Homework Monitor yetkisi yok');
    }

    final firebaseEmail = doc['firebaseEmail'] as String;
    final apiKey = Firebase.app().options.apiKey;

    // 3. Ensure Firebase Auth account exists
    await createStudentFirebaseAccount(
      email: firebaseEmail,
      password: password,
      apiKey: apiKey,
    );

    // 4. Sign in
    await _auth.signOut();
    await _auth.signInWithEmailAndPassword(
        email: firebaseEmail, password: password);

    // 5. Store session with role 'homework_monitor'
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('student_id', studentId);
    await prefs.setString('class_id', classId);
    await prefs.setString('teacher_id', teacherId);
    await prefs.setString('role', 'homework_monitor');
    await prefs.setStringList(
        'monitor_assignment_ids',
        (studentData['monitorAssignmentIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            []);
  }

  Future<Map<String, dynamic>> getMonitorSession() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'studentId': prefs.getString('student_id'),
      'classId': prefs.getString('class_id'),
      'teacherId': prefs.getString('teacher_id'),
      'monitorAssignmentIds':
          prefs.getStringList('monitor_assignment_ids') ?? <String>[],
    };
  }

  Future<void> signOut() async {
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('student_id');
    await prefs.remove('class_id');
    await prefs.remove('teacher_id');
    await prefs.remove('role');
    await prefs.remove('monitor_assignment_ids');
  }

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<String?> getStoredRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('role');
  }

  Future<Map<String, String?>> getStudentSession() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'studentId': prefs.getString('student_id'),
      'classId': prefs.getString('class_id'),
      'teacherId': prefs.getString('teacher_id'),
    };
  }
}
