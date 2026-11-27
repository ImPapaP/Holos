import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/haptics.dart';
import '../core/profiles.dart';
import '../core/theme.dart';
import '../widgets/big_tile.dart';
import '../core/l10n.dart';
import '../widgets/lang_toggle.dart';
import '../widgets/back_pill.dart';
import '../core/output.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  @override
  void initState() {
    super.initState();
    // Blind users hear what to do before they can see anything.
    Future.delayed(const Duration(milliseconds: 1200), () {
      Output.speak(L('Welcome to Gabay. Choose your profile. Options: blind or low vision, deaf or hard of hearing, deafblind, sensory sensitive, lost smell or touch. The language button is at the top right.'), force: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: AppState.I, builder: (context, _) => Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Center(child: GabayLogo(size: 120)),
            const SizedBox(height: 16),
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
                icon: switch (entry.key) {
                  Profile.blind => Icons.visibility_off,
                  Profile.deaf => Icons.hearing_disabled,
                  Profile.deafblind => Icons.back_hand,
                  Profile.neuro => Icons.self_improvement,
                  Profile.loss => Icons.sensors,
                },
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
