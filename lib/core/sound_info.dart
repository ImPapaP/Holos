import 'package:flutter/material.dart';

import 'haptics.dart';
import 'strings.dart';

/// Icon, vibration pattern and message for each recognized sound category.
class SoundInfo {
  static IconData icon(String cat) => switch (cat) {
        'horn' => Icons.directions_car,
        'siren' => Icons.emergency,
        'alarm' => Icons.alarm,
        'explosion' => Icons.warning_amber,
        'scream' => Icons.record_voice_over,
        'glass' => Icons.broken_image,
        'baby' => Icons.child_care,
        'doorbell' => Icons.doorbell,
        'knock' => Icons.door_front_door,
        'dog' => Icons.pets,
        'phone' => Icons.phone_in_talk,
        'speech' => Icons.forum,
        _ => Icons.graphic_eq,
      };

  static List<int> pattern(String cat) => switch (cat) {
        'horn' => Haptics.danger,
        'siren' || 'alarm' => Haptics.continuous,
        'explosion' || 'scream' || 'glass' => Haptics.danger,
        'baby' => [100, 100, 100, 100, 400],
        'doorbell' => [200, 120, 200],
        'knock' => [60, 80, 60, 80, 60],
        'dog' => [150, 100, 150],
        'phone' => [300, 200, 300, 200, 300],
        _ => Haptics.sudden,
      };

  static String text(String cat) => S.t('snd_$cat');
}
