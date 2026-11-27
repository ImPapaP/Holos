import 'dart:async';

import 'package:light/light.dart';

import '../core/app_state.dart';

/// Auto mode: reads the phone's ambient light sensor once when Gabay opens.
/// Bright surroundings (outdoors in daylight) -> Daylight theme, otherwise Gabay Night.
/// It only decides at launch so the screen never changes in the middle of a walk.
class AutoTheme {
  static const brightLux = 1000; // typical overcast daylight is 1,000+ lux; indoors is usually under 500

  static Future<void> pick() async {
    if (AppState.I.themeChoice != 'auto') return;
    try {
      final lux = await Light().lightSensorStream.first.timeout(const Duration(seconds: 2));
      AppState.I.setAutoPick(lux >= brightLux ? 'day' : 'night');
    } catch (_) {
      // No light sensor or no reading: keep Gabay Night.
    }
  }
}
