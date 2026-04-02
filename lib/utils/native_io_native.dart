import 'dart:io';

bool get isAndroid => Platform.isAndroid;
bool get isIOS     => Platform.isIOS;
bool get isWindows => Platform.isWindows;

Future<void> writeFileBytes(String path, List<int> bytes) =>
    File(path).writeAsBytes(bytes);

Future<String> writeTempFile(String dir, String name, List<int> bytes) async {
  final file = File('$dir/$name');
  await file.writeAsBytes(bytes);
  return file.path;
}
