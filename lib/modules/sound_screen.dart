import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/app_state.dart';
import '../core/haptics.dart';
import '../core/output.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../services/sound_watcher.dart';
import '../widgets/big_tile.dart';

/// Sound alerts (for deaf / deafblind users) and live captions.
class SoundScreen extends StatefulWidget {
  const SoundScreen({super.key});

  @override
  State<SoundScreen> createState() => _SoundScreenState();
}

class _SoundScreenState extends State<SoundScreen> {
  late final SoundWatcher _watcher = SoundWatcher(onAlert: _onAlert, onLevel: _onLevel);
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _alertsOn = false;
  bool _captionsOn = false;
  double _db = 0;
  String _finalText = '';
  String _caption = 'Captions will appear here.';
  final List<(String, DateTime)> _log = [];
  String _error = '';

  void _onAlert(String kind) {
    Output.notify(S.t(kind), kind == 'continuous' ? Haptics.continuous : Haptics.sudden);
    if (!mounted) return;
    setState(() {
      _log.insert(0, (S.t(kind), DateTime.now()));
      if (_log.length > 8) _log.removeLast();
    });
  }

  void _onLevel(double db) {
    if (mounted) setState(() => _db = db);
  }

  Future<void> _toggleAlerts() async {
    if (_alertsOn) {
      _watcher.stop();
      WakelockPlus.disable();
      setState(() {
        _alertsOn = false;
        _db = 0;
      });
      return;
    }
    await _stopCaptions();
    final ok = await _watcher.start();
    setState(() {
      _alertsOn = ok;
      _error = ok ? '' : 'Microphone permission denied';
    });
    if (ok) WakelockPlus.enable();
  }

  Future<void> _toggleCaptions() async {
    if (_captionsOn) return _stopCaptions();
    if (_alertsOn) await _toggleAlerts();
    final ok = await _speech.initialize(
      onStatus: (status) {
        // Keep listening continuously until the user stops captions.
        if (_captionsOn && (status == 'done' || status == 'notListening')) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (_captionsOn && !_speech.isListening) _listen();
          });
        }
      },
      onError: (_) {},
    );
    if (!ok) {
      setState(() => _error = 'Speech recognition is not available on this phone');
      return;
    }
    setState(() {
      _captionsOn = true;
      _caption = 'Listening…';
      _error = '';
    });
    WakelockPlus.enable();
    _listen();
  }

  void _listen() {
    _speech.listen(
      onResult: (r) {
        if (!mounted) return;
        setState(() {
          final text = '$_finalText${r.recognizedWords}';
          _caption = text.length > 500 ? text.substring(text.length - 500) : text;
          if (r.finalResult) _finalText = '$_finalText${r.recognizedWords} ';
        });
      },
      localeId: S.sttLocale,
      listenFor: const Duration(minutes: 5),
      pauseFor: const Duration(seconds: 6),
      listenOptions: stt.SpeechListenOptions(partialResults: true, listenMode: stt.ListenMode.dictation),
    );
  }

  Future<void> _stopCaptions() async {
    if (!_captionsOn) return;
    setState(() => _captionsOn = false);
    await _speech.stop();
    WakelockPlus.disable();
  }

  @override
  void dispose() {
    _watcher.stop();
    _captionsOn = false;
    _speech.stop();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final level = ((_db - 30) / 80).clamp(0.0, 1.0);
    return Scaffold(
      appBar: AppBar(title: const Text('Sound')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Alerts you to loud sounds by vibration and screen flashes. Live captions turn speech into large text.',
              style: TextStyle(color: GabayColors.mute, fontSize: 17)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _toggleAlerts,
            child: Text(_alertsOn ? 'Stop sound alerts' : 'Start sound alerts'),
          ),
          const SizedBox(height: 12),
          Text(_alertsOn ? 'Sound level: ${_db.toStringAsFixed(0)} dB (estimate)' : 'Sound level',
              style: TextStyle(color: GabayColors.mute)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: LinearProgressIndicator(
              value: level,
              minHeight: 22,
              backgroundColor: GabayColors.card,
              color: level > 0.65 ? GabayColors.danger : GabayColors.ok,
            ),
          ),
          const SizedBox(height: 8),
          ListenableBuilder(
            listenable: AppState.I,
            builder: (context, _) => Row(
              children: [
                Text('Sensitivity', style: TextStyle(color: GabayColors.mute)),
                Expanded(
                  child: Slider(
                    value: AppState.I.soundSensitivity,
                    min: -15,
                    max: 15,
                    divisions: 6,
                    label: AppState.I.soundSensitivity.toStringAsFixed(0),
                    onChanged: AppState.I.setSoundSensitivity,
                  ),
                ),
              ],
            ),
          ),
          if (_error.isNotEmpty) Text(_error, style: TextStyle(color: GabayColors.danger, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _toggleCaptions,
            child: Text(_captionsOn ? 'Stop live captions' : 'Start live captions'),
          ),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(minHeight: 180),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: GabayColors.card, borderRadius: BorderRadius.circular(18)),
            child: Semantics(
              liveRegion: true,
              child: Text(_caption, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.25)),
            ),
          ),
          const SectionLabel('Recent alerts'),
          if (_log.isEmpty) Text('No alerts yet', style: TextStyle(color: GabayColors.mute)),
          for (final (text, at) in _log)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: GabayColors.card, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Expanded(child: Text(text)),
                  Text(TimeOfDay.fromDateTime(at).format(context), style: TextStyle(color: GabayColors.mute)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
