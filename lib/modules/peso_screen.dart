import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../core/haptics.dart';
import '../core/output.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../engines/classifier.dart';
import '../engines/detector.dart';
import '../services/test_log.dart';
import '../widgets/verdict_bar.dart';
import 'camera_frames.dart';
import '../core/l10n.dart';
import '../core/app_state.dart';
import '../widgets/lang_toggle.dart';

/// Pera: identifies Philippine peso bills with a model you train (training/ notebook).
/// Each bill has its own vibration count so deafblind users can feel the amount.
class PesoScreen extends StatefulWidget {
  const PesoScreen({super.key});

  @override
  State<PesoScreen> createState() => _PesoScreenState();
}

class _PesoScreenState extends State<PesoScreen> {
  bool _loaded = false;
  String? _last, _candidate;
  int _streak = 0;
  double _score = 0;

  static const pulses = {'20': 1, '50': 2, '100': 3, '200': 4, '500': 5, '1000': 6};

  @override
  void initState() {
    super.initState();
    ImageClassifier.peso.load().then((_) => setState(() => _loaded = true));
  }

  Future<void> _onFrame(CameraImage img, int rotation) async {
    final c = ImageClassifier.peso;
    if (!c.ready || img.planes.length != 1) return;
    final plane = img.planes.first;
    final r = await c.classify(FrameData(plane.bytes, img.width, img.height, plane.bytesPerRow, rotation, c.inW, c.inH, Platform.isAndroid, c.asFloat));
    if (r == null || !mounted) return;
    final value = r.key.replaceAll(RegExp(r'[^0-9]'), '');
    // Must be confident in 3 frames in a row before announcing.
    if (r.value >= 0.8 && value.isNotEmpty) {
      _streak = value == _candidate ? _streak + 1 : 1;
      _candidate = value;
    } else {
      _streak = 0;
      _candidate = null;
    }
    setState(() => _score = r.value);
    if (_streak >= 3 && value != _last) {
      _last = value;
      final n = pulses[value] ?? 1;
      Haptics.play(Haptics.pulses(n, 250, 250));
      final msg = S.lang == Lang.fil ? '$value piso' : '$value pesos';
      Output.speak(msg, force: true);
      TestLog.I.log('Pera', msg, label: r.key, score: r.value);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = ImageClassifier.peso.ready;
    return ListenableBuilder(listenable: AppState.I, builder: (context, _) => Scaffold(
      appBar: AppBar(actions: const [LangToggle()], title: Text(S.lang == Lang.fil ? 'Pera' : 'Peso reader')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : !ready
              ? ListView(padding: const EdgeInsets.all(20), children: [
                  Icon(Icons.payments, size: 80, color: GabayColors.accent),
                  const SizedBox(height: 12),
                  Text(L('Peso model not installed yet'), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: GabayColors.ink)),
                  const SizedBox(height: 10),
                  Text(
                      L('Train it with the notebook in the training/ folder of the GitHub repo: take about 100 photos of each bill (front and back, different lighting), train on Google Colab, then add peso.tflite and peso_labels.txt to assets/. The next build includes it automatically.'),
                      style: TextStyle(fontSize: 18, color: GabayColors.mute, height: 1.4)),
                ])
              : Column(children: [
                  Expanded(child: FrameCamera(onFrame: _onFrame)),
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: GabayColors.bg,
                    child: SafeArea(
                      top: false,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        // Visual helper: big amount and the vibration count as dots.
                        Semantics(
                          liveRegion: true,
                          child: Text(_last == null ? (S.lang == Lang.fil ? 'Itutok sa perang papel' : 'Point at a bill') : '₱$_last',
                              style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: GabayColors.accent)),
                        ),
                        if (_last != null)
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            for (var i = 0; i < (pulses[_last] ?? 1); i++)
                              Container(margin: const EdgeInsets.all(5), width: 22, height: 22, decoration: BoxDecoration(color: GabayColors.accent, shape: BoxShape.circle)),
                          ]),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: _score, minHeight: 10, backgroundColor: GabayColors.card, color: GabayColors.accent),
                        const SizedBox(height: 6),
                        Text(L('20 = 1 buzz · 50 = 2 · 100 = 3 · 200 = 4 · 500 = 5 · 1000 = 6'), style: TextStyle(color: GabayColors.mute, fontSize: 14)),
                        const VerdictBar(),
                      ]),
                    ),
                  ),
                ]),
    ));
  }
}
