import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

/// Tilt-compensated compass from the accelerometer and magnetometer.
/// Held flat: heading of the top of the phone. Held upright (lanyard): heading of the camera.
class HeadingService {
  StreamSubscription? _acc, _mag;
  List<double> _g = [0, 0, 9.8], _m = [0, 0, 0];
  double? heading; // degrees from magnetic north, 0..360
  final void Function(double heading)? onHeading;

  HeadingService({this.onHeading});

  void start() {
    _acc = accelerometerEventStream().listen((e) {
      _g = _lowPass([e.x, e.y, e.z], _g);
      _compute();
    });
    _mag = magnetometerEventStream().listen((e) {
      _m = _lowPass([e.x, e.y, e.z], _m);
    });
  }

  void stop() {
    _acc?.cancel();
    _mag?.cancel();
  }

  static List<double> _lowPass(List<double> v, List<double> prev) => [for (var i = 0; i < 3; i++) prev[i] + 0.15 * (v[i] - prev[i])];

  void _compute() {
    final a = _g, e = _m;
    // Same math as Android's SensorManager.getRotationMatrix.
    var hx = e[1] * a[2] - e[2] * a[1], hy = e[2] * a[0] - e[0] * a[2], hz = e[0] * a[1] - e[1] * a[0];
    final hn = sqrt(hx * hx + hy * hy + hz * hz);
    if (hn < 0.1) return;
    hx /= hn;
    hy /= hn;
    hz /= hn;
    final an = sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2]);
    final ax = a[0] / an, ay = a[1] / an, az = a[2] / an;
    final mx = ay * hz - az * hy, my = az * hx - ax * hz, mz = ax * hy - ay * hx;
    double deg;
    if (az.abs() < 0.6) {
      deg = atan2(-hz, -mz) * 180 / pi; // upright: direction the camera faces
    } else {
      deg = atan2(hy, my) * 180 / pi; // flat: direction the top edge points
    }
    heading = (deg + 360) % 360;
    onHeading?.call(heading!);
  }
}

double bearingTo(double lat1, double lon1, double lat2, double lon2) {
  final p1 = lat1 * pi / 180, p2 = lat2 * pi / 180, dl = (lon2 - lon1) * pi / 180;
  final y = sin(dl) * cos(p2);
  final x = cos(p1) * sin(p2) - sin(p1) * cos(p2) * cos(dl);
  return (atan2(y, x) * 180 / pi + 360) % 360;
}

/// Signed difference -180..180 (positive = target is to the right).
double angleDiff(double target, double heading) => ((target - heading + 540) % 360) - 180;
