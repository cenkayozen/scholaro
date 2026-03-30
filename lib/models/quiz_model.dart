import 'package:cloud_firestore/cloud_firestore.dart';

class QuizModel {
  final String id;
  final String name;
  final String classId;
  final String teacherId;
  final DateTime createdAt;

  QuizModel({
    required this.id,
    required this.name,
    required this.classId,
    required this.teacherId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'classId': classId,
        'teacherId': teacherId,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory QuizModel.fromMap(Map<String, dynamic> map) => QuizModel(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        classId: map['classId'] ?? '',
        teacherId: map['teacherId'] ?? '',
        createdAt: _parseDate(map['createdAt']),
      );

  static DateTime _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  factory QuizModel.fromDoc(DocumentSnapshot doc) =>
      QuizModel.fromMap(doc.data() as Map<String, dynamic>);
}

class QuizScore {
  final String id;
  final String studentId;
  final String quizId;
  final String classId;
  final String teacherId;
  final double score;
  final DateTime gradedAt;

  QuizScore({
    required this.id,
    required this.studentId,
    required this.quizId,
    required this.classId,
    required this.teacherId,
    required this.score,
    required this.gradedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'studentId': studentId,
        'quizId': quizId,
        'classId': classId,
        'teacherId': teacherId,
        'score': score,
        'gradedAt': Timestamp.fromDate(gradedAt),
      };

  factory QuizScore.fromMap(Map<String, dynamic> map) => QuizScore(
        id: map['id'] ?? '',
        studentId: map['studentId'] ?? '',
        quizId: map['quizId'] ?? '',
        classId: map['classId'] ?? '',
        teacherId: map['teacherId'] ?? '',
        score: (map['score'] ?? 0).toDouble(),
        gradedAt: _parseDate(map['gradedAt']),
      );

  static DateTime _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  factory QuizScore.fromDoc(DocumentSnapshot doc) =>
      QuizScore.fromMap(doc.data() as Map<String, dynamic>);
}
