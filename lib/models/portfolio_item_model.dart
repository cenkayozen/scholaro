import 'package:cloud_firestore/cloud_firestore.dart';

class PortfolioItem {
  final String id;
  final String studentId;
  final String classId;
  final String teacherId;
  final String fileUrl;
  final String fileType; // 'image' | 'pdf' | 'other'
  final String fileName;
  final DateTime uploadedAt;

  PortfolioItem({
    required this.id,
    required this.studentId,
    required this.classId,
    required this.teacherId,
    required this.fileUrl,
    required this.fileType,
    required this.fileName,
    required this.uploadedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'studentId': studentId,
        'classId': classId,
        'teacherId': teacherId,
        'fileUrl': fileUrl,
        'fileType': fileType,
        'fileName': fileName,
        'uploadedAt': Timestamp.fromDate(uploadedAt),
      };

  factory PortfolioItem.fromMap(Map<String, dynamic> map) => PortfolioItem(
        id: map['id'] ?? '',
        studentId: map['studentId'] ?? '',
        classId: map['classId'] ?? '',
        teacherId: map['teacherId'] ?? '',
        fileUrl: map['fileUrl'] ?? '',
        fileType: map['fileType'] ?? 'other',
        fileName: map['fileName'] ?? '',
        uploadedAt:
            (map['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );

  factory PortfolioItem.fromDoc(DocumentSnapshot doc) =>
      PortfolioItem.fromMap(doc.data() as Map<String, dynamic>);
}
