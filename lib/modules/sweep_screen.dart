import 'dart:async';

import 'package:flutter/material.dart';

import '../core/haptics.dart';
import '../core/output.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../engines/detector.dart';
import '../engines/vision_camera.dart';
import 'sight_screen.dart' show describeDet, nearOf;
import 'sos_screen.dart';
import '../services/test_log.dart';
import '../widgets/verdict_bar.dart';

/// Sweep: point the phone like a flashlight. It buzzes only when the center of the
/// camera faces an object; closer = stronger and faster. Your hand position tells the direction.
class SweepScreen extends StatefulWidget {
  const SweepScreen({super.key});

  @override
  State<SweepScreen> createState() => _SweepScreenState();
}

class _SweepScreenState extends State<SweepScreen> {
  Det? _hit;
  DateTime _hitAt = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _tick;
  Timer? _holdTimer;
  DateTime _lastPulse = DateTime.fromMillisecondsSinceEpoch(0);
  String _lastSpoken = '';

  static const _band = (0.38, 0.62); // center band of the view

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 50), (_) => _pulse());
    Output.speak(S.lang == Lang.fil ? 'Sweep. Igalaw ang telepono pakaliwa at pakanan.' : 'Sweep. Move the phone slowly left and right.');
  }

  void _onDetections(List<Det> dets, double fps) {
    Det? best;
    for (final d in dets) {
      final overlaps = d.box.right > _band.$1 && d.box.left < _band.$2;
      if (!overlaps) continue;
      if (best == null || d.closeness > best.closeness) best = d;
    }
    if (best != null) {
      _hitAt = DateTime.now();
      final key = '${best.label}${nearOf(best)}';
      if (key != _lastSpoken) {
        _lastSpoken = key;
        Output.speak(describeDet(best, dir: 'center'));
        TestLog.I.log('Sweep', describeDet(best, dir: 'center'), label: best.label, score: best.score, latencyMs: Detector.I.lastMs);
      }
    } else {
      _lastSpoken = '';
    }
    setState(() => _hit = best);
  }

  // Pulse rate and strength follow how close the object in the beam is.
  void _pulse() {
    final h = _hit;
    if (h == null || DateTime.now().difference(_hitAt).inMilliseconds > 600) return;
    final c = (h.closeness / 0.4).clamp(0.0, 1.0);
    final gap = (700 - 560 * c).round(); // 700 ms far -> 140 ms very close
    if (DateTime.now().difference(_lastPulse).inMilliseconds < gap) return;
    _lastPulse = DateTime.now();
    Haptics.pulse(h.isHazard ? 90 : 45, (60 + 195 * c).round());
  }

  @override
  void dispose() {
    _tick?.cancel();
    _holdTimer?.cancel();
    Haptics.cancel();
    Output.stopSpeech();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = _hit;
    final c = h == null ? 0.0 : (h.closeness / 0.4).clamp(0.0, 1.0);
    final beamColor = h == null ? Colors.white54 : (h.isHazard || c > 0.7 ? GabayColors.danger : GabayColors.accent);
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: (_) => _holdTimer = Timer(const Duration(milliseconds: 1500), () => SosScreen.trigger(reason: 'Manual SOS')),
        onLongPressEnd: (_) => _holdTimer?.cancel(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            VisionCamera(onDetections: _onDetections),
            // Visual helper: the "beam" the phone is scanning.
            LayoutBuilder(builder: (context, box) {
              final w = box.maxWidth;
              return Stack(children: [
                Positioned(
                  left: w * _band.$1,
                  width: w * (_band.$2 - _band.$1),
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color: beamColor.withAlpha(h == null ? 25 : 60),
                        border: Border.symmetric(vertical: BorderSide(color: beamColor, width: 4)),
                      ),
                    ),
                  ),
                ),
                Center(child: IgnorePointer(child: Icon(Icons.add, size: 90, color: beamColor))),
              ]);
            }),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(minimumSize: const Size(96, 52)),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Exit'),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                decoration: BoxDecoration(color: GabayColors.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(26))),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        liveRegion: true,
                        child: Text(h == null ? S.t('sweep_clear') : describeDet(h, dir: 'center'),
                            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: GabayColors.ink)),
                      ),
                      const SizedBox(height: 12),
                      Text(S.lang == Lang.fil ? 'Lakas ng vibration' : 'Vibration strength', style: TextStyle(color: GabayColors.mute, fontSize: 15)),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(value: c, minHeight: 22, backgroundColor: GabayColors.card, color: beamColor),
                      ),
                      const SizedBox(height: 10),
                      Text(S.lang == Lang.fil ? 'Igalaw ang telepono nang dahan-dahan. Hold: SOS' : 'Sweep slowly, like a flashlight. Hold: SOS',
                          style: TextStyle(color: GabayColors.mute, fontSize: 14)),
                      const VerdictBar(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
