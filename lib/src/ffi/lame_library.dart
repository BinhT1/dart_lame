import 'dart:ffi' as ffi;
import 'dart:io';

import '../generated/bindings.g.dart';

ffi.DynamicLibrary? _lib;
LameBindings? _bindings;

ffi.DynamicLibrary get lib {
  _lib ??= _loadLameLibraryDefault();
  return _lib!;
}

set lib(ffi.DynamicLibrary lib) => _lib = lib;

LameBindings get bindings {
  _bindings ??= LameBindings(lib);
  return _bindings!;
}

const String _libName = 'mp3lame';

ffi.DynamicLibrary _loadLameLibraryDefault() {
  if (Platform.isMacOS) {
    return ffi.DynamicLibrary.open('lib$_libName.dylib');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return ffi.DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return ffi.DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}
