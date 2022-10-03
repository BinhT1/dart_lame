import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:dart_lame/dart_lame.dart';
import 'package:wav/wav.dart';

void main(List<String> arguments) async {
  print("dart_lame example");
  print('LAME version: ${getLameVersion()}');

  final parser = ArgParser()
    ..addOption("input", abbr: "i", help: "Input wav file", mandatory: true)
    ..addOption("output",
        abbr: "o", help: "Output mp3 file", defaultsTo: "output.mp3");
  final argResults = parser.parse(arguments);

  final String inputPath = argResults["input"];
  print("Input file: $inputPath");
  final wav = await Wav.readFile(inputPath);

  final encoder = LameMp3Encoder(
      sampleRate: wav.samplesPerSecond, numChannels: wav.channels.length);

  print("Encoding...");

  final String outputPath = argResults["output"];
  final File f = File(outputPath);
  final IOSink sink = f.openWrite();
  try {
    final left = wav.channels[0];
    Float64List? right;
    if (wav.channels.length > 1) {
      right = wav.channels[1];
    }

    for (int i = 0; i < left.length; i += wav.samplesPerSecond) {
      final mp3Frame = encoder.encodeDouble(
          leftChannel: left.sublist(i, i + wav.samplesPerSecond),
          rightChannel: right?.sublist(i, i + wav.samplesPerSecond));
      sink.add(mp3Frame);
    }
  } finally {
    sink.close();
    encoder.close();
  }

  print("Successfully encoded mp3 file: ${f.absolute}");
}
