import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/haptics.dart';
import '../core/output.dart';
import '../core/profiles.dart';
import '../core/sound_info.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../engines/detector.dart';
import '../engines/vision_camera.dart';
import '../services/sound_watcher.dart';
import '../services/test_log.dart';
import '../widgets/verdict_bar.dart';
import 'sos_screen.dart';

/// Lakad (walk): obstacles ahead -> direction + distance -> vibration, voice and visual helpers.
/// Gestures: tap = pause, double-tap = repeat, hold 1.5 s = SOS.
class SightScreen extends StatefulWidget {
  const SightScreen({super.key});

  @override
  State<SightScreen> createState() => _SightScreenState();
}

class _Target {
  final Det det;
  final String dir; // left / center / right
  final int near; // 1 far, 2 close, 3 very close
  final DateTime at = DateTime.now();
  _Target(this.det, this.dir, this.near);
  String get key => '${det.label}$dir$near';
}

String dirOf(Det d) {
  final cx = d.box.center.dx;
  return cx < 0.38 ? 'left' : (cx > 0.62 ? 'right' : 'center');
}

int nearOf(Det d) => d.closeness > 0.3 ? 3 : (d.closeness > 0.12 ? 2 : 1);

String describeDet(Det? d, {int? near, String? dir}) {
  if (d == null) return S.t('clear');
  final n = near ?? nearOf(d);
  final nearTxt = n == 3 ? ', ${S.t('veryClose')}' : (n == 2 ? ', ${S.t('close')}' : '');
  final name = S.lang == Lang.fil ? (filLabels[d.label] ?? d.label) : d.label;
  return '${name[0].toUpperCase()}${name.substring(1)} ${S.t(dir ?? dirOf(d))}$nearTxt';
}

const filLabels = {
  'person': 'tao', 'car': 'kotse', 'motorcycle': 'motor', 'bus': 'bus', 'truck': 'trak', 'bicycle': 'bisikleta',
  'train': 'tren', 'chair': 'upuan', 'bench': 'bangko', 'couch': 'sopa', 'bed': 'kama', 'dining table': 'mesa',
  'dog': 'aso', 'cat': 'pusa', 'potted plant': 'halaman', 'fire hydrant': 'hydrant', 'stop sign': 'stop sign',
  'suitcase': 'maleta', 'toilet': 'inidoro', 'tv': 'TV', 'refrigerator': 'ref', 'traffic light': 'traffic light',
  'bottle': 'bote', 'cup': 'tasa', 'backpack': 'bag', 'umbrella': 'payong', 'cell phone': 'cellphone', 'book': 'libro',
};

class _SightScreenState extends State<SightScreen> {
  SoundWatcher? _sound;
  Timer? _hapticTimer;
  Timer? _holdTimer;
  bool _paused = false;
  bool _showBoxes = true;
  String _say = S.t('loading');
  _Target? _target;
  List<Det> _dets = [];
  double _fps = 0;
  String _lastKey = '';
  DateTime _lastSpeak = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastBuzz = DateTime.fromMillisecondsSinceEpoch(0);
  String? _soundBanner;

