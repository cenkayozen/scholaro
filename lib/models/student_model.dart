import 'package:cloud_firestore/cloud_firestore.dart';

class StudentModel {
  final String id;
  final String fullName;
  final String schoolNumber;
  final String photoUrl;
  final String username;
  final String password; // plain text, visible to teacher
  final String firebaseEmail; // generated email for Firebase Auth
  final String classId;
  final String teacherId;
  final DateTime createdAt;
  final int order;
  final bool isHomeworkMonitor;
  final List<String> monitorAssignmentIds;

  StudentModel({
    required this.id,
    required this.fullName,
    required this.schoolNumber,
    required this.photoUrl,
    required this.username,
    required this.password,
    required this.firebaseEmail,
    required this.classId,
    required this.teacherId,
    required this.createdAt,
    this.order = 0,
    this.isHomeworkMonitor = false,
    this.monitorAssignmentIds = const [],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'fullName': fullName,
        'schoolNumber': schoolNumber,
        'photoUrl': photoUrl,
        'username': username,
        'password': password,
        'firebaseEmail': firebaseEmail,
        'classId': classId,
        'teacherId': teacherId,
        'createdAt': Timestamp.fromDate(createdAt),
        'order': order,
        'isHomeworkMonitor': isHomeworkMonitor,
        'monitorAssignmentIds': monitorAssignmentIds,
      };

  factory StudentModel.fromMap(Map<String, dynamic> map) => StudentModel(
        id: map['id'] ?? '',
        fullName: map['fullName'] ?? '',
        schoolNumber: map['schoolNumber'] ?? '',
        photoUrl: map['photoUrl'] ?? '',
        username: map['username'] ?? '',
        password: map['password'] ?? '',
        firebaseEmail: map['firebaseEmail'] ?? '',
        classId: map['classId'] ?? '',
        teacherId: map['teacherId'] ?? '',
        createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        order: map['order'] ?? 0,
        isHomeworkMonitor: map['isHomeworkMonitor'] ?? false,
        monitorAssignmentIds:
            (map['monitorAssignmentIds'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [],
      );

  factory StudentModel.fromDoc(DocumentSnapshot doc) =>
      StudentModel.fromMap(doc.data() as Map<String, dynamic>);

  StudentModel copyWith({
    String? username,
    String? password,
    String? photoUrl,
    int? order,
    bool? isHomeworkMonitor,
    List<String>? monitorAssignmentIds,
  }) =>
      StudentModel(
        id: id,
        fullName: fullName,
        schoolNumber: schoolNumber,
        photoUrl: photoUrl ?? this.photoUrl,
        username: username ?? this.username,
        password: password ?? this.password,
        firebaseEmail: firebaseEmail,
        classId: classId,
        teacherId: teacherId,
        createdAt: createdAt,
        order: order ?? this.order,
        isHomeworkMonitor: isHomeworkMonitor ?? this.isHomeworkMonitor,
        monitorAssignmentIds: monitorAssignmentIds ?? this.monitorAssignmentIds,
      );
}
