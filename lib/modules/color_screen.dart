import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../core/haptics.dart';
import '../core/output.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../services/test_log.dart';
import '../widgets/verdict_bar.dart';
import 'camera_frames.dart';
import '../core/app_state.dart';
import '../widgets/lang_toggle.dart';
import '../widgets/back_pill.dart';

/// Kulay: says the color at the center of the camera and how bright the room is.
class ColorScreen extends StatefulWidget {
  const ColorScreen({super.key});

  @override
  State<ColorScreen> createState() => _ColorScreenState();
}

class _ColorScreenState extends State<ColorScreen> {
  Color _color = Colors.black;
  String _name = '…';
  double _light = 0;
  String _lastSpoken = '';
  DateTime _lastChange = DateTime.now();

  Future<void> _onFrame(CameraImage img, int rotation) async {
    final plane = img.planes.first;
    final b = plane.bytes, stride = plane.bytesPerRow, w = img.width, h = img.height;
    // Average color of the center 15% and overall brightness (sampled).
    var r = 0.0, g = 0.0, bl = 0.0, n = 0, ySum = 0.0, yN = 0;
    final x0 = (w * 0.425).round(), x1 = (w * 0.575).round(), y0 = (h * 0.425).round(), y1 = (h * 0.575).round();
    final android = Platform.isAndroid;
    for (var y = 0; y < h; y += 8) {
      for (var x = 0; x < w; x += 8) {
        if (android) {
          ySum += b[y * stride + x];
        } else {
          final i = y * stride + x * 4;
          ySum += 0.299 * b[i + 2] + 0.587 * b[i + 1] + 0.114 * b[i];
        }
        yN++;
      }
    }
    for (var y = y0; y < y1; y += 2) {
      for (var x = x0; x < x1; x += 2) {
        double rr, gg, bb;
        if (android) {
          final yy = b[y * stride + x].toDouble();
          final uv = stride * h + (y >> 1) * stride + (x & ~1);
          final v = b[uv] - 128.0, u = b[uv + 1] - 128.0;
          rr = yy + 1.402 * v;
          gg = yy - 0.344 * u - 0.714 * v;
          bb = yy + 1.772 * u;
        } else {
          final i = y * stride + x * 4;
          bb = b[i].toDouble();
          gg = b[i + 1].toDouble();
          rr = b[i + 2].toDouble();
        }
        r += rr.clamp(0, 255);
        g += gg.clamp(0, 255);
        bl += bb.clamp(0, 255);
        n++;
      }
    }
    if (n == 0) return;
    final c = Color.fromARGB(255, (r / n).round(), (g / n).round(), (bl / n).round());
    final name = colorName(c);
    if (!mounted) return;
    setState(() {
      _color = c;
      _light = (ySum / yN / 255).clamp(0.0, 1.0);
      if (name != _name) _lastChange = DateTime.now();
      _name = name;
    });
    // Speak when the color has been steady for 1 second.
    if (name != _lastSpoken && DateTime.now().difference(_lastChange).inMilliseconds > 1000) {
      _lastSpoken = name;
      Output.speak(name);
      Haptics.play(const [40]);
      TestLog.I.log('Kulay', name);
    }
  }

  static String colorName(Color c) {
    final hsv = HSVColor.fromColor(c);
    final fil = S.lang == Lang.fil;
    if (hsv.value < 0.18) return fil ? 'Itim' : 'Black';
    if (hsv.saturation < 0.15) return hsv.value > 0.8 ? (fil ? 'Puti' : 'White') : (fil ? 'Abo' : 'Gray');
    final hue = hsv.hue;
    if (hue >= 10 && hue < 45 && hsv.value < 0.6) return fil ? 'Kayumanggi' : 'Brown';
    if (hue < 15 || hue >= 345) return fil ? 'Pula' : 'Red';
    if (hue < 40) return fil ? 'Kahel' : 'Orange';
    if (hue < 65) return fil ? 'Dilaw' : 'Yellow';
    if (hue < 165) return fil ? 'Berde' : 'Green';
    if (hue < 200) return fil ? 'Mapusyaw na asul' : 'Light blue';
    if (hue < 255) return fil ? 'Asul' : 'Blue';
    if (hue < 290) return fil ? 'Lila' : 'Purple';
    return fil ? 'Rosas' : 'Pink';
  }

  String get _lightText {
    final fil = S.lang == Lang.fil;
    if (_light < 0.15) return fil ? 'Madilim' : 'Dark';
    if (_light < 0.35) return fil ? 'Malamlam' : 'Dim';
    return fil ? 'Maliwanag' : 'Bright';
  }

  @override
  void dispose() {
    Output.stopSpeech();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onColor = _color.computeLuminance() > 0.45 ? Colors.black : Colors.white;
    return ListenableBuilder(listenable: AppState.I, builder: (context, _) => Scaffold(
      appBar: AppBar(leading: const BackPill(), leadingWidth: 132, actions: const [LangToggle()], title: Text(S.lang == Lang.fil ? 'Kulay at Liwanag' : 'Color and Light')),
      body: Column(
        children: [
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              FrameCamera(onFrame: _onFrame),
              // Visual helper: the exact spot being measured.
              Center(child: Container(width: 70, height: 70, decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 4), borderRadius: BorderRadius.circular(12)))),
            ]),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: GabayColors.bg,
            child: SafeArea(
              top: false,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Visual helper: a big swatch of the detected color with its name.
                Container(
                  height: 96,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: _color, borderRadius: BorderRadius.circular(18), border: Border.all(color: GabayColors.line, width: 2)),
                  child: Semantics(liveRegion: true, child: Text(_name, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: onColor))),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Icon(_light < 0.15 ? Icons.dark_mode : Icons.light_mode, color: GabayColors.accent, size: 32),
                  const SizedBox(width: 10),
                  Text(_lightText, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: GabayColors.ink)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(value: _light, minHeight: 18, backgroundColor: GabayColors.card, color: GabayColors.accent),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Output.speak('$_name. $_lightText', force: true),
                  icon: const Icon(Icons.volume_up),
                  label: Text(S.lang == Lang.fil ? 'Sabihin ulit' : 'Say again'),
                ),
                const VerdictBar(),
              ]),
            ),
          ),
        ],
      ),
    ));
  }
}

