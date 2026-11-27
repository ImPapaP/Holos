import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../core/app_state.dart';

/// One detected object. [box] is normalized (0..1) in the upright (portrait) image.
class Det {
  final String label;
  final double score;
  final Rect box;
  const Det(this.label, this.score, this.box);

  double get closeness => max(box.width * box.height, pow(box.height, 2) * 0.6).toDouble();
  bool get isVehicle => vehicleLabels.contains(label);
  bool get isHazard => isVehicle || hazardLabels.contains(label);
}

const vehicleLabels = {'car', 'motorcycle', 'bus', 'truck', 'bicycle', 'train', 'tricycle', 'jeepney', 'e-trike', 'pedicab'};

/// Labels from Gabay's custom model (see training/) that mean "stop and check".
const hazardLabels = {'stairs', 'stairs_down', 'stairs_up', 'curb', 'hole', 'open_canal', 'manhole', 'pole', 'wire', 'step'};

/// COCO label map used by EfficientDet-Lite models (index = class id). '???' = unused id.
const cocoLabels = [
  'person', 'bicycle', 'car', 'motorcycle', 'airplane', 'bus', 'train', 'truck', 'boat', 'traffic light',
  'fire hydrant', '???', 'stop sign', 'parking meter', 'bench', 'bird', 'cat', 'dog', 'horse', 'sheep',
  'cow', 'elephant', 'bear', 'zebra', 'giraffe', '???', 'backpack', 'umbrella', '???', '???',
  'handbag', 'tie', 'suitcase', 'frisbee', 'skis', 'snowboard', 'sports ball', 'kite', 'baseball bat', 'baseball glove',
  'skateboard', 'surfboard', 'tennis racket', 'bottle', '???', 'wine glass', 'cup', 'fork', 'knife', 'spoon',
  'bowl', 'banana', 'apple', 'sandwich', 'orange', 'broccoli', 'carrot', 'hot dog', 'pizza', 'donut',
  'cake', 'chair', 'couch', 'potted plant', 'bed', '???', 'dining table', '???', '???', 'toilet',
  '???', 'tv', 'laptop', 'mouse', 'remote', 'keyboard', 'cell phone', 'microwave', 'oven', 'toaster',
  'sink', 'refrigerator', '???', 'book', 'clock', 'vase', 'scissors', 'teddy bear', 'hair drier', 'toothbrush',
];

/// Raw camera frame data, sent to a background isolate for conversion.
class FrameData {
  final Uint8List bytes;
  final int width, height, stride, rotation, outW, outH;
  final bool nv21; // true: Android NV21, false: iOS BGRA
  final bool asFloat; // float32 input normalized to [-1, 1]
  const FrameData(this.bytes, this.width, this.height, this.stride, this.rotation, this.outW, this.outH, this.nv21, this.asFloat);
}

/// Converts a camera frame into the detector's input: upright, resized RGB.
Uint8List frameToModelInput(FrameData f) {
  final uprightW = (f.rotation == 90 || f.rotation == 270) ? f.height : f.width;
  final uprightH = (f.rotation == 90 || f.rotation == 270) ? f.width : f.height;
  final n = f.outW * f.outH * 3;
  final out = f.asFloat ? Float32List(n) : null;
  final outU8 = f.asFloat ? null : Uint8List(n);
  final uvStart = f.stride * f.height;
  var o = 0;
  for (var oy = 0; oy < f.outH; oy++) {
    final uy = (oy * uprightH) ~/ f.outH;
    for (var ox = 0; ox < f.outW; ox++) {
      final ux = (ox * uprightW) ~/ f.outW;
      int sx, sy;
      switch (f.rotation) {
        case 90:
          sx = uy;
          sy = f.height - 1 - ux;
          break;
        case 180:
          sx = f.width - 1 - ux;
          sy = f.height - 1 - uy;
          break;
        case 270:
          sx = f.width - 1 - uy;
          sy = ux;
          break;
        default:
          sx = ux;
          sy = uy;
      }
      int r, g, b;
      if (f.nv21) {
        final y = f.bytes[sy * f.stride + sx];
        final uvIndex = uvStart + (sy >> 1) * f.stride + (sx & ~1);
        final v = (uvIndex < f.bytes.length ? f.bytes[uvIndex] : 128) - 128;
        final u = (uvIndex + 1 < f.bytes.length ? f.bytes[uvIndex + 1] : 128) - 128;
        r = (y + 1.402 * v).round().clamp(0, 255);
        g = (y - 0.344 * u - 0.714 * v).round().clamp(0, 255);
        b = (y + 1.772 * u).round().clamp(0, 255);
      } else {
        final i = sy * f.stride + sx * 4;
        b = f.bytes[i];
        g = f.bytes[i + 1];
        r = f.bytes[i + 2];
      }
      if (out != null) {
        out[o] = (r - 127.5) / 127.5;
        out[o + 1] = (g - 127.5) / 127.5;
        out[o + 2] = (b - 127.5) / 127.5;
      } else {
        outU8![o] = r;
        outU8[o + 1] = g;
        outU8[o + 2] = b;
      }
      o += 3;
    }
  }
  return out != null ? out.buffer.asUint8List() : outU8!;
}

