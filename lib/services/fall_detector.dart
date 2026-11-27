import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

import '../core/app_state.dart';
import '../modules/sos_screen.dart';

/// Detects a hard impact followed by stillness using the accelerometer.
/// Works while Gabay is open. A background service is a future improvement.
class FallDetector {
  FallDetector._();
  static final FallDetector I = FallDetector._();

  StreamSubscription<AccelerometerEvent>? _sub;
  DateTime? _impactAt;
  final List<double> _after = [];

  void sync() {
    if (AppState.I.fallDetection && _sub == null) {
      _sub = accelerometerEventStream().listen(_onEvent, onError: (_) {});
    } else if (!AppState.I.fallDetection && _sub != null) {
      _sub?.cancel();
      _sub = null;
    }
  }

  void _onEvent(AccelerometerEvent e) {
    final g = sqrt(e.x * e.x + e.y * e.y + e.z * e.z); // ~9.8 when still
    final now = DateTime.now();
    if (_impactAt == null) {
      if (g > 28) {
        _impactAt = now;
        _after.clear();
      }
      return;
    }
    final since = now.difference(_impactAt!).inMilliseconds;
    if (since < 800) return; // ignore bounce right after impact
    _after.add(g);
    if (since > 2800) {
      final mean = _after.reduce((a, b) => a + b) / _after.length;
      final still = _after.every((v) => (v - mean).abs() < 2.5);
      _impactAt = null;
      if (still) SosScreen.trigger(reason: 'Fall detected', countdown: true);
    }
  }
}
