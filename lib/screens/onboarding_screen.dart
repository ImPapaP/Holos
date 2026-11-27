import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/haptics.dart';
import '../core/profiles.dart';
import '../core/theme.dart';
import '../widgets/big_tile.dart';
import '../core/l10n.dart';
import '../widgets/lang_toggle.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: AppState.I, builder: (context, _) => Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(children: [
              Expanded(
                child: Text('Gabay', style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: GabayColors.accent, height: 1)),
              ),
              const LangToggle(),
            ]),
            const SizedBox(height: 10),
            Text(L('One app for every sense. Choose the profile that fits you. You can change it later in Settings.'),
                style: TextStyle(fontSize: 18, color: GabayColors.mute)),
            const SizedBox(height: 20),
            for (final entry in profiles.entries) ...[
              BigTile(
                title: entry.value.name,
                subtitle: entry.value.desc,
                onTap: () {
                  Haptics.play(Haptics.start);
                  AppState.I.setProfile(entry.key);
                },
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    ));
  }
}
