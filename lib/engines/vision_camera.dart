import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/theme.dart';
import 'detector.dart';

/// Maps a normalized box (upright image) onto the screen area, matching the cover-fitted preview.
Rect normToScreen(Rect n, Size screen, double imageAspect) {
  final imgW = imageAspect >= screen.width / screen.height ? screen.height * imageAspect : screen.width;
  final imgH = imgW / imageAspect;
  final dx = (screen.width - imgW) / 2;
  final dy = (screen.height - imgH) / 2;
  return Rect.fromLTRB(dx + n.left * imgW, dy + n.top * imgH, dx + n.right * imgW, dy + n.bottom * imgH);
}

/// Live camera + object detection. Detections are filtered (2 of 3 frames) before reporting.
class VisionCamera extends StatefulWidget {
  final void Function(List<Det> dets, double fps) onDetections;
  final bool paused;
  final bool showBoxes;
  final void Function(String error)? onError;

  const VisionCamera({super.key, required this.onDetections, this.paused = false, this.showBoxes = true, this.onError});

  @override
  State<VisionCamera> createState() => VisionCameraState();
}

class VisionCameraState extends State<VisionCamera> {
  CameraController? _cam;
  ObjectDetector? _mlkit;
  final _tracker = DetTracker();
  bool _busy = false;
  List<Det> dets = [];
  double imageAspect = 3 / 4;
  int _frames = 0;
  DateTime _fpsAt = DateTime.now();
  double fps = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final perm = await Permission.camera.request();
    if (!perm.isGranted) {
      widget.onError?.call('Camera permission denied');
      return;
    }
    await Detector.I.load();
    await Detector.custom.load();
    if (!Detector.I.ready) {
      _mlkit = ObjectDetector(options: ObjectDetectorOptions(mode: DetectionMode.stream, classifyObjects: true, multipleObjects: true));
    }
    final cams = await availableCameras();
    if (cams.isEmpty) {
      widget.onError?.call('No camera found');
      return;
    }
    final back = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cams.first);
    // high (720p) instead of medium (480p): medium looked blurry when stretched to full screen.
    final cam = CameraController(back, ResolutionPreset.high,
        enableAudio: false, imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888);
    try {
      await cam.initialize();
    } catch (e) {
      widget.onError?.call('Camera could not start');
      return;
    }
    try {
      await cam.setFocusMode(FocusMode.auto);
      await cam.setExposureMode(ExposureMode.auto);
    } catch (_) {}
    if (!mounted) {
      await cam.dispose();
      return;
    }
    final ps = cam.value.previewSize;
    if (ps != null) imageAspect = min(ps.width, ps.height) / max(ps.width, ps.height);
    setState(() => _cam = cam);
    await cam.startImageStream(_onFrame);
    WakelockPlus.enable();
  }

  Future<void> _onFrame(CameraImage img) async {
    if (_busy || widget.paused || !mounted) return;
    _busy = true;
    try {
      final rotation = _cam!.description.sensorOrientation;
      List<Det> raw;
      if (Detector.I.ready && img.planes.length == 1) {
        final plane = img.planes.first;
        raw = await Detector.I.detect(FrameData(plane.bytes, img.width, img.height, plane.bytesPerRow, rotation,
            Detector.I.inW, Detector.I.inH, Platform.isAndroid, Detector.I.asFloat));
        if (Detector.custom.ready) {
          final c = Detector.custom;
          raw = [...raw, ...await c.detect(FrameData(plane.bytes, img.width, img.height, plane.bytesPerRow, rotation, c.inW, c.inH, Platform.isAndroid, c.asFloat))];
        }
      } else {
        raw = await _mlkitDetect(img, rotation);
      }
      final confirmed = _tracker.update(raw);
      _frames++;
      final now = DateTime.now();
      final ms = now.difference(_fpsAt).inMilliseconds;
      if (ms > 1000) {
        fps = _frames * 1000 / ms;
        _frames = 0;
        _fpsAt = now;
      }
      if (!mounted) return;
      setState(() => dets = confirmed);
      widget.onDetections(confirmed, fps);
    } catch (_) {
      // skip a bad frame
    } finally {
      _busy = false;
    }
  }

  Future<List<Det>> _mlkitDetect(CameraImage img, int rotationDeg) async {
    final rotation = InputImageRotationValue.fromRawValue(rotationDeg);
    final format = InputImageFormatValue.fromRawValue(img.format.raw);
    if (_mlkit == null || rotation == null || format == null || img.planes.length != 1) return const [];
    final plane = img.planes.first;
    final input = InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(size: Size(img.width.toDouble(), img.height.toDouble()), rotation: rotation, format: format, bytesPerRow: plane.bytesPerRow),
    );
    final objects = await _mlkit!.processImage(input);
    final sideways = rotationDeg == 90 || rotationDeg == 270;
    final w = sideways ? img.height.toDouble() : img.width.toDouble();
    final h = sideways ? img.width.toDouble() : img.height.toDouble();
    return [
      for (final o in objects)
        Det(o.labels.isNotEmpty ? o.labels.first.text.toLowerCase() : 'object', o.labels.isNotEmpty ? o.labels.first.confidence : 0.6,
            Rect.fromLTRB(o.boundingBox.left / w, o.boundingBox.top / h, o.boundingBox.right / w, o.boundingBox.bottom / h)),
    ];
  }

  @override
  void dispose() {
    final cam = _cam;
    _cam = null;
    if (cam != null) {
      if (cam.value.isStreamingImages) cam.stopImageStream().catchError((_) {});
      cam.dispose();
    }
    _mlkit?.close();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized) {
      return const ColoredBox(color: Colors.black, child: Center(child: CircularProgressIndicator()));
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(width: cam.value.previewSize!.height, height: cam.value.previewSize!.width, child: CameraPreview(cam)),
        ),
        if (widget.showBoxes) CustomPaint(painter: DetPainter(dets, imageAspect)),
      ],
    );
  }
}

/// Visual helper: draws each detection with a large label. Vehicles in the danger color.
class DetPainter extends CustomPainter {
  final List<Det> dets;
  final double aspect;
  final Det? highlight;
  final bool fill;
  DetPainter(this.dets, this.aspect, {this.highlight, this.fill = false});

  @override
  void paint(Canvas canvas, Size size) {
    for (final d in dets) {
      final r = normToScreen(d.box, size, aspect);
      final color = d.isHazard ? GabayColors.danger : (identical(d, highlight) ? GabayColors.accent : Colors.white);
      if (fill) canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(10)), Paint()..color = color.withAlpha(70));
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(10)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = identical(d, highlight) ? 6 : 4
          ..color = color,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: ' ${d.label} ${(d.score * 100).round()}% ',
          style: TextStyle(color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white, fontSize: 18, fontWeight: FontWeight.w800, backgroundColor: color),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(r.left, max(0, r.top - tp.height)));
    }
  }

  @override
  bool shouldRepaint(covariant DetPainter old) => true;
}