/// Top-level so the background isolate only receives the frame data.
Future<Uint8List> convertFrameInBackground(FrameData f) => Isolate.run(() => frameToModelInput(f));

/// Turns RGBA pixels (already resized to the model size) into model input.
Uint8List rgbaToModelInput(Uint8List rgba, int w, int h, bool asFloat) {
  final n = w * h * 3;
  if (asFloat) {
    final out = Float32List(n);
    for (var i = 0, o = 0; i < w * h; i++, o += 3) {
      out[o] = rgba[i * 4] / 127.5 - 1;
      out[o + 1] = rgba[i * 4 + 1] / 127.5 - 1;
      out[o + 2] = rgba[i * 4 + 2] / 127.5 - 1;
    }
    return out.buffer.asUint8List();
  }
  final out = Uint8List(n);
  for (var i = 0, o = 0; i < w * h; i++, o += 3) {
    out[o] = rgba[i * 4];
    out[o + 1] = rgba[i * 4 + 1];
    out[o + 2] = rgba[i * 4 + 2];
  }
  return out;
}

/// EfficientDet-Lite object detector (COCO, 80 everyday objects), running on the phone.
class Detector {
  Detector._(this.name, {this.optional = false});

  /// Main COCO detector (EfficientDet-Lite).
  static final Detector I = Detector._('detector');

  /// Optional custom model trained on Philippine streets (stairs, curbs, holes, tricycles, jeepneys...).
  static final Detector custom = Detector._('custom_detector', optional: true);

  final String name;
  final bool optional;
  int lastMs = 0; // time for the last detection, for testing mode

  Interpreter? _interp;
  IsolateInterpreter? _iso;
  List<String> labels = cocoLabels;
  int inW = 320, inH = 320;
  bool asFloat = false;
  int _boxIdx = 0, _classIdx = 1, _scoreIdx = 2, _countIdx = 3, _n = 25;
  bool ready = false;
  String status = 'Not loaded';
  double minScore = 0.45;

