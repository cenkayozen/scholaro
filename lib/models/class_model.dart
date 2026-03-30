import 'package:cloud_firestore/cloud_firestore.dart';

class ClassModel {
  final String id;
  final String name;
  final String teacherId;
  final int studentCount;
  final DateTime createdAt;

  ClassModel({
    required this.id,
    required this.name,
    required this.teacherId,
    required this.studentCount,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'teacherId': teacherId,
        'studentCount': studentCount,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory ClassModel.fromMap(Map<String, dynamic> map) => ClassModel(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        teacherId: map['teacherId'] ?? '',
        studentCount: map['studentCount'] ?? 0,
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  factory ClassModel.fromDoc(DocumentSnapshot doc) =>
      ClassModel.fromMap(doc.data() as Map<String, dynamic>);
}
