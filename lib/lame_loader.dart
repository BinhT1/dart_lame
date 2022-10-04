import 'dart:ffi' as ffi;
import 'src/ffi/lame_library.dart' as lame;

/// Allow you to manually load `libmp3lame` from other location.
/// Load the library by yourself, then call this function.
///
/// You don't need to call this function. `dart_lame` will automatically load
/// the library from predefined location unless you want to place it somewhere else.
set library(ffi.DynamicLibrary library) => lame.lib = library;
