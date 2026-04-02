bool get isAndroid => false;
bool get isIOS     => false;
bool get isWindows => false;

Future<void> writeFileBytes(String path, List<int> bytes) async {}

Future<String> writeTempFile(String dir, String name, List<int> bytes) async =>
    '';
