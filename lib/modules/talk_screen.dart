import 'dart:async';

import 'package:flutter/material.dart';

import '../core/haptics.dart';
import '../core/output.dart';
import '../core/theme.dart';
import '../widgets/big_tile.dart';
import '../core/l10n.dart';
import '../core/app_state.dart';
import '../widgets/lang_toggle.dart';
import '../widgets/back_pill.dart';

/// A family member types a message; the phone vibrates it in Morse code
/// so a deafblind user can feel it.
class TalkScreen extends StatefulWidget {
  const TalkScreen({super.key});

  @override
  State<TalkScreen> createState() => _TalkScreenState();
}

class _TalkScreenState extends State<TalkScreen> {
  final _text = TextEditingController(text: 'Kain na');
  final _player = MorsePlayer();
  int _unit = 140;
  String _letter = '';

  // Tap Reply: tap = dot, hold = dash. A short pause ends the letter, a long pause adds a space.
  String _code = '';
  String _reply = '';
  DateTime? _downAt;
  Timer? _gapTimer;
  static final Map<String, String> _decode = {for (final e in morseCode.entries) e.value: e.key};

  void _tapDown() {
    _gapTimer?.cancel();
    _downAt = DateTime.now();
  }

  void _tapUp() {
    final held = DateTime.now().difference(_downAt ?? DateTime.now()).inMilliseconds;
    final sym = held < 250 ? '.' : '-';
    Haptics.play(sym == '.' ? const [40] : const [160]);
    setState(() => _code += sym);
    _gapTimer = Timer(const Duration(milliseconds: 800), () {
      final ch = _decode[_code];
      setState(() {
        if (ch != null) _reply += ch;
        _code = '';
      });
      if (ch == null) Haptics.play(const [30, 60, 30, 60, 30]); // unknown pattern
      _gapTimer = Timer(const Duration(milliseconds: 1200), () {
        if (_reply.isNotEmpty && !_reply.endsWith(' ')) setState(() => _reply += ' ');
      });
    });
  }

  static const _quick = ['Kain na', 'Nandito ako', 'Hintay', 'Tara na', 'OK ka ba', 'Tulog na'];
  static const _speeds = {'Slow': 200, 'Normal': 140, 'Fast': 90};

  void _send(String msg) {
    if (msg.trim().isEmpty) return;
    _player.play(msg, _unit, (l) {
      if (mounted) setState(() => _letter = l);
    });
  }

  @override
  void dispose() {
    _gapTimer?.cancel();
    _player.stop();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: AppState.I, builder: (context, _) => Scaffold(
      appBar: AppBar(leading: const BackPill(), leadingWidth: 132, actions: const [LangToggle()], title: Text(L('Touch Talk'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(L('Type a message and the phone vibrates it in Morse code, one letter at a time.'),
              style: TextStyle(color: GabayColors.mute, fontSize: 17)),
          const SizedBox(height: 16),
          TextField(
            controller: _text,
            minLines: 2,
            maxLines: 4,
            style: const TextStyle(fontSize: 20),
            decoration: InputDecoration(hintText: L('Type a message')),
          ),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            segments: [for (final e in _speeds.entries) ButtonSegment(value: e.value, label: Text(L(e.key)))],
            selected: {_unit},
            onSelectionChanged: (s) => setState(() => _unit = s.first),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: FilledButton(onPressed: () => _send(_text.text), child: Text(L('Send as vibration')))),
              const SizedBox(width: 10),
              SizedBox(
                width: 110,
                child: OutlinedButton(
                  onPressed: () {
                    _player.stop();
                    setState(() => _letter = '');
                  },
                  child: Text(L('Stop')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: Center(
              child: Text(_letter,
                  style: TextStyle(fontSize: 120, fontWeight: FontWeight.w900, color: GabayColors.accent, height: 1)),
            ),
          ),
          // Visual helper: the current letter's Morse code as dots and dashes.
          if (morseCode[_letter] != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final c in morseCode[_letter]!.split(''))
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: c == '.' ? 22 : 66,
                    height: 22,
                    decoration: BoxDecoration(color: GabayColors.accent, borderRadius: BorderRadius.circular(11)),
                  ),
              ],
            ),
          SectionLabel(L('Tap Reply (for the deafblind user)')),
          Text(L('Tap for a dot, hold for a dash. Pause to finish a letter. Your family reads or hears the reply.'),
              style: TextStyle(color: GabayColors.mute, fontSize: 16)),
          const SizedBox(height: 10),
          Semantics(
            label: L('Morse tap pad. Tap for dot, hold for dash.'),
            button: true,
            child: Listener(
              onPointerDown: (_) => _tapDown(),
              onPointerUp: (_) => _tapUp(),
              child: Container(
                height: 180,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: GabayColors.card, borderRadius: BorderRadius.circular(24), border: Border.all(color: GabayColors.accent, width: 4)),
                // Visual helper: the dots and dashes being typed.
                child: Text(_code.isEmpty ? 'TAP' : _code.replaceAll('.', '●').replaceAll('-', '▬'),
                    style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: GabayColors.accent, letterSpacing: 6)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: GabayColors.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: GabayColors.line, width: 2)),
            child: Semantics(liveRegion: true, child: Text(_reply.isEmpty ? L('Reply appears here') : _reply, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: GabayColors.ink))),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: FilledButton.icon(onPressed: _reply.trim().isEmpty ? null : () => Output.speak(_reply, force: true), icon: const Icon(Icons.volume_up), label: Text(L('Speak reply')))),
            const SizedBox(width: 10),
            SizedBox(width: 120, child: OutlinedButton(onPressed: () => setState(() { _reply = ''; _code = ''; }), child: Text(L('Clear')))),
          ]),
          SectionLabel(L('Quick messages')),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final q in _quick)
                ActionChip(
                  label: Padding(padding: const EdgeInsets.all(8), child: Text(q, style: const TextStyle(fontSize: 18))),
                  onPressed: () {
                    _text.text = q;
                    _send(q);
                  },
                ),
            ],
          ),
        ],
      ),
    ));
  }
}
