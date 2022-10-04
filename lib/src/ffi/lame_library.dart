import 'dart:ffi' as ffi;
import 'dart:io';

import '../generated/bindings.g.dart';

final ffi.DynamicLibrary lib = _loadLameLibrary();
final LameBindings bindings = LameBindings(lib);

const String _libName = 'mp3lame';

ffi.DynamicLibrary _loadLameLibrary() {
  if (Platform.isMacOS || Platform.isIOS) {
    try {
      return ffi.DynamicLibrary.open('$_libName.framework/$_libName');
    } catch (_) {
      return ffi.DynamicLibrary.open('lib$_libName.dylib');
    }
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return ffi.DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return ffi.DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}
