import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/app_state.dart';
import '../core/output.dart';
import '../core/sound_info.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../engines/sound_classifier.dart';
import '../services/sound_watcher.dart';
import '../services/test_log.dart';
import '../widgets/big_tile.dart';
import '../widgets/verdict_bar.dart';
import '../core/l10n.dart';
import '../widgets/lang_toggle.dart';
import '../widgets/back_pill.dart';

/// Tunog: recognizes important sounds (YAMNet) and shows them as big icons, screen
/// flashes and vibration. Live captions turn speech into large text.
class SoundScreen extends StatefulWidget {
  const SoundScreen({super.key});

  @override
  State<SoundScreen> createState() => _SoundScreenState();
}

class _SoundScreenState extends State<SoundScreen> {
  late final SoundWatcher _watcher = SoundWatcher(onEvent: _onEvent, onLevel: _onLevel, onSpeech: _onSpeech);
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _alertsOn = false;
  bool _captionsOn = false;
  double _db = 0;
  SoundEvent? _current;
  DateTime _currentAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _talking = false;
  String _finalText = '';
  String _caption = '';
  double _captionSize = 28;
  final List<(SoundEvent, DateTime)> _log = [];
  String _error = '';

  void _onEvent(SoundEvent e) {
    Output.notify(SoundInfo.text(e.category), SoundInfo.pattern(e.category), color: e.urgent ? GabayColors.danger : GabayColors.accent);
    TestLog.I.log('Tunog', SoundInfo.text(e.category), label: e.label, score: e.score);
    if (!mounted) return;
    setState(() {
      _current = e;
      _currentAt = DateTime.now();
      _log.insert(0, (e, DateTime.now()));
      if (_log.length > 8) _log.removeLast();
    });
  }

  void _onLevel(double db) {
    if (mounted) setState(() => _db = db);
  }

  void _onSpeech(String? label) {
    if (mounted && _talking != (label != null)) setState(() => _talking = label != null);
  }

  Future<void> _toggleAlerts() async {
    if (_alertsOn) {
      await _watcher.stop();
      WakelockPlus.disable();
      setState(() {
        _alertsOn = false;
        _db = 0;
        _talking = false;
      });
      return;
    }
    await _stopCaptions();
    final ok = await _watcher.start();
    setState(() {
      _alertsOn = ok;
      _error = ok ? '' : L('Microphone permission denied');
    });
    if (ok) WakelockPlus.enable();
  }

