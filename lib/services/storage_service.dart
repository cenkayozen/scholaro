import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadStudentPhoto({
    required String teacherId,
    required String classId,
    required String studentId,
    required XFile file,
  }) async {
    final ext = p.extension(file.path).isNotEmpty ? p.extension(file.path) : '.jpg';
    final bytes = await file.readAsBytes();
    final ref = _storage
        .ref('teachers/$teacherId/classes/$classId/students/$studentId/photo$ext');
    await ref.putData(bytes, SettableMetadata(contentType: _mimeFromExt(ext)));
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
    required XFile file,
  }) async {
    final ext = p.extension(file.path).isNotEmpty ? p.extension(file.path) : '';
    final bytes = await file.readAsBytes();
    final ref = _storage.ref(
        'teachers/$teacherId/classes/$classId/portfolio/$studentId/$itemId$ext');
    await ref.putData(bytes, SettableMetadata(contentType: _mimeFromExt(ext)));
    return await ref.getDownloadURL();
  }

  Future<void> deleteFile(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {}
  }

  String _mimeFromExt(String ext) {
    switch (ext.toLowerCase()) {
      case '.jpg':
      case '.jpeg': return 'image/jpeg';
      case '.png':  return 'image/png';
      case '.gif':  return 'image/gif';
      case '.webp': return 'image/webp';
      case '.pdf':  return 'application/pdf';
      default:      return 'application/octet-stream';
    }
  }
}
