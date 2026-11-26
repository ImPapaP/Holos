import 'dart:async';
import 'dart:math';

import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/app_state.dart';

/// Listens to the microphone and reports:
///  - 'sudden'     : a sharp spike above the room's normal level (horn, bang, shout)
///  - 'continuous' : loud sound that keeps going (alarm, siren)
///
/// Prototype logic uses decibel levels. Next step for the capstone: replace
/// [_classify] with a YAMNet TensorFlow Lite model to name the exact sound.
class SoundWatcher {
  final void Function(String kind)? onAlert;
  final void Function(double db)? onLevel;

  SoundWatcher({this.onAlert, this.onLevel});

  StreamSubscription<NoiseReading>? _sub;
  double _baseline = 50;
  DateTime _lastAlert = DateTime.fromMillisecondsSinceEpoch(0);
  final List<_Sample> _recent = [];

  bool get running => _sub != null;

  Future<bool> start() async {
    if (_sub != null) return true;
    final status = await Permission.microphone.request();
    if (!status.isGranted) return false;
    try {
      _sub = NoiseMeter().noise.listen(_onReading, onError: (_) => stop());
      return true;
    } catch (_) {
      return false;
    }
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _recent.clear();
  }

  void _onReading(NoiseReading r) {
    final db = r.meanDecibel;
    if (db.isNaN || db.isInfinite) return;
    onLevel?.call(db);
    final kind = _classify(db, r.maxDecibel.isFinite ? r.maxDecibel : db);
    _baseline = _baseline * 0.97 + db * 0.03;
    final now = DateTime.now();
    if (kind != null && now.difference(_lastAlert).inMilliseconds > 3500) {
      _lastAlert = now;
      _recent.clear();
      onAlert?.call(kind);
    }
  }

  String? _classify(double db, double maxDb) {
    // Sensitivity slider shifts the thresholds (+ = more sensitive).
    final shift = AppState.I.soundSensitivity;
    final now = DateTime.now();
    _recent.add(_Sample(now, db));
    _recent.removeWhere((s) => now.difference(s.at).inMilliseconds > 1500);

    final loudLevel = 80 - shift;
    final window = _recent.length >= 5 ? _recent : null;
    if (window != null &&
        now.difference(window.first.at).inMilliseconds > 1200 &&
        window.where((s) => s.db > loudLevel).length >= window.length * 0.85) {
      return 'continuous';
    }
    if (maxDb > max(85 - shift, _baseline + 25 - shift)) return 'sudden';
    return null;
  }
}

class _Sample {
  final DateTime at;
  final double db;
  _Sample(this.at, this.db);
}