  Future<void> _toggleCaptions() async {
    if (_captionsOn) return _stopCaptions();
    if (_alertsOn) await _toggleAlerts();
    final ok = await _speech.initialize(
      onStatus: (status) {
        if (_captionsOn && (status == 'done' || status == 'notListening')) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (_captionsOn && !_speech.isListening) _listen();
          });
        }
      },
      onError: (_) {},
    );
    if (!ok) {
      setState(() => _error = L('Speech recognition is not available on this phone'));
      return;
    }
    setState(() {
      _captionsOn = true;
      _caption = '';
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
          _caption = text.length > 600 ? text.substring(text.length - 600) : text;
          if (r.finalResult) _finalText = '$_finalText${r.recognizedWords} ';
        });
      },
      localeId: S.sttLocale,
      listenFor: const Duration(minutes: 5),
      pauseFor: const Duration(seconds: 6),
      listenOptions: stt.SpeechListenOptions(partialResults: true, listenMode: stt.ListenMode.dictation, onDevice: AppState.I.offlineCaptions),
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
    final fresh = _current != null && DateTime.now().difference(_currentAt).inSeconds < 6;
    final cur = _current;
    final curColor = cur != null && cur.urgent ? GabayColors.danger : GabayColors.accent;
    return ListenableBuilder(listenable: AppState.I, builder: (context, _) => Scaffold(
      appBar: AppBar(leading: const BackPill(), leadingWidth: 132, actions: const [LangToggle()], title: Text(S.lang == Lang.fil ? 'Tunog' : 'Sound')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(SoundClassifier.I.ready ? L('Recognizes horns, sirens, alarms, doorbells, knocking, babies crying, dogs and more.') : L('Alerts you to loud sounds by vibration and screen flashes.'),
              style: TextStyle(color: GabayColors.mute, fontSize: 17)),
          const SizedBox(height: 16),
          FilledButton(onPressed: _toggleAlerts, child: Text(_alertsOn ? L('Stop sound alerts') : L('Start sound alerts'))),
          const SizedBox(height: 16),

          // Visual helper: the last recognized sound as a big icon card.
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: fresh ? curColor : GabayColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: fresh ? curColor : GabayColors.line, width: 3),
            ),
            child: Row(children: [
              Icon(fresh ? SoundInfo.icon(cur!.category) : (_alertsOn ? Icons.hearing : Icons.hearing_disabled),
                  size: 64, color: fresh ? (cur!.urgent ? GabayColors.onDanger : GabayColors.onAccent) : GabayColors.mute),
              const SizedBox(width: 16),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      fresh ? SoundInfo.text(cur!.category) : (_alertsOn ? (S.lang == Lang.fil ? 'Nakikinig…' : 'Listening…') : (S.lang == Lang.fil ? 'Naka-off' : 'Off')),
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: fresh ? (cur!.urgent ? GabayColors.onDanger : GabayColors.onAccent) : GabayColors.ink),
                    ),
                    if (fresh && cur!.category != 'loud')
                      Text(S.lang == Lang.fil ? '${(cur!.score * 100).round()}% sigurado' : '${(cur!.score * 100).round()}% sure', style: TextStyle(fontSize: 16, color: cur!.urgent ? GabayColors.onDanger : GabayColors.onAccent)),
                  ]),
                ),
              ),
            ]),
          ),
          const VerdictBar(),
          const SizedBox(height: 12),
          if (_alertsOn && _talking)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: GabayColors.selected, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Icon(Icons.forum, color: GabayColors.accent),
                const SizedBox(width: 10),
                Text(S.t('speaking'), style: TextStyle(fontSize: 18, color: GabayColors.ink, fontWeight: FontWeight.w700)),
              ]),
            ),
          const SizedBox(height: 12),
          Text(_alertsOn ? '${L('Sound level')}: ${_db.toStringAsFixed(0)} dB' : L('Sound level'), style: TextStyle(color: GabayColors.mute)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: LinearProgressIndicator(value: level, minHeight: 22, backgroundColor: GabayColors.card, color: level > 0.65 ? GabayColors.danger : GabayColors.ok),
          ),
          ListenableBuilder(
            listenable: AppState.I,
            builder: (context, _) => Row(children: [
              Text(L('Sensitivity'), style: TextStyle(color: GabayColors.mute)),
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
            ]),
          ),
          if (_error.isNotEmpty) Text(_error, style: TextStyle(color: GabayColors.danger, fontWeight: FontWeight.w700)),

          SectionLabel(L('Live captions')),
          OutlinedButton(onPressed: _toggleCaptions, child: Text(_captionsOn ? L('Stop live captions') : L('Start live captions'))),
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.text_decrease, color: GabayColors.mute),
            Expanded(child: Slider(value: _captionSize, min: 20, max: 56, divisions: 18, onChanged: (v) => setState(() => _captionSize = v))),
            Icon(Icons.text_increase, color: GabayColors.mute),
          ]),
          // Visual helper: big, high-contrast captions; newest words highlighted.
          Container(
            constraints: const BoxConstraints(minHeight: 180),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: GabayColors.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: _captionsOn ? GabayColors.accent : GabayColors.line, width: 3)),
            child: Semantics(
              liveRegion: true,
              child: Text(
                _caption.isEmpty ? (_captionsOn ? (S.lang == Lang.fil ? 'Nakikinig…' : 'Listening…') : (S.lang == Lang.fil ? 'Lalabas dito ang caption.' : 'Captions will appear here.')) : _caption,
                style: TextStyle(fontSize: _captionSize, fontWeight: FontWeight.w700, height: 1.25, color: GabayColors.ink),
              ),
            ),
          ),

          SectionLabel(L('Recent sounds')),
          if (_log.isEmpty) Text(L('No sounds yet'), style: TextStyle(color: GabayColors.mute)),
          for (final (e, at) in _log)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: GabayColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: e.urgent ? GabayColors.danger : GabayColors.line, width: 2)),
              child: Row(children: [
                Icon(SoundInfo.icon(e.category), color: e.urgent ? GabayColors.danger : GabayColors.accent),
                const SizedBox(width: 10),
                Expanded(child: Text(SoundInfo.text(e.category), style: const TextStyle(fontSize: 17))),
                Text(TimeOfDay.fromDateTime(at).format(context), style: TextStyle(color: GabayColors.mute)),
              ]),
            ),
        ],
      ),
    ));
  }
}
