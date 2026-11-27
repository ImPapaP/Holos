import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/haptics.dart';
import '../core/output.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../services/test_log.dart';
import '../widgets/verdict_bar.dart';
import '../core/l10n.dart';
import '../core/app_state.dart';
import '../widgets/lang_toggle.dart';
import '../widgets/back_pill.dart';
import 'package:flutter/services.dart';

/// Basa (read): take a photo of a sign, label, medicine box or document;
/// Gabay finds the text (ML Kit, on the phone) and reads it aloud in large print.
class ReadScreen extends StatefulWidget {
  const ReadScreen({super.key});

  @override
  State<ReadScreen> createState() => _ReadScreenState();
}

class _ReadScreenState extends State<ReadScreen> {
  CameraController? _cam;
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  bool _busy = false;
  String? _text;
  String? _photo;
  Size? _photoSize;
  List<Rect> _boxes = [];
  double _fontSize = 28;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (!(await Permission.camera.request()).isGranted) {
      setState(() => _status = L('Camera permission denied'));
      return;
    }
    final cams = await availableCameras();
    if (cams.isEmpty) return;
    final back = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cams.first);
    // veryHigh (1080p) keeps small print sharp; JPEG avoids devices that fail on other formats.
    final cam = CameraController(back, ResolutionPreset.veryHigh, enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
    try {
      await cam.initialize();
    } catch (e) {
      if (mounted) setState(() => _status = L('Camera could not start'));
      return;
    }
    try {
      await cam.setFocusMode(FocusMode.auto);
      await cam.setFlashMode(FlashMode.off);
    } catch (_) {}
    if (!mounted) {
      await cam.dispose();
      return;
    }
    setState(() => _cam = cam);
    Output.speak(S.lang == Lang.fil ? 'Basa. Itutok sa teksto at pindutin ang Basahin.' : 'Read. Point at the text and press Read.', force: true);
  }

  Future<void> _read() async {
    final cam = _cam;
    if (cam == null || _busy) return;
    setState(() {
      _busy = true;
      _status = S.t('reading');
    });
    Haptics.play(Haptics.start);
    try {
      // Focus on the middle first so the text is sharp.
      try {
        await cam.setFocusPoint(const Offset(0.5, 0.5));
        await Future.delayed(const Duration(milliseconds: 450));
      } catch (_) {}
      final shot = await cam.takePicture();
      RecognizedText result;
      try {
        result = await _recognizer.processImage(InputImage.fromFilePath(shot.path));
      } on PlatformException {
        // Some phones reject the camera's file directly: re-save it as a clean JPEG copy and try again.
        final fixed = await _resave(shot.path);
        result = await _recognizer.processImage(InputImage.fromFilePath(fixed));
      }
      final bytes = await File(shot.path).readAsBytes();
      final img = await decodeImageFromList(bytes);
      final text = result.text.trim();
      setState(() {
        _photo = shot.path;
        _photoSize = Size(img.width.toDouble(), img.height.toDouble());
        _boxes = [for (final b in result.blocks) b.boundingBox];
        _text = text.isEmpty ? null : text;
        _status = text.isEmpty ? S.t('read_none') : '';
      });
      Output.speak(text.isEmpty ? S.t('read_none') : text, force: true);
      TestLog.I.log('Basa', text.isEmpty ? 'no text' : text.replaceAll('\n', ' '), latencyMs: null);
      if (text.isEmpty) Haptics.play(Haptics.clear);
    } on PlatformException catch (e) {
      setState(() => _status = '${L('Could not read the text. Hold the phone still and try again.')}\n(${e.code}: ${e.message ?? ''})');
      Output.speak(L('Could not read the text. Hold the phone still and try again.'), force: true);
      TestLog.I.log('Basa', 'error ${e.code} ${e.message ?? ''}');
    } catch (e) {
      setState(() => _status = '${L('Could not read the text. Hold the phone still and try again.')}\n($e)');
      Output.speak(L('Could not read the text. Hold the phone still and try again.'), force: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Writes a downscaled PNG copy of the photo (max 1600 px) that ML Kit always accepts.
  Future<String> _resave(String path) async {
    final bytes = await File(path).readAsBytes();
    final probe = await decodeImageFromList(bytes);
    final big = probe.width > probe.height ? probe.width : probe.height;
    final scale = big > 1600 ? 1600 / big : 1.0;
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: (probe.width * scale).round(), targetHeight: (probe.height * scale).round());
    final img = (await codec.getNextFrame()).image;
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    final out = '${File(path).parent.path}/gabay_read_${DateTime.now().millisecondsSinceEpoch}.png';
    await File(out).writeAsBytes(png!.buffer.asUint8List());
    return out;
  }

  Future<void> _focusAt(Offset p) async {
    try {
      await _cam?.setFocusPoint(p);
      await _cam?.setExposurePoint(p);
      Haptics.play(const [20]);
    } catch (_) {}
  }

  @override
  void dispose() {
    _cam?.dispose();
    _recognizer.close();
    Output.stopSpeech();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cam = _cam;
    return ListenableBuilder(listenable: AppState.I, builder: (context, _) => Scaffold(
      appBar: AppBar(leading: const BackPill(), leadingWidth: 132, actions: const [LangToggle()], title: Text(S.lang == Lang.fil ? 'Basa' : 'Read (Basa)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: _photo != null && _photoSize != null
                  // Visual helper: the photo with every text block outlined.
                  ? LayoutBuilder(builder: (context, box) {
                      return Stack(fit: StackFit.expand, children: [
                        Image.file(File(_photo!), fit: BoxFit.cover),
                        CustomPaint(painter: _TextBoxPainter(_boxes, _photoSize!)),
                      ]);
                    })
                  : (cam != null && cam.value.isInitialized
                      // Tap the preview to focus on that spot.
                      ? LayoutBuilder(builder: (context, box) => GestureDetector(
                            onTapDown: (d) => _focusAt(Offset(d.localPosition.dx / box.maxWidth, d.localPosition.dy / box.maxHeight)),
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(width: cam.value.previewSize!.height, height: cam.value.previewSize!.width, child: CameraPreview(cam)),
                            ),
                          ))
                      : const ColoredBox(color: Colors.black, child: Center(child: CircularProgressIndicator()))),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : _read,
                icon: const Icon(Icons.document_scanner, size: 30),
                label: Text(S.lang == Lang.fil ? 'Basahin' : 'Read'),
              ),
            ),
            if (_photo != null) ...[
              const SizedBox(width: 10),
              SizedBox(
                width: 120,
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _photo = null;
                    _text = null;
                    _boxes = [];
                  }),
                  child: Text(S.lang == Lang.fil ? 'Bago' : 'New'),
                ),
              ),
            ],
          ]),
          const VerdictBar(),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_status, style: TextStyle(fontSize: 18, color: GabayColors.mute)),
          ],
          if (_text != null) ...[
            const SizedBox(height: 16),
            Row(children: [
              Icon(Icons.text_decrease, color: GabayColors.mute),
              Expanded(
                child: Slider(value: _fontSize, min: 18, max: 56, divisions: 19, label: _fontSize.round().toString(), onChanged: (v) => setState(() => _fontSize = v)),
              ),
              Icon(Icons.text_increase, color: GabayColors.mute),
            ]),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: GabayColors.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: GabayColors.line, width: 2)),
              child: SelectableText(_text!, style: TextStyle(fontSize: _fontSize, height: 1.35, color: GabayColors.ink, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Output.speak(_text!, force: true),
                  icon: const Icon(Icons.volume_up),
                  label: Text(S.lang == Lang.fil ? 'Basahin ulit' : L('Read again')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(onPressed: Output.stopSpeech, icon: const Icon(Icons.stop), label: Text(L('Stop'))),
              ),
            ]),
          ],
        ],
      ),
    ));
  }
}

class _TextBoxPainter extends CustomPainter {
  final List<Rect> boxes;
  final Size image;
  _TextBoxPainter(this.boxes, this.image);

  @override
  void paint(ui.Canvas canvas, Size size) {
    final scale = size.width / image.width > size.height / image.height ? size.width / image.width : size.height / image.height;
    final dx = (size.width - image.width * scale) / 2;
    final dy = (size.height - image.height * scale) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = GabayColors.accent;
    for (final b in boxes) {
      canvas.drawRect(Rect.fromLTRB(dx + b.left * scale, dy + b.top * scale, dx + b.right * scale, dy + b.bottom * scale), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TextBoxPainter old) => true;
}
