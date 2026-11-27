import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/haptics.dart';
import '../services/test_log.dart';
import '../core/l10n.dart';

/// Shown only in testing mode: lets a sighted tester mark the last alert correct or wrong.
class VerdictBar extends StatelessWidget {
  const VerdictBar({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AppState.I.testMode) return const SizedBox.shrink();
    Widget btn(String label, IconData icon, Color color, bool ok) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(52)),
              onPressed: () {
                TestLog.I.verdict(ok);
                Haptics.play(const [40]);
              },
              icon: Icon(icon),
              label: Text(label, style: const TextStyle(fontSize: 17)),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        btn(L('Correct'), Icons.check, const Color(0xFF1E7A46), true),
        btn(L('Wrong'), Icons.close, const Color(0xFFB3261E), false),
      ]),
    );
  }
}
