import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

import '../core/app_state.dart';
import '../core/haptics.dart';
import '../core/l10n.dart';
import '../core/output.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../engines/detector.dart';
import '../services/test_log.dart';
import '../widgets/back_pill.dart';
import '../widgets/lang_toggle.dart';
import '../widgets/verdict_bar.dart';
import 'sight_screen.dart' show dirOf, nearOf, filLabels;

/// Ilarawan: describes what is in front of the user.
/// Works offline on the phone by default (no account, no key, nothing uploaded):
///  - ML Kit image labeling: what kind of place / scene it is
///  - EfficientDet: which objects, where (left / ahead / right) and how close
///  - ML Kit text recognition: any sign or label in view
///  - brightness: whether it is dark
/// An optional online "More detail" (Google Gemini) appears only if a key was added in Settings.
class SceneScreen extends StatefulWidget {
  const SceneScreen({super.key});

  @override
  State<SceneScreen> createState() => _SceneScreenState();
}

class _SceneScreenState extends State<SceneScreen> {
  CameraController? _cam;
  final _labeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.62));
  final _ocr = TextRecognizer(script: TextRecognitionScript.latin);
  bool _busy = false;
  String _text = '';
  String? _lastPhoto;
  double _size = 26;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (!(await Permission.camera.request()).isGranted) return;
    await Detector.I.load();
    final cams = await availableCameras();
    if (cams.isEmpty) return;
    final back = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cams.first);
    final cam = CameraController(back, ResolutionPreset.veryHigh, enableAudio: false);
    await cam.initialize();
    try {
      await cam.setFocusMode(FocusMode.auto);
      await cam.setFlashMode(FlashMode.off);
    } catch (_) {}
    if (!mounted) {
      await cam.dispose();
      return;
    }
    setState(() => _cam = cam);
    Output.speak(S.lang == Lang.fil ? 'Ilarawan. Itutok ang telepono at pindutin ang malaking button.' : 'Describe. Point the phone and press the big button.', force: true);
  }

  Future<void> _focusAt(Offset p) async {
    try {
      await _cam?.setFocusPoint(p);
      await _cam?.setExposurePoint(p);
      Haptics.play(const [20]);
    } catch (_) {}
  }

  /// Decodes the photo straight to the model size and returns RGBA pixels + average brightness.
  Future<(Uint8List, double)?> _pixels(String path, int w, int h) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: w, targetHeight: h);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    final rgba = data.buffer.asUint8List();
    var sum = 0;
    for (var i = 0; i < rgba.length; i += 16) {
      sum += (rgba[i] * 299 + rgba[i + 1] * 587 + rgba[i + 2] * 114) ~/ 1000;
    }
    return (rgba, sum / (rgba.length / 16));
  }

  String _name(String label, int count) {
    final fil = S.lang == Lang.fil;
    final base = fil ? (filLabels[label] ?? label) : label;
    if (count == 1) return fil ? 'isang $base' : (RegExp('^[aeiou]').hasMatch(base) ? 'an $base' : 'a $base');
    if (fil) return '$count na $base';
    if (base == 'person') return '$count people';
    return base.endsWith('s') ? '$count $base' : '$count ${base}s';
  }

  String _where(String dir) => S.t(dir);

  Future<void> _describe() async {
    final cam = _cam;
    if (cam == null || _busy) return;
    setState(() {
      _busy = true;
      _text = S.lang == Lang.fil ? 'Tinitingnan…' : 'Looking…';
    });
    Haptics.play(Haptics.start);
    final sw = Stopwatch()..start();
    final fil = S.lang == Lang.fil;
    try {
      final shot = await cam.takePicture();
      _lastPhoto = shot.path;
      final input = InputImage.fromFilePath(shot.path);
      final parts = <String>[];

      // 1) What kind of scene.
      List<ImageLabel> labels = const [];
      try {
        labels = await _labeler.processImage(input);
      } catch (_) {}
      final scene = labels.where((l) => !_skipLabels.contains(l.label.toLowerCase())).take(3).map((l) => fil ? (_filScene[l.label.toLowerCase()] ?? l.label.toLowerCase()) : l.label.toLowerCase()).toList();
      if (scene.isNotEmpty) parts.add(fil ? 'Mukhang: ${scene.join(', ')}.' : 'This looks like: ${scene.join(', ')}.');

      // 2) Objects, grouped by name, nearest first, with direction.
      double? brightness;
      if (Detector.I.ready) {
        final px = await _pixels(shot.path, Detector.I.inW, Detector.I.inH);
        if (px != null) {
          brightness = px.$2;
          final dets = await Detector.I.detectInput(rgbaToModelInput(px.$1, Detector.I.inW, Detector.I.inH, Detector.I.asFloat));
          final groups = <String, List<Det>>{};
          for (final d in dets) {
            groups.putIfAbsent(d.label, () => []).add(d);
          }
          final sorted = groups.entries.toList()
            ..sort((a, b) => b.value.map((d) => d.closeness).reduce((x, y) => x > y ? x : y).compareTo(a.value.map((d) => d.closeness).reduce((x, y) => x > y ? x : y)));
          final said = <String>[];
          for (final g in sorted.take(4)) {
            final nearest = g.value.reduce((a, b) => a.closeness > b.closeness ? a : b);
            final n = nearOf(nearest);
            final close = n == 3 ? ', ${S.t('veryClose')}' : (n == 2 ? ', ${S.t('close')}' : '');
            said.add('${_name(g.key, g.value.length)} ${_where(dirOf(nearest))}$close');
          }
          if (said.isNotEmpty) {
            parts.add('${fil ? 'May' : 'I see'} ${said.join('; ')}.');
          } else {
            parts.add(fil ? 'Walang malinaw na bagay sa harap.' : 'No clear objects in front.');
          }
        }
      }

      // 3) Any sign or label.
      try {
        final t = (await _ocr.processImage(input)).text.replaceAll('\n', ' ').trim();
        if (t.length >= 3) {
          final short = t.length > 90 ? '${t.substring(0, 90)}…' : t;
          parts.add(fil ? 'May nakasulat: $short' : 'There is text: $short');
        }
      } catch (_) {}

      // 4) Light.
      if (brightness != null && brightness < 45) parts.add(fil ? 'Madilim ang paligid.' : 'It is dark here.');

      final text = parts.isEmpty ? (fil ? 'Hindi ko malaman. Subukan ulit.' : 'I could not tell. Try again.') : parts.join(' ');
      setState(() => _text = text);
      Output.speak(text, force: true);
      TestLog.I.log('Ilarawan', text, latencyMs: sw.elapsedMilliseconds);
    } catch (e) {
      setState(() => _text = '${L('Could not take the photo. Try again.')} ($e)');
      Output.speak(L('Could not take the photo. Try again.'), force: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Optional: richer sentences from Google Gemini (only if the user added a key).
  Future<void> _moreDetail() async {
    final key = AppState.I.geminiKey;
    final path = _lastPhoto;
    if (key.isEmpty || path == null || _busy) return;
    setState(() => _busy = true);
    Haptics.play(Haptics.start);
    try {
      final b64 = base64Encode(await File(path).readAsBytes());
      final prompt = S.lang == Lang.fil
          ? 'Ilarawan ang larawang ito para sa isang bulag sa 2 hanggang 3 maikling pangungusap sa Filipino. Unahin ang mga harang o panganib at kung nasaan sila.'
          : 'Describe this photo for a blind person in 2 to 3 short sentences. Mention obstacles or dangers first and where they are.';
      final res = await http
          .post(Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/${AppState.I.geminiModel}:generateContent'),
              headers: {'Content-Type': 'application/json', 'x-goog-api-key': key},
              body: jsonEncode({
                'contents': [
                  {
                    'parts': [
                      {'text': prompt},
                      {'inline_data': {'mime_type': 'image/jpeg', 'data': b64}},
                    ]
                  }
                ]
              }))
          .timeout(const Duration(seconds: 25));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        final t = ((j['candidates'] as List).first['content']['parts'] as List).map((p) => p['text'] ?? '').join(' ').trim();
        setState(() => _text = t);
        Output.speak(t, force: true);
      } else {
        Output.speak(L('Online description is not available right now.'), force: true);
      }
    } catch (_) {
      Output.speak(L('Online description is not available right now.'), force: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _cam?.dispose();
    _labeler.close();
    _ocr.close();
    Output.stopSpeech();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cam = _cam;
    return ListenableBuilder(listenable: AppState.I, builder: (context, _) => Scaffold(
      appBar: AppBar(leading: const BackPill(), leadingWidth: 132, actions: const [LangToggle()], title: Text(S.lang == Lang.fil ? 'Ilarawan' : 'Describe')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: cam != null && cam.value.isInitialized
                ? LayoutBuilder(builder: (context, box) => GestureDetector(
                      onTapDown: (d) => _focusAt(Offset(d.localPosition.dx / box.maxWidth, d.localPosition.dy / box.maxHeight)),
                      child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: cam.value.previewSize!.height, height: cam.value.previewSize!.width, child: CameraPreview(cam))),
                    ))
                : const ColoredBox(color: Colors.black, child: Center(child: CircularProgressIndicator())),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _busy ? null : _describe,
          icon: const Icon(Icons.auto_awesome, size: 30),
          label: Text(S.lang == Lang.fil ? 'Ilarawan ang harap' : 'Describe what\'s in front'),
        ),
        const SizedBox(height: 8),
        Text(L('Works offline. Nothing leaves your phone.'), style: TextStyle(color: GabayColors.mute, fontSize: 15)),
        if (_text.isNotEmpty) ...[
          Row(children: [
            Icon(Icons.text_decrease, color: GabayColors.mute),
            Expanded(child: Slider(value: _size, min: 18, max: 52, divisions: 17, onChanged: (v) => setState(() => _size = v))),
            Icon(Icons.text_increase, color: GabayColors.mute),
          ]),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: GabayColors.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: GabayColors.line, width: 2)),
            child: Semantics(liveRegion: true, child: Text(_text, style: TextStyle(fontSize: _size, height: 1.35, color: GabayColors.ink, fontWeight: FontWeight.w600))),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: () => Output.speak(_text, force: true), icon: const Icon(Icons.volume_up), label: Text(L('Read again'))),
          if (AppState.I.geminiKey.isNotEmpty && _lastPhoto != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: _busy ? null : _moreDetail, icon: const Icon(Icons.cloud_outlined), label: Text(L('More detail (online)'))),
            Text(L('Sends this photo to Google.'), style: TextStyle(color: GabayColors.mute, fontSize: 14)),
          ],
          const VerdictBar(),
        ],
      ]),
    ));
  }
}

