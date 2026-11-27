import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../core/app_state.dart';
import '../core/haptics.dart';
import '../core/output.dart';
import '../core/profiles.dart';
import '../core/strings.dart';

/// Hands-free module opening: say "Lakad", "Basahin", "Tunog", "Tulong"...
class VoiceCommands {
  static final _speech = stt.SpeechToText();

  static const _words = <Module, List<String>>{
    Module.sos: ['sos', 'tulong', 'help', 'saklolo', 'emergency'],
    Module.sight: ['lakad', 'walk', 'sight', 'maglakad'],
    Module.sweep: ['sweep', 'scan', 'hanap'],
    Module.touch: ['touch', 'hawak', 'explore', 'kapa'],
    Module.read: ['basa', 'read', 'basahin', 'text'],
    Module.scene: ['ilarawan', 'describe', 'scene', 'paligid'],
    Module.color: ['kulay', 'color', 'colour', 'liwanag', 'light'],
    Module.peso: ['pera', 'peso', 'money', 'piso', 'bill'],
    Module.nav: ['daan', 'navigate', 'guide', 'direksyon', 'way', 'gabayan'],
    Module.sound: ['tunog', 'sound', 'caption', 'pakinig'],
    Module.talk: ['talk', 'morse', 'mensahe', 'message'],
    Module.calm: ['kalma', 'calm', 'breathe', 'hinga'],
    Module.sensor: ['sensor', 'gas', 'usok', 'smoke'],
  };

  /// Listens for up to 5 seconds and returns the module that was named, if any.
  static Future<Module?> listen() async {
    final ok = await _speech.initialize(onError: (_) {});
    if (!ok) {
      Output.speak('Voice commands are not available on this phone', force: true);
      return null;
    }
    Haptics.play(Haptics.start);
    final done = Completer<Module?>();
    String heard = '';
    await _speech.listen(
      onResult: (r) {
        heard = r.recognizedWords.toLowerCase();
        final m = match(heard);
        if (m != null && !done.isCompleted) {
          _speech.stop();
          done.complete(m);
        } else if (r.finalResult && !done.isCompleted) {
          done.complete(null);
        }
      },
      localeId: S.sttLocale,
      listenFor: const Duration(seconds: 5),
      pauseFor: const Duration(seconds: 2),
      listenOptions: stt.SpeechListenOptions(partialResults: true, onDevice: AppState.I.offlineCaptions),
    );
    final m = await done.future.timeout(const Duration(seconds: 6), onTimeout: () => null);
    if (m == null) {
      Output.speak(S.lang == Lang.fil ? 'Hindi ko naintindihan. Subukan ulit.' : 'Sorry, I did not catch that. Try again.', force: true);
    } else {
      Output.speak(modules[m]!.title, force: true);
    }
    return m;
  }

  static Module? match(String text) {
    for (final e in _words.entries) {
      if (e.value.any(text.contains)) return e.key;
    }
    return null;
  }
}
