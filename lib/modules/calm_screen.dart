import 'dart:async';

import 'package:flutter/material.dart';

import '../core/haptics.dart';
import '../core/output.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../services/sound_watcher.dart';

/// Noise monitor that warns before overload, plus a haptic breathing guide
/// (4 s in, 4 s hold, 6 s out).
class CalmScreen extends StatefulWidget {
  const CalmScreen({super.key});

  @override
  State<CalmScreen> createState() => _CalmScreenState();
}

class _CalmScreenState extends State<CalmScreen> {
  late final SoundWatcher _watcher = SoundWatcher(onLevel: _onLevel);
  bool _monitoring = false;
  double _db = 0;
  DateTime? _loudSince;
  DateTime _lastWarn = DateTime.fromMillisecondsSinceEpoch(0);

  bool _breathing = false;
  String _phase = 'Ready';
  double _scale = 1;
  Duration _anim = const Duration(milliseconds: 600);
  final List<Timer> _timers = [];

  void _onLevel(double db) {
    final now = DateTime.now();
    if (db >= 70) {
      _loudSince ??= now;
    } else {
      _loudSince = null;
    }
    if (_loudSince != null &&
        now.difference(_loudSince!).inSeconds >= 3 &&
        now.difference(_lastWarn).inSeconds >= 20) {
      _lastWarn = now;
      Output.notify(S.t('noisy'), Haptics.gentle, color: GabayColors.calm);
    }
    if (mounted) setState(() => _db = db);
  }

  Future<void> _toggleMonitor() async {
    if (_monitoring) {
      _watcher.stop();
      setState(() {
        _monitoring = false;
        _db = 0;
      });
      return;
    }
    final ok = await _watcher.start();
    setState(() => _monitoring = ok);
  }

  void _step(String phase, double scale, int ms, List<int>? pattern, int delayMs) {
    _timers.add(Timer(Duration(milliseconds: delayMs), () {
      if (!_breathing || !mounted) return;
      setState(() {
        _phase = S.t(phase);
        _scale = scale;
        _anim = Duration(milliseconds: ms);
      });
      if (pattern != null) Haptics.play(pattern);
    }));
  }

  void _cycle() {
    if (!_breathing) return;
    _step('inhale', 2.1, 4000, Haptics.pulses(8, 40, 460), 0); // quick buzzes = breathe in
    _step('hold', 2.1, 4000, null, 4000);
    _step('exhale', 1.0, 6000, Haptics.pulses(4, 300, 1200), 8000); // slow buzzes = breathe out
    _timers.add(Timer(const Duration(milliseconds: 14000), _cycle));
  }

  void _toggleBreathing() {
    if (_breathing) {
      _stopBreathing();
      return;
    }
    setState(() => _breathing = true);
    _cycle();
  }

  void _stopBreathing() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    Haptics.cancel();
    setState(() {
      _breathing = false;
      _phase = 'Ready';
      _scale = 1;
      _anim = const Duration(milliseconds: 600);
    });
  }

  @override
  void dispose() {
    _watcher.stop();
    _breathing = false;
    for (final t in _timers) {
      t.cancel();
    }
    Haptics.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _db < 55 ? ('Calm', GabayColors.ok) : (_db < 70 ? ('Busy', GabayColors.accent) : ('Loud', GabayColors.danger));
    return Scaffold(
      appBar: AppBar(title: const Text('Calm')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Watches the noise around you and warns before it gets overwhelming. Follow the breathing buzz to settle down.',
              style: TextStyle(color: GabayColors.mute, fontSize: 17)),
          const SizedBox(height: 16),
          FilledButton(onPressed: _toggleMonitor, child: Text(_monitoring ? 'Stop noise monitor' : 'Start noise monitor')),
          const SizedBox(height: 14),
          Text(_monitoring ? '${_db.toStringAsFixed(0)} dB' : '--',
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900)),
          Text(_monitoring ? 'Noise level (estimate): ${state.$1}' : 'Noise level (estimate)',
              style: TextStyle(color: GabayColors.mute)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: LinearProgressIndicator(
              value: _monitoring ? ((_db - 30) / 80).clamp(0.0, 1.0) : 0,
              minHeight: 22,
              backgroundColor: GabayColors.card,
              color: state.$2,
            ),
          ),
          SizedBox(
            height: 280,
            child: Center(
              child: AnimatedScale(
                scale: MediaQuery.of(context).disableAnimations ? 1 : _scale,
                duration: _anim,
                curve: Curves.easeInOut,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: Alignment(-0.3, -0.3),
                      colors: [Color(0xFFFFF3B0), GabayColors.accent, Color(0xFFC99A10)],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Semantics(
            liveRegion: true,
            child: Text(_phase, textAlign: TextAlign.center, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _toggleBreathing,
            child: Text(_breathing ? 'Stop breathing guide' : 'Start breathing guide'),
          ),
          const SizedBox(height: 8),
          Text('Breathe in with the quick buzzes, out with the slow ones.',
              textAlign: TextAlign.center, style: TextStyle(color: GabayColors.mute)),
        ],
      ),
    );
  }
}
