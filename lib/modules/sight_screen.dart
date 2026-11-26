import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/app_state.dart';
import '../core/haptics.dart';
import '../core/output.dart';
import '../core/profiles.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../services/sound_watcher.dart';
import 'sos_screen.dart';

/// Camera → on-device object detection → direction + distance → vibration.
/// Gestures: tap = pause, double-tap = repeat, hold 1.5 s = SOS.
class SightScreen extends StatefulWidget {
  const SightScreen({super.key});

  @override
  State<SightScreen> createState() => _SightScreenState();
}

class _Target {
  final String label;
  final String dir; // left / center / right
  final int near; // 1 far, 2 close, 3 very close
  final Rect box;
  final DateTime at;
  _Target(this.label, this.dir, this.near, this.box) : at = DateTime.now();
  String get key => '$label$dir$near';
}

class _SightScreenState extends State<SightScreen> {
  CameraController? _cam;
  ObjectDetector? _detector;
  SoundWatcher? _sound;
  Timer? _hapticTimer;
  Timer? _holdTimer;

  bool _busy = false;
  bool _paused = false;
  bool _showBoxes = true;
  String _say = S.t('loading');
  String _meta = 'Tap: pause · Double-tap: repeat · Hold: SOS';
  _Target? _target;
  List<DetectedObject> _objects = [];
  Size _imageSize = Size.zero;
  String _lastKey = '';
  DateTime _lastSpeak = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastBuzz = DateTime.fromMillisecondsSinceEpoch(0);
  int _frames = 0;
  DateTime _fpsAt = DateTime.now();
  int _fps = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final perm = await Permission.camera.request();
    if (!perm.isGranted) {
      setState(() => _say = 'Camera permission denied');
      return;
    }
    final cams = await availableCameras();
    if (cams.isEmpty) {
      setState(() => _say = 'No camera found');
      return;
    }
    final back = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cams.first);
    final cam = CameraController(
      back,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );
    await cam.initialize();
    if (!mounted) {
      await cam.dispose();
      return;
    }
    _detector = ObjectDetector(
      options: ObjectDetectorOptions(mode: DetectionMode.stream, classifyObjects: true, multipleObjects: true),
    );
    _cam = cam;
    await cam.startImageStream(_onFrame);
    WakelockPlus.enable();
    _hapticTimer = Timer.periodic(const Duration(milliseconds: 100), (_) => _hapticTick());

    // Blind and deafblind users also get sound alerts while walking.
    final p = AppState.I.profile;
    if (p == Profile.blind || p == Profile.deafblind) {
      _sound = SoundWatcher(onAlert: (kind) {
        if (_paused) return;
        _lastBuzz = DateTime.now().add(const Duration(milliseconds: 1500));
        Haptics.play(kind == 'continuous' ? Haptics.continuous : Haptics.sudden);
        Output.speak(S.t(kind));
        if (mounted) setState(() => _say = S.t(kind));
      });
      await _sound!.start();
    }

    Haptics.play(Haptics.start);
    Output.speak(S.t('ready'));
    if (mounted) setState(() => _say = S.t('ready'));
  }

  InputImage? _toInputImage(CameraImage image) {
    final cam = _cam;
    if (cam == null) return null;
    final rotation = InputImageRotationValue.fromRawValue(cam.description.sensorOrientation);
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null || format == null || image.planes.length != 1) return null;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_busy || _paused || !mounted || _detector == null) return;
    _busy = true;
    try {
      final input = _toInputImage(image);
      if (input == null) return;
      final objects = await _detector!.processImage(input);
      final rot = input.metadata!.rotation;
      final sideways = rot == InputImageRotation.rotation90deg || rot == InputImageRotation.rotation270deg;
      final upright = sideways
          ? Size(image.height.toDouble(), image.width.toDouble())
          : Size(image.width.toDouble(), image.height.toDouble());
      _process(objects, upright);
    } catch (_) {
      // Skip a bad frame.
    } finally {
      _busy = false;
    }
  }

  void _process(List<DetectedObject> objects, Size size) {
    _Target? best;
    double bestScore = 0;
    for (final o in objects) {
      final b = o.boundingBox;
      final area = (b.width * b.height) / (size.width * size.height);
      final tall = pow(b.height / size.height, 2) * 0.6;
      final closeness = max(area, tall.toDouble()); // bigger on screen = closer
      if (closeness < 0.05) continue;
      if (closeness > bestScore) {
        bestScore = closeness;
        final cx = b.center.dx / size.width;
        final dir = cx < 0.38 ? 'left' : (cx > 0.62 ? 'right' : 'center');
        final near = closeness > 0.3 ? 3 : (closeness > 0.12 ? 2 : 1);
        final label = o.labels.isNotEmpty ? o.labels.first.text : S.t('object');
        best = _Target(label, dir, near, b);
      }
    }
    final now = DateTime.now();
    _frames++;
    if (now.difference(_fpsAt).inMilliseconds > 1000) {
      _fps = _frames;
      _frames = 0;
      _fpsAt = now;
    }
    final key = best?.key ?? 'none';
    if (best != null && key != _lastKey && now.difference(_lastSpeak).inMilliseconds > 2000) {
      Output.speak(_describe(best));
      _lastSpeak = now;
    }
    if (key != 'none' || now.difference(_lastSpeak).inMilliseconds > 2000) _lastKey = key;
    if (!mounted) return;
    setState(() {
      _target = best;
      _objects = objects;
      _imageSize = size;
      _say = _describe(best);
      _meta = 'Detector: $_fps fps · Tap: pause · Double-tap: repeat · Hold: SOS';
    });
  }

  String _describe(_Target? t) {
    if (t == null) return S.t('clear');
    final near = t.near == 3 ? ', ${S.t('veryClose')}' : (t.near == 2 ? ', ${S.t('close')}' : '');
    return '${t.label} ${S.t(t.dir)}$near';
  }

  // Closer objects buzz more often.
  void _hapticTick() {
    final t = _target;
    if (_paused || t == null) return;
    final now = DateTime.now();
    if (now.difference(t.at).inMilliseconds > 800) return;
    const gaps = [0, 2600, 1400, 750];
    if (now.difference(_lastBuzz).inMilliseconds < gaps[t.near]) return;
    _lastBuzz = now;
    final pattern = switch (t.dir) { 'left' => Haptics.left, 'right' => Haptics.right, _ => Haptics.center };
    Haptics.play(t.near == 3 ? [...Haptics.danger, 250, ...pattern] : pattern);
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
    final fresh = t != null && DateTime.now().difference(t.at).inMilliseconds < 800;
    if (fresh) {
      Haptics.play(switch (t.dir) { 'left' => Haptics.left, 'right' => Haptics.right, _ => Haptics.center });
    } else {
      Haptics.play(Haptics.clear);
    }
    Output.speak(_describe(fresh ? t : null));
  }

  @override
  void dispose() {
    _hapticTimer?.cancel();
    _holdTimer?.cancel();
    _sound?.stop();
    final cam = _cam;
    _cam = null;
    if (cam != null) {
      if (cam.value.isStreamingImages) cam.stopImageStream().catchError((_) {});
      cam.dispose();
    }
    _detector?.close();
    WakelockPlus.disable();
    Haptics.cancel();
    Output.stopSpeech();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cam = _cam;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Semantics(
        label: 'Sight is running. Tap to pause, double tap to repeat, hold for SOS.',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _togglePause,
          onDoubleTap: _repeat,
          onLongPressStart: (_) =>
              _holdTimer = Timer(const Duration(milliseconds: 1500), () => SosScreen.trigger(reason: 'Manual SOS')),
          onLongPressEnd: (_) => _holdTimer?.cancel(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (cam != null && cam.value.isInitialized)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: cam.value.previewSize!.height,
                    height: cam.value.previewSize!.width,
                    child: CameraPreview(cam),
                  ),
                ),
              if (_showBoxes && _imageSize != Size.zero)
                CustomPaint(painter: _BoxPainter(_objects, _imageSize, _target?.box)),
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                  padding: const EdgeInsets.fromLTRB(20, 48, 20, 28),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xE0000000)],
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_say,
                            style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                                color: _paused ? HolosColors.mute : Colors.white)),
                        const SizedBox(height: 6),
                        Text(_meta, style: const TextStyle(color: Colors.white70, fontSize: 15)),
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

  Widget _pill(String text, VoidCallback onTap) => Material(
        color: Colors.black54,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ),
      );
}

/// Draws detection boxes for sighted helpers and panel demos.
class _BoxPainter extends CustomPainter {
  final List<DetectedObject> objects;
  final Size imageSize;
  final Rect? target;
  _BoxPainter(this.objects, this.imageSize, this.target);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = max(size.width / imageSize.width, size.height / imageSize.height);
    final dx = (size.width - imageSize.width * scale) / 2;
    final dy = (size.height - imageSize.height * scale) / 2;
    for (final o in objects) {
      final b = o.boundingBox;
      final r = Rect.fromLTWH(dx + b.left * scale, dy + b.top * scale, b.width * scale, b.height * scale);
      final isTarget = target == b;
      canvas.drawRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = isTarget ? HolosColors.accent : Colors.white54,
      );
      final label = o.labels.isNotEmpty ? o.labels.first.text : 'Object';
      final tp = TextPainter(
        text: TextSpan(
            text: ' $label ',
            style: TextStyle(color: Colors.black, fontSize: 15, backgroundColor: isTarget ? HolosColors.accent : Colors.white70)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(r.left, max(0, r.top - tp.height)));
    }
  }

  @override
  bool shouldRepaint(covariant _BoxPainter old) => true;
}
