import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

import '../core/app_state.dart';
import '../core/haptics.dart';
import '../core/output.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../services/test_log.dart';
import '../widgets/verdict_bar.dart';
import '../core/l10n.dart';
import '../widgets/lang_toggle.dart';

/// Ilarawan: describes the whole scene in sentences using an online vision AI (Google Gemini).
/// Needs internet and a free API key in Settings. The photo is sent to Google.
class SceneScreen extends StatefulWidget {
  const SceneScreen({super.key});

  @override
  State<SceneScreen> createState() => _SceneScreenState();
}

class _SceneScreenState extends State<SceneScreen> {
  CameraController? _cam;
  bool _busy = false;
  String _text = '';
  double _size = 26;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (!(await Permission.camera.request()).isGranted) return;
    final cams = await availableCameras();
    if (cams.isEmpty) return;
    final back = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cams.first);
    final cam = CameraController(back, ResolutionPreset.medium, enableAudio: false);
    await cam.initialize();
    if (!mounted) {
      await cam.dispose();
      return;
    }
    setState(() => _cam = cam);
  }

  Future<void> _describe() async {
    final key = AppState.I.geminiKey;
    if (key.isEmpty) {
      setState(() => _text = L('Add a Gemini API key in Settings → Scene description to use this module.'));
      Output.speak(_text, force: true);
      return;
    }
    if (_cam == null || _busy) return;
    setState(() {
      _busy = true;
      _text = S.lang == Lang.fil ? 'Inilalarawan…' : 'Describing…';
    });
    Haptics.play(Haptics.start);
    final sw = Stopwatch()..start();
    try {
      final shot = await _cam!.takePicture();
      final b64 = base64Encode(await File(shot.path).readAsBytes());
      final prompt = S.lang == Lang.fil
          ? 'Ilarawan ang larawang ito para sa isang bulag sa 2 hanggang 3 maikling pangungusap sa Filipino. Unahin ang mga harang o panganib at kung nasaan sila (kaliwa, harap, kanan, gaano kalapit). Basahin ang mahahalagang karatula.'
          : 'Describe this photo for a blind person in 2 to 3 short sentences. Mention obstacles or dangers first and where they are (left, ahead, right, how close). Read any important signs.';
      final uri = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/${AppState.I.geminiModel}:generateContent');
      final res = await http
          .post(uri,
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
      String text;
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body);
        text = ((j['candidates'] as List).first['content']['parts'] as List).map((p) => p['text'] ?? '').join(' ').trim();
      } else {
        text = 'The description service answered with an error (${res.statusCode}). Check the API key and model name in Settings.';
      }
      setState(() => _text = text);
      Output.speak(text, force: true);
      TestLog.I.log('Ilarawan', text, latencyMs: sw.elapsedMilliseconds);
    } catch (e) {
      setState(() => _text = L('Could not describe the scene. Check your internet connection.'));
      Output.speak(_text, force: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _cam?.dispose();
    Output.stopSpeech();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cam = _cam;
    return ListenableBuilder(listenable: AppState.I, builder: (context, _) => Scaffold(
      appBar: AppBar(actions: const [LangToggle()], title: Text(S.lang == Lang.fil ? 'Ilarawan' : 'Describe scene')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: cam != null && cam.value.isInitialized
                ? FittedBox(fit: BoxFit.cover, child: SizedBox(width: cam.value.previewSize!.height, height: cam.value.previewSize!.width, child: CameraPreview(cam)))
                : const ColoredBox(color: Colors.black, child: Center(child: CircularProgressIndicator())),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _busy ? null : _describe,
          icon: const Icon(Icons.auto_awesome, size: 30),
          label: Text(S.lang == Lang.fil ? 'Ilarawan ang paligid' : 'Describe what\'s in front'),
        ),
        const SizedBox(height: 8),
        Text(L('Needs internet. The photo is sent to Google to be described.'), style: TextStyle(color: GabayColors.mute, fontSize: 14)),
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
          const VerdictBar(),
        ],
      ]),
    ));
  }
}
