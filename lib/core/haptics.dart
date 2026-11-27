import 'package:vibration/vibration.dart';

/// Vibration patterns are written as [on, off, on, ...] in milliseconds.
class Haptics {
  static const center = [400];
  static const left = [120, 100, 120];
  static const right = [120, 100, 120, 100, 120];
  static const danger = [80, 60, 80, 60, 80, 60, 80, 60, 300];
  static const sudden = [600, 150, 600, 150, 600];
  static const continuous = [300, 100, 300, 100, 300, 100, 300, 100, 300];
  static const gas = [1000, 200, 1000, 200, 1000];
  static const hot = [150, 80, 150, 80, 150, 80, 150];
  static const sos = [100, 100, 100, 100, 100, 300, 300, 100, 300, 100, 300, 300, 100, 100, 100, 100, 100];
  static const start = [60, 80, 60];
  static const pause = [300];
  static const clear = [40];
  static const gentle = [150, 200, 150];
  /// Haptic logo: braille "g" (dots 1-2-4-5) as four short pulses, played when Gabay opens.
  static const logo = [70, 90, 70, 90, 70, 90, 70];

  static bool? _hasVibrator;

  static Future<void> play(List<int> onOff) async {
    _hasVibrator ??= (await Vibration.hasVibrator()) ?? false;
    if (_hasVibrator != true || onOff.isEmpty) return;
    // The vibration package expects [wait, on, wait, on, ...].
    await Vibration.vibrate(pattern: [0, ...onOff]);
  }

  /// One pulse with a strength from 1 (soft) to 255 (strong), on phones that support it.
  static Future<void> pulse(int ms, int amplitude) async {
    _hasVibrator ??= (await Vibration.hasVibrator()) ?? false;
    if (_hasVibrator != true) return;
    await Vibration.vibrate(duration: ms, amplitude: amplitude.clamp(1, 255));
  }

  static Future<void> cancel() => Vibration.cancel();

  static List<int> pulses(int count, int on, int off) {
    final p = <int>[];
    for (var i = 0; i < count; i++) {
      if (i > 0) p.add(off);
      p.add(on);
    }
    return p;
  }
}

const Map<String, String> morseCode = {
  'A': '.-', 'B': '-...', 'C': '-.-.', 'D': '-..', 'E': '.', 'F': '..-.', 'G': '--.',
  'H': '....', 'I': '..', 'J': '.---', 'K': '-.-', 'L': '.-..', 'M': '--', 'N': '-.',
  'O': '---', 'P': '.--.', 'Q': '--.-', 'R': '.-.', 'S': '...', 'T': '-', 'U': '..-',
  'V': '...-', 'W': '.--', 'X': '-..-', 'Y': '-.--', 'Z': '--..',
  '0': '-----', '1': '.----', '2': '..---', '3': '...--', '4': '....-',
  '5': '.....', '6': '-....', '7': '--...', '8': '---..', '9': '----.',
};

/// Plays text as Morse code vibration, one letter at a time.
class MorsePlayer {
  int _token = 0;

  Future<void> play(String text, int unitMs, void Function(String letter) onLetter) async {
    final token = ++_token;
    final words = text.toUpperCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    for (var wi = 0; wi < words.length; wi++) {
      final chars = words[wi].split('').where(morseCode.containsKey).toList();
      for (var ci = 0; ci < chars.length; ci++) {
        if (token != _token) return;
        final c = chars[ci];
        onLetter(c);
        final code = morseCode[c]!;
        final pattern = <int>[];
        for (var si = 0; si < code.length; si++) {
          if (si > 0) pattern.add(unitMs);
          pattern.add(code[si] == '.' ? unitMs : unitMs * 3);
        }
        await Haptics.play(pattern);
        final duration = pattern.fold<int>(0, (a, b) => a + b);
        final gap = ci == chars.length - 1 ? (wi == words.length - 1 ? 0 : unitMs * 7) : unitMs * 3;
        await Future.delayed(Duration(milliseconds: duration + gap));
      }
    }
    if (token == _token) onLetter('✓');
  }

  void stop() {
    _token++;
    Haptics.cancel();
  }
}
