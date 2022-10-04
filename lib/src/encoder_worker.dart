import 'dart:async';
import 'dart:isolate';
import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'ffi/lame_library.dart';
import 'ffi/list_extensions.dart';
import 'dart_lame_base.dart';
import 'generated/bindings.g.dart';

class EncoderWorker {
  final SendPort sendPort;
  final Function(EncodeResponse) responseCallback;

  EncoderWorker._(this.sendPort, this.responseCallback);

  static Future<EncoderWorker> create(
      {required int numChannels,
      required int sampleRate,
      required int bitRate,
      required Function(EncodeResponse) responseCallback}) async {
    // The worker isolate is going to send us back a SendPort, which we want to
    // wait for.
    final Completer<SendPort> completer = Completer<SendPort>();

    // Receive port on the main isolate to receive messages from the helper.
    // We receive two types of messages:
    // 1. A port to send messages on.
    // 2. Responses to requests we sent.
    final ReceivePort receivePort = ReceivePort()
      ..listen((dynamic data) {
        if (data is SendPort) {
          // The worker isolate sent us the port on which we can sent it requests.
          completer.complete(data);
          return;
        }
        if (data is EncodeResponse) {
          // The worker isolate sent us a response to a request we sent.
          responseCallback(data);
          return;
        }
        throw UnsupportedError('Unsupported message type: ${data.runtimeType}');
      });

    await Isolate.spawn((EncoderWorkerOptions options) {
      final ffi.Pointer<lame_global_struct> flags = bindings.lame_init();
      bindings.lame_set_num_channels(flags, options.numChannels);
      bindings.lame_set_in_samplerate(flags, options.sampleRate);
      bindings.lame_set_brate(flags, options.bitRate);

      if (options.numChannels == 1) {
        bindings.lame_set_mode(flags, 3); // 3: mono mode
      }

      int retCode = bindings.lame_init_params(flags);
      if (retCode < 0) {
        throw LameMp3EncoderException(retCode,
            errorMessage:
                "Unable to create encoder, probably because of invalid parameters");
      }

      final ReceivePort workerReceivePort = ReceivePort()
        ..listen((dynamic data) {
          // On the worker isolate listen to requests and respond to them.
          if (data is EncodeRequest) {
            final ffi.Pointer<ffi.Short> ptrLeft =
                data.leftChannel.copyToNativeMemory().cast<ffi.Short>();
            ffi.Pointer<ffi.Short>? ptrRight;
            if (data.rightChannel != null) {
              ptrRight =
                  data.rightChannel!.copyToNativeMemory().cast<ffi.Short>();
            }

            int mp3BufSize = (1.25 * data.leftChannel.length + 7500).ceil();
            ffi.Pointer<ffi.UnsignedChar> ptrMp3 = calloc(mp3BufSize);

            int encodedSize = bindings.lame_encode_buffer(
                flags,
                ptrLeft,
                ptrRight ?? ffi.Pointer<ffi.Short>.fromAddress(0),
                data.leftChannel.length,
                ptrMp3,
                mp3BufSize);

            final result = Uint8List(encodedSize);
            for (int i = 0; i < encodedSize; i++) {
              result[i] = ptrMp3.elementAt(i).value;
            }

            calloc.free(ptrMp3);
            calloc.free(ptrLeft);
            if (ptrRight != null) {
              calloc.free(ptrRight);
            }

            final EncodeResponse response =
                EncodeResponse(id: data.id, result: result);
            options.sendPort.send(response);
            return;
          }

          if (data is EncodeFloat64Request) {
            final ffi.Pointer<ffi.Double> ptrLeft =
                data.leftChannel.copyToNativeMemory().cast<ffi.Double>();
            ffi.Pointer<ffi.Double>? ptrRight;
            if (data.rightChannel != null) {
              ptrRight =
                  data.rightChannel!.copyToNativeMemory().cast<ffi.Double>();
            }

            // See LAME API doc
            int mp3BufSize = (1.25 * data.leftChannel.length + 7500).ceil();
            ffi.Pointer<ffi.UnsignedChar> ptrMp3 = calloc(mp3BufSize);

            int encodedSize = bindings.lame_encode_buffer_ieee_double(
                flags,
                ptrLeft,
                ptrRight ?? ffi.Pointer<ffi.Double>.fromAddress(0),
                data.leftChannel.length,
                ptrMp3,
                mp3BufSize);

            final result = Uint8List(encodedSize);
            for (int i = 0; i < encodedSize; i++) {
              result[i] = ptrMp3.elementAt(i).value;
            }

            calloc.free(ptrMp3);
            calloc.free(ptrLeft);
            if (ptrRight != null) {
              calloc.free(ptrRight);
            }

            final EncodeResponse response =
                EncodeResponse(id: data.id, result: result);
            options.sendPort.send(response);
            return;
          }

          if (data is FlushRequest) {
            final int mp3BufSize = 7200; // See LAME API doc
            ffi.Pointer<ffi.UnsignedChar> ptrMp3 = calloc(mp3BufSize);

            int encodedSize =
                bindings.lame_encode_flush(flags, ptrMp3, mp3BufSize);

            final result = Uint8List(encodedSize);
            for (int i = 0; i < encodedSize; i++) {
              result[i] = ptrMp3.elementAt(i).value;
            }
            calloc.free(ptrMp3);

            final EncodeResponse response =
                EncodeResponse(id: data.id, result: result);
            options.sendPort.send(response);
            return;
          }

          if (data is CloseRequest) {
            bindings.lame_close(flags);
            Isolate.exit();
          }

          throw UnsupportedError(
              'Unsupported message type: ${data.runtimeType}');
        });

      // Send the the port to the main isolate on which we can receive requests.
      options.sendPort.send(workerReceivePort.sendPort);
    },
        EncoderWorkerOptions(
            numChannels: numChannels,
            sampleRate: sampleRate,
            bitRate: bitRate,
            sendPort: receivePort.sendPort));

    return EncoderWorker._(await completer.future, responseCallback);
  }

  void sendRequest(BaseEncoderRequest? request) {
    sendPort.send(request);
  }
}

class EncoderWorkerOptions {
  final int numChannels;
  final int sampleRate;
  final int bitRate;
  final SendPort sendPort;

  EncoderWorkerOptions(
      {required this.numChannels,
      required this.sampleRate,
      required this.bitRate,
      required this.sendPort});
}

class BaseEncoderRequest {
  final int id;
  const BaseEncoderRequest(this.id);
}

class EncodeRequest extends BaseEncoderRequest {
  final Uint16List leftChannel;
  final Uint16List? rightChannel;

  const EncodeRequest(
      {required int id, required this.leftChannel, this.rightChannel})
      : super(id);
}

class EncodeFloat64Request extends BaseEncoderRequest {
  final Float64List leftChannel;
  final Float64List? rightChannel;

  const EncodeFloat64Request(
      {required int id, required this.leftChannel, this.rightChannel})
      : super(id);
}

class FlushRequest extends BaseEncoderRequest {
  const FlushRequest(int id) : super(id);
}

class CloseRequest extends BaseEncoderRequest {
  const CloseRequest(int id) : super(id);
}

class EncodeResponse {
  final int id;
  final Uint8List result;

  EncodeResponse({required this.id, required this.result});
}
