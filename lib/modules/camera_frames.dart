import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// A plain camera preview that hands every frame to [onFrame] (one at a time).
class FrameCamera extends StatefulWidget {
  final Future<void> Function(CameraImage img, int rotation) onFrame;
  final ResolutionPreset preset;
  const FrameCamera({super.key, required this.onFrame, this.preset = ResolutionPreset.high});

  @override
  State<FrameCamera> createState() => _FrameCameraState();
}

class _FrameCameraState extends State<FrameCamera> {
  CameraController? _cam;
  bool _busy = false;

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
    final cam = CameraController(back, widget.preset,
        enableAudio: false, imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888);
    await cam.initialize();
    try {
      await cam.setFocusMode(FocusMode.auto);
    } catch (_) {}
    if (!mounted) {
      await cam.dispose();
      return;
    }
    setState(() => _cam = cam);
    await cam.startImageStream((img) async {
      if (_busy || !mounted) return;
      _busy = true;
      try {
        await widget.onFrame(img, cam.description.sensorOrientation);
      } catch (_) {
      } finally {
        _busy = false;
      }
    });
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    final cam = _cam;
    _cam = null;
    if (cam != null) {
      if (cam.value.isStreamingImages) cam.stopImageStream().catchError((_) {});
      cam.dispose();
    }
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized) return const ColoredBox(color: Colors.black, child: Center(child: CircularProgressIndicator()));
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(width: cam.value.previewSize!.height, height: cam.value.previewSize!.width, child: CameraPreview(cam)),
    );
  }
}