  @override
  void initState() {
    super.initState();
    _hapticTimer = Timer.periodic(const Duration(milliseconds: 100), (_) => _hapticTick());
    final p = AppState.I.profile;
    if (p == Profile.blind || p == Profile.deafblind) {
      _sound = SoundWatcher(onEvent: (e) {
        if (_paused || !e.urgent) return;
        _lastBuzz = DateTime.now().add(const Duration(milliseconds: 1500));
        Haptics.play(SoundInfo.pattern(e.category));
        Output.speak(SoundInfo.text(e.category));
        TestLog.I.log('Tunog (Lakad)', SoundInfo.text(e.category), label: e.label, score: e.score);
        if (mounted) setState(() => _soundBanner = e.category);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _soundBanner = null);
        });
      });
      _sound!.start();
    }
    Haptics.play(Haptics.start);
    Output.speak(S.t('ready'));
    _say = S.t('ready');
  }

  void _onDetections(List<Det> dets, double fps) {
    _Target? best;
    var bestScore = 0.0;
    for (final d in dets) {
      if (d.closeness < 0.04) continue;
      final pr = d.closeness * (d.isHazard ? 1.6 : 1);
      if (pr > bestScore) {
        bestScore = pr;
        best = _Target(d, dirOf(d), nearOf(d));
      }
    }
    final now = DateTime.now();
    final key = best?.key ?? 'none';
    if (best != null && key != _lastKey && now.difference(_lastSpeak).inMilliseconds > 2000) {
      Output.speak(describeDet(best.det, near: best.near, dir: best.dir));
      TestLog.I.log('Lakad', describeDet(best.det, near: best.near, dir: best.dir), label: best.det.label, score: best.det.score, latencyMs: Detector.I.lastMs);
      _lastSpeak = now;
    }
    if (key != 'none' || now.difference(_lastSpeak).inMilliseconds > 2000) _lastKey = key;
    setState(() {
      _target = best;
      _dets = dets;
      _fps = fps;
      _say = describeDet(best?.det, near: best?.near, dir: best?.dir);
    });
  }

  // Closer objects buzz more often; vehicles add a danger burst when close.
  void _hapticTick() {
    final t = _target;
    if (_paused || t == null) return;
    final now = DateTime.now();
    if (now.difference(t.at).inMilliseconds > 900) return;
    const gaps = [0, 2600, 1400, 750];
    if (now.difference(_lastBuzz).inMilliseconds < gaps[t.near]) return;
    _lastBuzz = now;
    final pattern = switch (t.dir) { 'left' => Haptics.left, 'right' => Haptics.right, _ => Haptics.center };
    Haptics.play((t.det.isHazard && t.near >= 2) || t.near == 3 ? [...Haptics.danger, 250, ...pattern] : pattern);
  }

  void _togglePause() {
    setState(() {
      _paused = !_paused;
      _say = _paused ? S.t('paused') : S.t('resumed');
    });
    Haptics.play(Haptics.pause);
    Output.speak(_say);
  }

  void _repeat() {
    final t = _target;
    if (t != null && DateTime.now().difference(t.at).inMilliseconds < 900) {
      Haptics.play(switch (t.dir) { 'left' => Haptics.left, 'right' => Haptics.right, _ => Haptics.center });
      Output.speak(describeDet(t.det, near: t.near, dir: t.dir));
    } else {
      Haptics.play(Haptics.clear);
      Output.speak(S.t('clear'));
    }
  }

  @override
  void dispose() {
    _hapticTimer?.cancel();
    _holdTimer?.cancel();
    _sound?.stop();
    Haptics.cancel();
    Output.stopSpeech();
    super.dispose();
  }

  // Visual helper: how close the nearest object is in each third of the view.
  Widget _zoneBar() {
    Color zoneColor(String zone) {
      final inZone = _dets.where((d) => dirOf(d) == zone).toList();
      if (inZone.isEmpty) return Colors.white24;
      final n = inZone.map(nearOf).reduce((a, b) => a > b ? a : b);
      final vehicle = inZone.any((d) => d.isHazard);
      if (n == 3 || (vehicle && n >= 2)) return GabayColors.danger;
      return n == 2 ? GabayColors.accent : GabayColors.accent.withAlpha(110);
    }

    Widget zone(String z, String label) => Expanded(
          child: Container(
            height: 54,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(color: zoneColor(z), borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Text(label, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        );
    return Semantics(
      excludeSemantics: true,
      child: Row(children: [
        zone('left', S.lang == Lang.fil ? 'Kaliwa' : 'Left'),
        zone('center', S.lang == Lang.fil ? 'Harap' : 'Ahead'),
        zone('right', S.lang == Lang.fil ? 'Kanan' : 'Right'),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _target;
    final closeness = t == null ? 0.0 : (t.det.closeness / 0.4).clamp(0.0, 1.0);
    final arrow = t == null ? Icons.check_circle_outline : switch (t.dir) { 'left' => Icons.arrow_back, 'right' => Icons.arrow_forward, _ => Icons.arrow_upward };
    return Scaffold(
      backgroundColor: Colors.black,
      body: Semantics(
        label: 'Lakad is running. Tap to pause, double tap to repeat, hold for SOS.',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _togglePause,
          onDoubleTap: _repeat,
          onLongPressStart: (_) => _holdTimer = Timer(const Duration(milliseconds: 1500), () => SosScreen.trigger(reason: 'Manual SOS')),
          onLongPressEnd: (_) => _holdTimer?.cancel(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              VisionCamera(onDetections: _onDetections, paused: _paused, showBoxes: _showBoxes, onError: (e) => setState(() => _say = e)),
              if (_soundBanner != null)
                Positioned(
                  top: 90,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: GabayColors.danger, borderRadius: BorderRadius.circular(16)),
                    child: Row(children: [
                      Icon(SoundInfo.icon(_soundBanner!), color: GabayColors.onDanger, size: 36),
                      const SizedBox(width: 12),
                      Expanded(child: Text(SoundInfo.text(_soundBanner!), style: TextStyle(color: GabayColors.onDanger, fontSize: 22, fontWeight: FontWeight.w800))),
                    ]),
                  ),
                ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        _pill('${_fps.toStringAsFixed(0)} fps · ${Detector.I.ready ? 'EfficientDet' : 'ML Kit'}', null),
                        const Spacer(),
                        _pill(_showBoxes ? 'Boxes on' : 'Boxes off', () => setState(() => _showBoxes = !_showBoxes)),
                        const SizedBox(width: 8),
                        _pill('Exit', () => Navigator.of(context).pop()),
                      ],
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
                  decoration: BoxDecoration(color: GabayColors.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(26))),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(arrow, size: 52, color: t?.det.isHazard == true ? GabayColors.danger : GabayColors.accent),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Semantics(
                              liveRegion: true,
                              child: Text(_say, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 1.1, color: _paused ? GabayColors.mute : GabayColors.ink)),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 14),
                        Text(S.lang == Lang.fil ? 'Gaano kalapit' : 'How close', style: TextStyle(color: GabayColors.mute, fontSize: 15)),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: closeness,
                            minHeight: 18,
                            backgroundColor: GabayColors.card,
                            color: closeness > 0.7 ? GabayColors.danger : GabayColors.accent,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _zoneBar(),
                        const SizedBox(height: 10),
                        Text('Tap: pause · Double-tap: repeat · Hold: SOS', style: TextStyle(color: GabayColors.mute, fontSize: 14)),
                        const VerdictBar(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, VoidCallback? onTap) => Material(
        color: Colors.black54,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 15)),
          ),
        ),
      );
}
