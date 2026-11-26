import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'app_state.dart';
import 'haptics.dart';
import 'strings.dart';

final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

/// Routes every alert to the senses the user's profile can use:
/// voice, vibration and/or a full-screen visual alert.
class Output {
  static final FlutterTts _tts = FlutterTts();
  static OverlayEntry? _entry;
  static Timer? _timer;

  static Future<void> init() async {
    try {
      await _tts.setSpeechRate(0.5);
      await _tts.awaitSpeakCompletion(false);
    } catch (_) {}
  }

  static Future<void> speak(String text, {bool force = false}) async {
    if (!AppState.I.out.voice && !force) return;
    try {
      await _tts.stop();
      await _tts.setLanguage(S.ttsLocale);
      await _tts.speak(text);
    } catch (_) {}
  }

  static Future<void> stopSpeech() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  static void notify(String text, List<int> pattern, {Color color = const Color(0xFFFF5A4E)}) {
    final o = AppState.I.out;
    if (o.vibration) Haptics.play(pattern);
    if (o.voice) speak(text);
    if (o.visual) showAlert(text, color);
  }

  static void showAlert(String text, Color color) {
    final overlay = navKey.currentState?.overlay;
    if (overlay == null) return;
    hideAlert();
    _entry = OverlayEntry(builder: (_) => _AlertOverlay(text: text, color: color, onClose: hideAlert));
    overlay.insert(_entry!);
    _timer = Timer(const Duration(seconds: 4), hideAlert);
  }

  static void hideAlert() {
    _timer?.cancel();
    _entry?.remove();
    _entry = null;
  }
}

class _AlertOverlay extends StatelessWidget {
  final String text;
  final Color color;
  final VoidCallback onClose;
  const _AlertOverlay({required this.text, required this.color, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        color: color,
        child: InkWell(
          onTap: onClose,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning_rounded, size: 140, color: Colors.white),
                  const SizedBox(height: 16),
                  Text(text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1)),
                  const SizedBox(height: 24),
                  const Text('Tap to close', style: TextStyle(color: Colors.white70, fontSize: 18)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
