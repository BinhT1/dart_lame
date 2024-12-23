import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'ffi/lame_library.dart';
import 'ffi/lame_loader.dart';
import 'ffi/list_extensions.dart';
import 'generated/bindings.g.dart';

class DecoderWorker {
  final ReceivePort receivePort;
  final SendPort sendPort;
  final Function(DecodeResponse) responseCallback;

  DecoderWorker._({
    required this.receivePort,
    required this.sendPort,
    required this.responseCallback,
  });

  static Future<DecoderWorker> create(
      {required int numChannels,
      required int sampleRate,
      required int bitRate,
      required Function(DecodeResponse) responseCallback}) async {
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
        if (data is DecodeResponse) {
          // The worker isolate sent us a response to a request we sent.
          responseCallback(data);
          return;
        }
        throw UnsupportedError('Unsupported message type: ${data.runtimeType}');
      });

    await Isolate.spawn(
      (DecoderWorkerOptions options) {
        lameLoader = options.lameLoader;

        final ffi.Pointer<hip_global_struct> hip = bindings.hip_decode_init();

        final ReceivePort workerReceivePort = ReceivePort();

        workerReceivePort.listen((dynamic data) {
          // On the worker isolate listen to requests and respond to them.
          if (data is DecodeRequest) {
            final ffi.Pointer<ffi.UnsignedChar> mp3buf =
                data.mp3buf.copyToNativeMemory();
            ffi.Pointer<ffi.Short> pcmLeft = calloc(32768);
            ffi.Pointer<ffi.Short> pcmRight = calloc(32768);

            int decodedSize = bindings.hip_decode(
              hip,
              mp3buf,
              data.mp3buf.length,
              pcmLeft,
              pcmRight,
            );

            final result = Int16List(decodedSize * 2);
            for (int i = 0; i < decodedSize; i++) {
              result[2 * i] = pcmLeft.elementAt(i).value;
              result[2 * i + 1] = pcmRight.elementAt(i).value;
            }

            calloc.free(pcmLeft);
            calloc.free(pcmRight);
            calloc.free(mp3buf);

            final DecodeResponse response = DecodeResponse(
              id: data.id,
              result: result,
            );

            options.sendPort.send(response);
            return;
          }
          if (data is _CloseRequest) {
            bindings.hip_decode_exit(hip);
            workerReceivePort.close();
            Isolate.exit();
          }

          throw UnsupportedError(
              'Unsupported message type: ${data.runtimeType}');
        });
        options.sendPort.send(workerReceivePort.sendPort);
      },
      DecoderWorkerOptions(
        numChannels: numChannels,
        sampleRate: sampleRate,
        bitRate: bitRate,
        sendPort: receivePort.sendPort,
        lameLoader: lameLoader,
      ),
    );

    return DecoderWorker._(
      receivePort: receivePort,
      sendPort: await completer.future,
      responseCallback: responseCallback,
    );
  }

  void sendRequest(BaseDecoderRequest? request) {
    sendPort.send(request);
  }

  void close() {
    final _CloseRequest request = _CloseRequest();
    sendPort.send(request);
    receivePort.close();
  }
}

class _CloseRequest {}

class DecoderWorkerOptions {
  final int numChannels;
  final int sampleRate;
  final int bitRate;
  final SendPort sendPort;
  final LameLibraryLoader lameLoader;

  DecoderWorkerOptions({
    required this.numChannels,
    required this.sampleRate,
    required this.bitRate,
    required this.sendPort,
    required this.lameLoader,
  });
}

class BaseDecoderRequest {
  final int id;
  const BaseDecoderRequest(this.id);
}

class DecodeRequest extends BaseDecoderRequest {
  final Uint8List mp3buf;

  const DecodeRequest({
    required int id,
    required this.mp3buf,
  }) : super(id);
}

class DecodeResponse {
  final int id;
  final Int16List result;

  DecodeResponse({
    required this.id,
    required this.result,
  });
}
