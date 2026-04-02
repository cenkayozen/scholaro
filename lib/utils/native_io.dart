/// Cross-platform shim for dart:io operations.
/// On web: all operations are no-ops / return false.
/// On native: delegates to dart:io.
export 'native_io_web.dart' if (dart.library.io) 'native_io_native.dart';
