import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Gabay's sound categories, built from YAMNet's 521 sound labels.
class SoundCategory {
  final String id;
  final List<String> keys; // matched against YAMNet label text
  final bool urgent;
  const SoundCategory(this.id, this.keys, {this.urgent = false});
}

const soundCategories = [
  SoundCategory('horn', ['horn', 'honk'], urgent: true),
  SoundCategory('siren', ['siren', 'police car', 'ambulance', 'fire engine'], urgent: true),
  SoundCategory('alarm', ['smoke detector', 'fire alarm', 'car alarm', 'alarm clock', 'alarm', 'buzzer'], urgent: true),
  SoundCategory('explosion', ['explosion', 'gunshot', 'gunfire', 'fireworks', 'burst'], urgent: true),
  SoundCategory('scream', ['scream', 'yell', 'shout'], urgent: true),
  SoundCategory('glass', ['shatter', 'glass', 'breaking'], urgent: true),
  SoundCategory('baby', ['baby cry', 'infant cry', 'crying', 'sobbing']),
  SoundCategory('doorbell', ['doorbell', 'ding-dong']),
  SoundCategory('knock', ['knock']),
  SoundCategory('dog', ['dog', 'bark', 'growl', 'howl']),
  SoundCategory('phone', ['telephone', 'ringtone']),
  SoundCategory('speech', ['speech', 'conversation', 'narration']),
];

/// YAMNet audio classifier (Google), running on the phone. Input: 0.975 s of 16 kHz audio.
class SoundClassifier {
  SoundClassifier._();
  static final SoundClassifier I = SoundClassifier._();

  static const sampleRate = 16000;
  int windowSize = 15600;
  Interpreter? _interp;
  IsolateInterpreter? _iso;
  List<String> labels = const [];
  int _outIdx = 0, _classes = 521;
  bool ready = false;
  String status = 'Not loaded';

  Future<bool> load() async {
    if (ready) return true;
    try {
      final txt = await rootBundle.loadString('assets/labels/yamnet_labels.txt');
      labels = txt.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      final interp = await Interpreter.fromAsset('assets/models/yamnet.tflite', options: InterpreterOptions()..threads = 2);
      final input = interp.getInputTensor(0);
      windowSize = input.shape.last;
      for (var i = 0; i < interp.getOutputTensors().length; i++) {
        final t = interp.getOutputTensor(i);
        if (t.shape.isNotEmpty && t.shape.last == labels.length) {
          _outIdx = i;
          _classes = t.shape.last;
          break;
        }
      }
      _interp = interp;
      _iso = await IsolateInterpreter.create(address: interp.address);
      ready = labels.length >= 500;
      status = ready ? 'YAMNet (${labels.length} sounds)' : 'Sound labels missing';
    } catch (e) {
      ready = false;
      status = 'Sound model missing, using loudness only';
    }
    return ready;
  }

  /// Returns the top labels with their scores (0..1).
  Future<List<MapEntry<String, double>>> classify(Float32List window) async {
    if (!ready || _iso == null) return const [];
    final outputs = <int, Object>{_outIdx: [List<double>.filled(_classes, 0)]};
    await _iso!.runForMultipleInputs([window.buffer.asUint8List()], outputs);
    final scores = ((outputs[_outIdx] as List)[0] as List).map((v) => (v as num).toDouble()).toList();
    final idx = List<int>.generate(scores.length, (i) => i)..sort((a, b) => scores[b].compareTo(scores[a]));
    return [for (final i in idx.take(5)) if (i < labels.length) MapEntry(labels[i], scores[i])];
  }

  static SoundCategory? categorize(String label) {
    final l = label.toLowerCase();
    for (final c in soundCategories) {
      if (c.keys.any(l.contains)) return c;
    }
    return null;
  }
}
