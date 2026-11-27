import 'package:flutter/material.dart';

import '../core/haptics.dart';
import '../core/output.dart';
import '../widgets/big_tile.dart';
import '../core/l10n.dart';
import '../core/app_state.dart';
import '../widgets/lang_toggle.dart';

class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key});

  static const _items = [
    ('Object straight ahead', 'One long buzz', Haptics.center),
    ('Object on your left', 'Two short buzzes', Haptics.left),
    ('Object on your right', 'Three short buzzes', Haptics.right),
    ('Vehicle close: stop', 'Rapid burst, then direction', Haptics.danger),
    ('Sudden loud sound', 'Three long buzzes', Haptics.sudden),
    ('Continuous loud sound (alarm, siren)', 'Five medium buzzes', Haptics.continuous),
    ('Gas or smoke', 'Three very long buzzes', Haptics.gas),
    ('Hot surface', 'Four quick buzzes', Haptics.hot),
    ('Emergency mode on', 'S-O-S rhythm', Haptics.sos),
    ('Gabay is open', 'Four quick pulses: braille "g"', Haptics.logo),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: AppState.I, builder: (context, _) => Scaffold(
      appBar: AppBar(actions: const [LangToggle()], title: Text(L('Practice'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(L('Tap a pattern to feel it. In Sight, faster repeats mean the object is closer.'),
              style: TextStyle(fontSize: 18)),
          const SizedBox(height: 16),
          for (final (meaning, name, pattern) in _items) ...[
            BigTile(
              title: meaning,
              subtitle: name,
              icon: Icons.vibration,
              onTap: () {
                Haptics.play(pattern);
                Output.speak(meaning, force: true);
              },
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    ));
  }
}
