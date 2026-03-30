import 'package:cloud_firestore/cloud_firestore.dart';

class ParticipationEntry {
  final String id;
  final String studentId;
  final String classId;
  final String teacherId;
  final String note;
  final DateTime date;

  ParticipationEntry({
    required this.id,
    required this.studentId,
    required this.classId,
    required this.teacherId,
    required this.note,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'studentId': studentId,
        'classId': classId,
        'teacherId': teacherId,
        'note': note,
        'date': Timestamp.fromDate(date),
      };

  factory ParticipationEntry.fromMap(Map<String, dynamic> map) =>
      ParticipationEntry(
        id: map['id'] ?? '',
        studentId: map['studentId'] ?? '',
        classId: map['classId'] ?? '',
        teacherId: map['teacherId'] ?? '',
        note: map['note'] ?? '',
        date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  factory ParticipationEntry.fromDoc(DocumentSnapshot doc) =>
      ParticipationEntry.fromMap(doc.data() as Map<String, dynamic>);
}
