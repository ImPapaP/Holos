import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../core/app_state.dart';
import '../engines/sound_classifier.dart';

/// A recognized sound.
class SoundEvent {
  final String category; // horn, siren, alarm, ... or 'loud' when only loudness is known
  final String label; // YAMNet's own label, e.g. "Vehicle horn, car horn, honking"
  final double score;
  final bool urgent;
  const SoundEvent(this.category, this.label, this.score, this.urgent);
}

/// Listens to the microphone (16 kHz), measures loudness and recognizes sounds with YAMNet.
/// To cut false alarms, a sound must be recognized in 2 windows in a row before it alerts.
class SoundWatcher {
  final void Function(SoundEvent e)? onEvent;
  final void Function(double db)? onLevel;
  final void Function(String? speechLabel)? onSpeech;

  SoundWatcher({this.onEvent, this.onLevel, this.onSpeech});

  AudioRecorder? _rec;
  StreamSubscription<Uint8List>? _sub;
  final Float32List _ring = Float32List(SoundClassifier.sampleRate * 2);
  int _filled = 0, _sinceLast = 0;
  bool _busy = false;
  String? _lastCat;
  final Map<String, DateTime> _cooldown = {};
  double _baseline = 50;

  bool get running => _sub != null;

  Future<bool> start() async {
    if (_sub != null) return true;
    await SoundClassifier.I.load();
    final rec = AudioRecorder();
    if (!await rec.hasPermission()) {
      await rec.dispose();
      return false;
    }
    try {
      final stream = await rec.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: SoundClassifier.sampleRate,
        numChannels: 1,
      ));
      _rec = rec;
      _sub = stream.listen(_onPcm, onError: (_) => stop());
      return true;
    } catch (_) {
      await rec.dispose();
      return false;
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    final rec = _rec;
    _rec = null;
    if (rec != null) {
      try {
        await rec.stop();
      } catch (_) {}
      await rec.dispose();
    }
    _filled = 0;
  }

  void _onPcm(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    final n = bytes.length ~/ 2;
    if (n == 0) return;
    var sum = 0.0;
    for (var i = 0; i < n; i++) {
      final v = data.getInt16(i * 2, Endian.little) / 32768.0;
      sum += v * v;
      _ring[(_filled + i) % _ring.length] = v;
    }
    _filled += n;
    _sinceLast += n;

    final rms = sqrt(sum / n);
    final db = (20 * log(max(rms, 1e-6)) / ln10 + 90).clamp(30.0, 110.0);
    onLevel?.call(db);

    if (!SoundClassifier.I.ready) {
      _loudnessOnly(db);
      return;
    }
    // Classify every 0.5 s on the latest window.
    final win = SoundClassifier.I.windowSize;
    if (_filled >= win && _sinceLast >= SoundClassifier.sampleRate ~/ 2 && !_busy) {
      _sinceLast = 0;
      final window = Float32List(win);
      final end = _filled % _ring.length;
      for (var i = 0; i < win; i++) {
        window[i] = _ring[(end - win + i + _ring.length) % _ring.length];
      }
      _classify(window);
    }
  }

  Future<void> _classify(Float32List window) async {
    _busy = true;
    try {
      final top = await SoundClassifier.I.classify(window);
      final threshold = 0.35 - AppState.I.soundSensitivity / 100; // sensitivity slider shifts it
      SoundEvent? best;
      String? speech;
      for (final e in top) {
        if (e.value < threshold) continue;
        final cat = SoundClassifier.categorize(e.key);
        if (cat == null) continue;
        if (cat.id == 'speech') {
          speech = e.key;
          continue;
        }
        best = SoundEvent(cat.id, e.key, e.value, cat.urgent);
        break;
      }
      onSpeech?.call(speech);
      if (best == null) {
        _lastCat = null;
        return;
      }
      // Must appear in two windows in a row (about 0.5 s apart).
      if (_lastCat != best.category) {
        _lastCat = best.category;
        return;
      }
      final now = DateTime.now();
      final last = _cooldown[best.category];
      if (last != null && now.difference(last).inSeconds < 4) return;
      _cooldown[best.category] = now;
      onEvent?.call(best);
    } catch (_) {
    } finally {
      _busy = false;
    }
  }

  // Fallback when the YAMNet model is not available: sudden loud sounds only.
  void _loudnessOnly(double db) {
    final shift = AppState.I.soundSensitivity;
    final now = DateTime.now();
    if (db > max(85 - shift, _baseline + 25 - shift)) {
      final last = _cooldown['loud'];
      if (last == null || now.difference(last).inMilliseconds > 3500) {
        _cooldown['loud'] = now;
        onEvent?.call(const SoundEvent('loud', 'Loud sound', 1, true));
      }
    }
    _baseline = _baseline * 0.97 + db * 0.03;
  }
}