// Labels that don't help a blind user picture the place.
const _skipLabels = {'font', 'pattern', 'metal', 'rectangle', 'circle', 'event', 'fun', 'smile', 'flesh', 'skin', 'cool', 'jacket', 'sleeve'};

const _filScene = {
  'room': 'kuwarto', 'building': 'gusali', 'road': 'kalsada', 'street': 'kalye', 'car': 'kotse', 'vehicle': 'sasakyan',
  'tree': 'puno', 'plant': 'halaman', 'sky': 'langit', 'food': 'pagkain', 'table': 'mesa', 'chair': 'upuan', 'door': 'pinto',
  'window': 'bintana', 'stairs': 'hagdan', 'kitchen': 'kusina', 'bathroom': 'banyo', 'bedroom': 'kuwarto', 'office': 'opisina',
  'shelf': 'istante', 'crowd': 'maraming tao', 'person': 'tao', 'dog': 'aso', 'cat': 'pusa', 'water': 'tubig', 'flower': 'bulaklak',
  'grass': 'damo', 'paper': 'papel', 'money': 'pera', 'bag': 'bag', 'shoe': 'sapatos', 'computer': 'computer', 'screen': 'screen',
  'bicycle': 'bisikleta', 'motorcycle': 'motor', 'wheel': 'gulong', 'river': 'ilog', 'beach': 'dagat', 'market': 'palengke',
  'interior design': 'loob ng bahay', 'house': 'bahay', 'night': 'gabi',
};
