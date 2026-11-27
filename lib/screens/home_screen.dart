import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/profiles.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../modules/calm_screen.dart';
import '../modules/color_screen.dart';
import '../modules/nav_screen.dart';
import '../modules/peso_screen.dart';
import '../modules/scene_screen.dart';
import '../modules/read_screen.dart';
import '../modules/sensor_screen.dart';
import '../modules/sight_screen.dart';
import '../modules/sos_screen.dart';
import '../modules/sound_screen.dart';
import '../modules/sweep_screen.dart';
import '../modules/talk_screen.dart';
import '../modules/touch_screen.dart';
import '../widgets/big_tile.dart';
import 'settings_screen.dart';
import '../services/voice_commands.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _open(BuildContext context, Module m) {
    if (m == Module.sos) {
      SosScreen.trigger(reason: 'Manual SOS');
      return;
    }
    final Widget screen = switch (m) {
      Module.sight => const SightScreen(),
      Module.sweep => const SweepScreen(),
      Module.touch => const TouchScreen(),
      Module.read => const ReadScreen(),
      Module.scene => const SceneScreen(),
      Module.color => const ColorScreen(),
      Module.peso => const PesoScreen(),
      Module.nav => const NavScreen(),
      Module.sound => const SoundScreen(),
      Module.talk => const TalkScreen(),
      Module.calm => const CalmScreen(),
      Module.sensor => const SensorScreen(),
      Module.sos => const SizedBox.shrink(),
    };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Widget _tile(BuildContext context, Module m) {
    final info = modules[m]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BigTile(
        title: info.title,
        subtitle: info.desc,
        icon: info.icon,
        danger: m == Module.sos,
        onTap: () => _open(context, m),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.I;
    final p = profiles[state.profile]!;
    final others = Module.values.where((m) => !p.recommended.contains(m)).toList();
    return Scaffold(
      floatingActionButton: SizedBox(
        width: 88,
        height: 88,
        child: FloatingActionButton(
          tooltip: 'Voice command',
          backgroundColor: GabayColors.accent,
          foregroundColor: GabayColors.onAccent,
          onPressed: () async {
            final m = await VoiceCommands.listen();
            if (m != null && context.mounted) _open(context, m);
          },
          child: const Icon(Icons.mic, size: 44),
        ),
      ),
      appBar: AppBar(
        title: const Text('Gabay'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            iconSize: 32,
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Text('Profile: ${p.name} (${p.desc})', style: TextStyle(color: GabayColors.mute, fontSize: 16)),
          const SizedBox(height: 12),
          SegmentedButton<Lang>(
            segments: const [
              ButtonSegment(value: Lang.en, label: Text('English')),
              ButtonSegment(value: Lang.fil, label: Text('Filipino')),
            ],
            selected: {state.lang},
            onSelectionChanged: (s) => state.setLang(s.first),
          ),
          const SectionLabel('Recommended for you'),
          for (final m in p.recommended) _tile(context, m),
          const SectionLabel('Other modules'),
          for (final m in others) _tile(context, m),
          if (state.caregiverPhone.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Add a caregiver number in Settings so SOS can reach them.',
                  style: TextStyle(color: GabayColors.accent, fontSize: 16)),
            ),
        ],
      ),
    );
  }
}
