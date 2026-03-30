import 'package:cloud_firestore/cloud_firestore.dart';

class MonitorGrade {
  final String id;
  final String teacherId;
  final String classId;
  final String monitorStudentId; // who entered the grade
  final String studentId;        // whose grade it is
  final String assignmentId;
  final String mark;
  final DateTime gradedAt;

  MonitorGrade({
    required this.id,
    required this.teacherId,
    required this.classId,
    required this.monitorStudentId,
    required this.studentId,
    required this.assignmentId,
    required this.mark,
    required this.gradedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'teacherId': teacherId,
        'classId': classId,
        'monitorStudentId': monitorStudentId,
        'studentId': studentId,
        'assignmentId': assignmentId,
        'mark': mark,
        'gradedAt': Timestamp.fromDate(gradedAt),
      };

  factory MonitorGrade.fromMap(Map<String, dynamic> map) => MonitorGrade(
        id: map['id'] ?? '',
        teacherId: map['teacherId'] ?? '',
        classId: map['classId'] ?? '',
        monitorStudentId: map['monitorStudentId'] ?? '',
        studentId: map['studentId'] ?? '',
        assignmentId: map['assignmentId'] ?? '',
        mark: map['mark'] ?? '',
        gradedAt:
            (map['gradedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
}

class MonitorSubmission {
  final String id;
  final String teacherId;
  final String classId;
  final String monitorStudentId;
  final String assignmentId;
  final String status; // 'pending' | 'approved'
  final DateTime submittedAt;
  final DateTime? approvedAt;

  MonitorSubmission({
    required this.id,
    required this.teacherId,
    required this.classId,
    required this.monitorStudentId,
    required this.assignmentId,
    required this.status,
    required this.submittedAt,
    this.approvedAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';

  Map<String, dynamic> toMap() => {
        'id': id,
        'teacherId': teacherId,
        'classId': classId,
        'monitorStudentId': monitorStudentId,
        'assignmentId': assignmentId,
        'status': status,
        'submittedAt': Timestamp.fromDate(submittedAt),
        'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      };

  factory MonitorSubmission.fromMap(Map<String, dynamic> map) =>
      MonitorSubmission(
        id: map['id'] ?? '',
        teacherId: map['teacherId'] ?? '',
        classId: map['classId'] ?? '',
        monitorStudentId: map['monitorStudentId'] ?? '',
        assignmentId: map['assignmentId'] ?? '',
        status: map['status'] ?? 'pending',
        submittedAt:
            (map['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        approvedAt: (map['approvedAt'] as Timestamp?)?.toDate(),
      );
}
