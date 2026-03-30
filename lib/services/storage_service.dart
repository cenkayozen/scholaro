import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadStudentPhoto({
    required String teacherId,
    required String classId,
    required String studentId,
    required File file,
  }) async {
    final ext = p.extension(file.path);
    final ref = _storage
        .ref('teachers/$teacherId/classes/$classId/students/$studentId/photo$ext');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  /// Upload raw image bytes (e.g. extracted from a PDF).
  Future<String> uploadStudentPhotoBytes({
    required String teacherId,
    required String classId,
    required String studentId,
    required Uint8List bytes,
  }) async {
    final ref = _storage.ref(
        'teachers/$teacherId/classes/$classId/students/$studentId/photo.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return await ref.getDownloadURL();
  }

  Future<String> uploadPortfolioItem({
    required String teacherId,
    required String classId,
    required String studentId,
    required String itemId,
    required File file,
  }) async {
    final ext = p.extension(file.path);
    final ref = _storage.ref(
        'teachers/$teacherId/classes/$classId/portfolio/$studentId/$itemId$ext');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<void> deleteFile(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {}
  }
}
