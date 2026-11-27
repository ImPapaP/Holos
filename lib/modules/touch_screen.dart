import 'package:flutter/material.dart';

import '../core/haptics.dart';
import '../core/output.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../engines/detector.dart';
import '../engines/vision_camera.dart';
import 'sight_screen.dart' show describeDet;

/// Touch-explore: slide a finger across the screen to feel where objects are.
/// Entering an object gives its own vibration and says its name; staying on it ticks
/// softly, stronger when the object is closer. "Hold scene" freezes the view to explore it.
class TouchScreen extends StatefulWidget {
  const TouchScreen({super.key});

  @override
  State<TouchScreen> createState() => _TouchScreenState();
}

class _TouchScreenState extends State<TouchScreen> {
  final _camKey = GlobalKey<VisionCameraState>();
  List<Det> _dets = [];
  bool _frozen = false;
  Det? _under;
  Offset? _finger;
  DateTime _lastTick = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    Output.speak(S.lang == Lang.fil ? 'Touch explore. Idaan ang daliri sa screen.' : 'Touch explore. Slide your finger across the screen.');
  }

  void _onDetections(List<Det> dets, double fps) {
    if (_frozen) return;
    setState(() => _dets = dets);
  }

  void _feel(Offset pos, Size size) {
    final aspect = _camKey.currentState?.imageAspect ?? 3 / 4;
    Det? hit;
    for (final d in _dets) {
      if (normToScreen(d.box, size, aspect).contains(pos)) {
        if (hit == null || d.closeness > hit.closeness) hit = d;
      }
    }
    final prev = _under;
    final entered = hit != null && (prev == null || prev.label != hit.label || prev.box != hit.box);
    if (hit != null && entered) {
      Haptics.play(hit.isVehicle ? Haptics.danger : (hit.label == 'person' ? [80, 80, 80] : [160]));
      Output.speak(describeDet(hit));
    } else if (hit != null && DateTime.now().difference(_lastTick).inMilliseconds > 280) {
      _lastTick = DateTime.now();
      Haptics.pulse(25, (60 + 195 * (hit.closeness / 0.4).clamp(0.0, 1.0)).round());
    }
    setState(() {
      _under = hit;
      _finger = pos;
    });
  }

  @override
  void dispose() {
    Haptics.cancel();
    Output.stopSpeech();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aspect = _camKey.currentState?.imageAspect ?? 3 / 4;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              final size = Size(box.maxWidth, box.maxHeight);
              return Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) => _feel(e.localPosition, size),
                onPointerMove: (e) => _feel(e.localPosition, size),
                onPointerUp: (_) => setState(() {
                  _under = null;
                  _finger = null;
                }),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    VisionCamera(key: _camKey, onDetections: _onDetections, paused: _frozen, showBoxes: false),
                    // Visual helper: objects as filled shapes, the one under your finger highlighted.
                    IgnorePointer(child: CustomPaint(painter: DetPainter(_dets, aspect, highlight: _under, fill: true))),
                    if (_finger != null)
                      Positioned(
                        left: _finger!.dx - 40,
                        top: _finger!.dy - 40,
                        child: IgnorePointer(
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: GabayColors.accent, width: 5)),
                          ),
                        ),
                      ),
                    if (_frozen)
                      Positioned(
                        top: 40,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(color: GabayColors.accent, borderRadius: BorderRadius.circular(99)),
                          child: Text(S.lang == Lang.fil ? 'Naka-hold ang eksena' : 'Scene held',
                              style: TextStyle(color: GabayColors.onAccent, fontWeight: FontWeight.w800, fontSize: 16)),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          Container(
            color: GabayColors.bg,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _under == null ? (S.lang == Lang.fil ? '${_dets.length} bagay sa eksena' : '${_dets.length} objects in view') : describeDet(_under),
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: GabayColors.ink),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          setState(() => _frozen = !_frozen);
                          Haptics.play(Haptics.pause);
                          Output.speak(_frozen ? (S.lang == Lang.fil ? 'Naka-hold' : 'Scene held') : (S.lang == Lang.fil ? 'Live' : 'Live view'));
                        },
                        child: Text(_frozen ? 'Live view' : 'Hold scene'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 110,
                      child: OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Exit')),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
