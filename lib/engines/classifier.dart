import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'detector.dart';

/// Generic on-device image classifier (e.g. the peso bill model trained in training/).
class ImageClassifier {
  ImageClassifier(this.name);
  static final ImageClassifier peso = ImageClassifier('peso');

  final String name;
  Interpreter? _interp;
  IsolateInterpreter? _iso;
  List<String> labels = [];
  int inW = 224, inH = 224, _classes = 0;
  bool asFloat = false, ready = false;
  String status = 'Not loaded';

  Future<bool> load() async {
    if (ready) return true;
    try {
      final txt = await rootBundle.loadString('assets/labels/${name}_labels.txt');
      labels = txt.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      final interp = await Interpreter.fromAsset('assets/models/$name.tflite', options: InterpreterOptions()..threads = 2);
      final input = interp.getInputTensor(0);
      inH = input.shape[1];
      inW = input.shape[2];
      asFloat = input.type == TensorType.float32;
      _classes = interp.getOutputTensor(0).shape.last;
      _interp = interp;
      _iso = await IsolateInterpreter.create(address: interp.address);
      ready = labels.isNotEmpty;
      status = '${labels.length} classes';
    } catch (_) {
      ready = false;
      status = 'Not installed (train with the notebook in training/)';
    }
    return ready;
  }

  Future<MapEntry<String, double>?> classify(FrameData frame) async {
    if (!ready || _iso == null) return null;
    final input = await convertFrameInBackground(frame);
    final outputs = <int, Object>{0: [List<double>.filled(_classes, 0)]};
    await _iso!.runForMultipleInputs([input], outputs);
    final raw = ((outputs[0] as List)[0] as List).map((v) => (v as num).toDouble()).toList();
    // Quantized models output 0..255; normalize.
    final scores = raw.any((v) => v > 1.0) ? raw.map((v) => v / 255.0).toList() : raw;
    var best = 0;
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] > scores[best]) best = i;
    }
    if (best >= labels.length) return null;
    return MapEntry(labels[best], scores[best]);
  }
}
