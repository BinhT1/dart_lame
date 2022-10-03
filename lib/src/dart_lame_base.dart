import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';
import 'package:dart_lame/src/ffi/list_extensions.dart';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

import 'generated/bindings.g.dart';

final ffi.DynamicLibrary _lib = _loadLameLibrary();
final LameBindings _bindings = LameBindings(_lib);

ffi.DynamicLibrary _loadLameLibrary() {
  var libraryPath = path.join(Directory.current.path, 'liblame.so');
  if (Platform.isMacOS) {
    libraryPath = path.join(Directory.current.path, 'liblame.dylib');
  } else if (Platform.isWindows) {
    libraryPath = path.join(Directory.current.path, 'mp3lame.dll');
  }

  return ffi.DynamicLibrary.open(libraryPath);
}

String getLameVersion() {
  return _bindings.get_lame_version().cast<Utf8>().toDartString();
}

class LameMp3Encoder {
  final ffi.Pointer<lame_global_struct> _flags = _bindings.lame_init();

  LameMp3Encoder(
      {int numChannels = 2, int sampleRate = 44100, int bitRate = 128}) {
    _bindings.lame_set_num_channels(_flags, numChannels);
    _bindings.lame_set_in_samplerate(_flags, sampleRate);
    _bindings.lame_set_brate(_flags, bitRate);

    if (numChannels == 1) {
      _bindings.lame_set_mode(_flags, 3); // 3: mono mode
    }

    int retCode = _bindings.lame_init_params(_flags);
    if (retCode < 0) {
      throw LameMp3EncoderException(retCode,
          errorMessage:
              "Unable to create encoder, probably because of invalid parameters");
    }
  }

  /// Encode PCM-16bit data to mp3 frames
  Uint8List encode(
      {required Uint16List leftChannel, Uint16List? rightChannel}) {
    final ffi.Pointer<ffi.Short> ptrLeft =
        leftChannel.copyToNativeMemory().cast<ffi.Short>();
    ffi.Pointer<ffi.Short>? ptrRight;
    if (rightChannel != null) {
      ptrRight = rightChannel.copyToNativeMemory().cast<ffi.Short>();
    }

    int mp3BufSize = (1.25 * leftChannel.length + 7500).ceil();
    ffi.Pointer<ffi.UnsignedChar> ptrMp3 = calloc(mp3BufSize);

    int encodedSize = _bindings.lame_encode_buffer(
        _flags,
        ptrLeft,
        ptrRight ?? ffi.Pointer<ffi.Short>.fromAddress(0),
        leftChannel.length,
        ptrMp3,
        mp3BufSize);

    final ret = Uint8List(encodedSize);
    for (int i = 0; i < encodedSize; i++) {
      ret[i] = ptrMp3.elementAt(i).value;
    }

    calloc.free(ptrMp3);
    calloc.free(ptrLeft);
    if (ptrRight != null) {
      calloc.free(ptrRight);
    }

    return ret;
  }

  /// Encode PCM IEEE Double data to mp3 frames
  Uint8List encodeDouble(
      {required Float64List leftChannel, Float64List? rightChannel}) {
    final ffi.Pointer<ffi.Double> ptrLeft =
        leftChannel.copyToNativeMemory().cast<ffi.Double>();
    ffi.Pointer<ffi.Double>? ptrRight;
    if (rightChannel != null) {
      ptrRight = rightChannel.copyToNativeMemory().cast<ffi.Double>();
    }

    int mp3BufSize = (1.25 * leftChannel.length + 7500).ceil();
    ffi.Pointer<ffi.UnsignedChar> ptrMp3 = calloc(mp3BufSize);

    int encodedSize = _bindings.lame_encode_buffer_ieee_double(
        _flags,
        ptrLeft,
        ptrRight ?? ffi.Pointer<ffi.Double>.fromAddress(0),
        leftChannel.length,
        ptrMp3,
        mp3BufSize);

    final ret = Uint8List(encodedSize);
    for (int i = 0; i < encodedSize; i++) {
      ret[i] = ptrMp3.elementAt(i).value;
    }

    calloc.free(ptrMp3);
    calloc.free(ptrLeft);
    if (ptrRight != null) {
      calloc.free(ptrRight);
    }

    return ret;
  }

  Uint8List flush() {
    final int mp3BufSize = 7200;
    ffi.Pointer<ffi.UnsignedChar> ptrMp3 = calloc(mp3BufSize);

    int encodedSize = _bindings.lame_encode_flush(_flags, ptrMp3, mp3BufSize);

    final ret = Uint8List(encodedSize);
    for (int i = 0; i < encodedSize; i++) {
      ret[i] = ptrMp3.elementAt(i).value;
    }
    calloc.free(ptrMp3);

    return ret;
  }

  void close() {
    _bindings.lame_close(_flags);
  }
}

class LameMp3EncoderException implements Exception {
  int errorCode;
  String? errorMessage;

  LameMp3EncoderException(this.errorCode, {this.errorMessage});

  @override
  String toString() {
    return "LameMp3EncoderException! Error Code: $errorCode. ${errorMessage ?? ""}";
  }
}
