import 'package:flutter/material.dart';

import '../core/haptics.dart';
import '../core/theme.dart';
import '../widgets/big_tile.dart';

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
    _player.stop();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Touch Talk')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Type a message and the phone vibrates it in Morse code, one letter at a time.',
              style: TextStyle(color: GabayColors.mute, fontSize: 17)),
          const SizedBox(height: 16),
          TextField(
            controller: _text,
            minLines: 2,
            maxLines: 4,
            style: const TextStyle(fontSize: 20),
            decoration: const InputDecoration(hintText: 'Type a message'),
          ),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            segments: [for (final e in _speeds.entries) ButtonSegment(value: e.value, label: Text(e.key))],
            selected: {_unit},
            onSelectionChanged: (s) => setState(() => _unit = s.first),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: FilledButton(onPressed: () => _send(_text.text), child: const Text('Send as vibration'))),
              const SizedBox(width: 10),
              SizedBox(
                width: 110,
                child: OutlinedButton(
                  onPressed: () {
                    _player.stop();
                    setState(() => _letter = '');
                  },
                  child: const Text('Stop'),
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
          const SectionLabel('Quick messages'),
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
    );
  }
}