  Future<bool> load() async {
    if (ready) return true;
    try {
      final opts = InterpreterOptions()..threads = 4;
      if (AppState.I.speedBoost) opts.useNnApiForAndroid = true; // phone's AI chip, if it has one
      final interp = await Interpreter.fromAsset('assets/models/$name.tflite', options: opts);
      final input = interp.getInputTensor(0);
      inH = input.shape[1];
      inW = input.shape[2];
      asFloat = input.type == TensorType.float32;

      final twoD = <int>[];
      for (var i = 0; i < interp.getOutputTensors().length; i++) {
        final t = interp.getOutputTensor(i);
        final name = t.name.toLowerCase();
        if (t.shape.length == 3 && t.shape.last == 4) {
          _boxIdx = i;
          _n = t.shape[1];
        } else if (t.shape.length == 1) {
          _countIdx = i;
        } else if (t.shape.length == 2) {
          if (name.contains('score')) {
            _scoreIdx = i;
          } else if (name.contains('class') || name.contains('categor')) {
            _classIdx = i;
          } else {
            twoD.add(i);
          }
        }
      }
      if (twoD.length == 2) {
        _classIdx = twoD[0];
        _scoreIdx = twoD[1];
      }
      try {
        final txt = await rootBundle.loadString('assets/labels/${name}_labels.txt');
        final lines = txt.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
        if (lines.length >= 80 || optional) labels = lines;
      } catch (_) {}
      _interp = interp;
      _iso = await IsolateInterpreter.create(address: interp.address);
      ready = true;
      status = optional ? 'Custom model (${labels.length} classes)' : 'EfficientDet-Lite ${inW}x$inH (${asFloat ? 'float' : 'int8'})${AppState.I.speedBoost ? ' + speed boost' : ''}';
    } catch (e) {
      ready = false;
      status = optional ? 'Not installed (train with training/ notebook)' : 'Detector model missing, using ML Kit fallback';
    }
    return ready;
  }

  /// Runs detection on one frame. Returns objects above [minScore].
  Future<List<Det>> detect(FrameData frame) async {
    if (!ready || _iso == null) return const [];
    final sw = Stopwatch()..start();
    final input = await convertFrameInBackground(frame);
    final out = await detectInput(input);
    lastMs = sw.elapsedMilliseconds;
    return out;
  }

  /// Runs the model on an already-prepared input (inW x inH x 3, uint8 or float bytes).
  Future<List<Det>> detectInput(Uint8List input) async {
    if (!ready || _iso == null) return const [];
    final outputs = <int, Object>{
      _boxIdx: [List.generate(_n, (_) => List<double>.filled(4, 0))],
      _classIdx: [List<double>.filled(_n, 0)],
      _scoreIdx: [List<double>.filled(_n, 0)],
      _countIdx: List<double>.filled(1, 0),
    };
    await _iso!.runForMultipleInputs([input], outputs);
    final boxes = (outputs[_boxIdx] as List).cast<List>();
    final classes = (outputs[_classIdx] as List).cast<List>();
    final scores = (outputs[_scoreIdx] as List).cast<List>();
    final count = outputs[_countIdx] as List;
    final c0 = (count[0] as num).round();
    final total = min(_n, c0 <= 0 ? _n : c0);
    final out = <Det>[];
    for (var i = 0; i < total; i++) {
      final s = (scores[0][i] as num).toDouble();
      if (s < minScore) continue;
      final c = (classes[0][i] as num).round();
      if (c < 0 || c >= labels.length) continue;
      final label = labels[c];
      if (label == '???' || label.isEmpty) continue;
      final b = (boxes[0][i] as List).map((v) => (v as num).toDouble().clamp(0.0, 1.0)).toList();
      final rect = Rect.fromLTRB(b[1], b[0], b[3], b[2]);
      if (rect.width <= 0 || rect.height <= 0) continue;
      out.add(Det(label, s, rect));
    }
    return out;
  }
}

/// Cuts false alarms: an object is only reported after it appears in
/// 2 of the last 3 frames at roughly the same place.
class DetTracker {
  final List<List<Det>> _history = [];

  List<Det> update(List<Det> frame) {
    _history.add(frame);
    if (_history.length > 3) _history.removeAt(0);
    final confirmed = <Det>[];
    for (final d in frame) {
      var hits = 0;
      for (final past in _history) {
        if (past.any((p) => p.label == d.label && _iou(p.box, d.box) > 0.2)) hits++;
      }
      if (hits >= 2 || (d.score > 0.75 && d.closeness > 0.3)) confirmed.add(d);
    }
    return confirmed;
  }

  void clear() => _history.clear();

  static double _iou(Rect a, Rect b) {
    final i = a.intersect(b);
    if (i.width <= 0 || i.height <= 0) return 0;
    final inter = i.width * i.height;
    return inter / (a.width * a.height + b.width * b.height - inter);
  }
}
