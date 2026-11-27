import 'package:flutter/services.dart';

import '../core/app_state.dart';

/// Auto mode: reads the phone's ambient light sensor once when Gabay opens.
/// Bright surroundings (outdoors in daylight) -> Daylight theme, otherwise Gabay Night.
/// It only decides at launch so the screen never changes in the middle of a walk.
class AutoTheme {
  static const _channel = MethodChannel('gabay/light');
  static const brightLux = 1000; // overcast daylight is 1,000+ lux; indoor rooms are usually under 500

  static Future<void> pick() async {
    if (AppState.I.themeChoice != 'auto') return;
    try {
      final lux = await _channel.invokeMethod<double>('read');
      if (lux == null || lux < 0) return; // no light sensor: keep Gabay Night
      AppState.I.setAutoPick(lux >= brightLux ? 'day' : 'night');
    } catch (_) {
      // Keep Gabay Night if anything goes wrong.
    }
  }
}
