import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

extension Int16ListExtension on Int16List {
  /// Allocate native memory and copy list data into it. You are responsible to
  /// free this memory after use
  Pointer<Short> copyToNativeMemory() {
    final pointer = calloc<Short>(length);
    for (int i = 0; i < length; i++) {
      pointer[i] = this[i];
    }

    return pointer;
  }
}

extension Float64ListExtension on Float64List {
  Pointer<Double> copyToNativeMemory() {
    final pointer = calloc<Double>(length);
    for (int i = 0; i < length; i++) {
      pointer[i] = this[i];
    }

    return pointer;
  }
}

extension Uint8ListExtension on Uint8List {
  Pointer<UnsignedChar> copyToNativeMemory() {
    final pointer = calloc<UnsignedChar>(length);
    for (int i = 0; i < length; i++) {
      pointer[i] = this[i];
    }

    return pointer;
  }
}
