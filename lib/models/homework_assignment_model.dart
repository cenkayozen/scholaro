import 'package:cloud_firestore/cloud_firestore.dart';

class HomeworkAssignment {
  final String id;
  final String title;
  final String classId;
  final String teacherId;
  final int order;
  final DateTime createdAt;

  HomeworkAssignment({
    required this.id,
    required this.title,
    required this.classId,
    required this.teacherId,
    required this.order,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'classId': classId,
        'teacherId': teacherId,
        'order': order,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory HomeworkAssignment.fromMap(Map<String, dynamic> map) =>
      HomeworkAssignment(
        id: map['id'] ?? '',
        title: map['title'] ?? '',
        classId: map['classId'] ?? '',
        teacherId: map['teacherId'] ?? '',
        order: map['order'] ?? 0,
        createdAt: _parseDate(map['createdAt']),
      );

  static DateTime _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  factory HomeworkAssignment.fromDoc(DocumentSnapshot doc) =>
      HomeworkAssignment.fromMap(doc.data() as Map<String, dynamic>);
}

// plus, halfPlus, minus, absent, exempt
class HomeworkGrade {
  final String id;
  final String studentId;
  final String assignmentId;
  final String classId;
  final String teacherId;
  final String mark; // 'plus' | 'halfPlus' | 'minus' | 'absent' | 'exempt'
  final DateTime gradedAt;

  HomeworkGrade({
    required this.id,
    required this.studentId,
    required this.assignmentId,
    required this.classId,
    required this.teacherId,
    required this.mark,
    required this.gradedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'studentId': studentId,
        'assignmentId': assignmentId,
        'classId': classId,
        'teacherId': teacherId,
        'mark': mark,
        'gradedAt': Timestamp.fromDate(gradedAt),
      };

  factory HomeworkGrade.fromMap(Map<String, dynamic> map) => HomeworkGrade(
        id: map['id'] ?? '',
        studentId: map['studentId'] ?? '',
        assignmentId: map['assignmentId'] ?? '',
        classId: map['classId'] ?? '',
        teacherId: map['teacherId'] ?? '',
        mark: map['mark'] ?? 'minus',
        gradedAt: _parseDate(map['gradedAt']),
      );

  static DateTime _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  factory HomeworkGrade.fromDoc(DocumentSnapshot doc) =>
      HomeworkGrade.fromMap(doc.data() as Map<String, dynamic>);

  double get numericValue {
    switch (mark) {
      case 'plus':
        return 1.0;
      case 'halfPlus':
        return 0.5;
      case 'minus':
        return 0.0;
      case 'absent':
        return 0.0;
      case 'exempt':
        return -1.0; // special flag
      default:
        return 0.0;
    }
  }

  String get displayMark {
    switch (mark) {
      case 'plus':
        return '+';
      case 'halfPlus':
        return '½+';
      case 'minus':
        return '−';
      case 'absent':
        return 'A';
      case 'exempt':
        return 'E';
      default:
        return '?';
    }
  }
}
