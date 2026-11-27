import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/haptics.dart';
import '../core/l10n.dart';
import '../core/output.dart';
import '../core/profiles.dart';
import '../core/theme.dart';
import '../modules/calm_screen.dart';
import '../modules/color_screen.dart';
import '../modules/nav_screen.dart';
import '../modules/peso_screen.dart';
import '../modules/read_screen.dart';
import '../modules/scene_screen.dart';
import '../modules/sensor_screen.dart';
import '../modules/sight_screen.dart';
import '../modules/sos_screen.dart';
import '../modules/sound_screen.dart';
import '../modules/sweep_screen.dart';
import '../modules/talk_screen.dart';
import '../modules/touch_screen.dart';
import '../services/voice_commands.dart';
import '../widgets/big_tile.dart';
import '../widgets/lang_toggle.dart';
import '../widgets/back_pill.dart';
import 'settings_screen.dart';

/// Home: big, simple choices. Simple mode shows only the user's modules as large squares;
/// SOS is always at the bottom of the screen, never hidden in a list.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    if (AppState.I.speakTaps) {
      Future.delayed(const Duration(milliseconds: 900), () {
        Output.speak(L('Home. Your modules are on screen. SOS is at the bottom. Settings is at the top right.'), force: true);
      });
    }
  }

  void _open(BuildContext context, Module m) {
    if (m == Module.sos) {
      SosScreen.trigger(reason: L('Manual SOS'));
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

  // Simple mode: a large square with one icon and one word.
  Widget _square(BuildContext context, Module m) {
    final info = modules[m]!;
    return Semantics(
      button: true,
      label: '${L(info.title)}. ${L(info.desc)}',
      excludeSemantics: true,
      child: Material(
        color: GabayColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: GabayColors.line, width: 3)),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            Haptics.play(const [25]);
            if (AppState.I.speakTaps) Output.speak(L(info.title), force: true);
            _open(context, m);
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(info.icon, size: 64, color: GabayColors.accent),
                const SizedBox(height: 10),
                Text(L(info.title),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: GabayColors.ink)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, Module m) {
    final info = modules[m]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BigTile(title: info.title, subtitle: info.desc, icon: info.icon, onTap: () => _open(context, m)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.I,
      builder: (context, _) {
        final state = AppState.I;
        final p = profiles[state.profile]!;
        final mine = p.recommended.where((m) => m != Module.sos).toList();
        final others = Module.values.where((m) => !p.recommended.contains(m) && m != Module.sos).toList();
        final simple = state.simpleHome && !_showAll;
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            titleSpacing: 12,
            title: const Row(mainAxisSize: MainAxisSize.min, children: [GabayLogo(size: 46), SizedBox(width: 12), Text('Gabay')]),
            actions: [
              const LangToggle(),
              IconButton(
                tooltip: L('Settings'),
                iconSize: 36,
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Text('${L('Profile')}: ${L(p.name)}', style: TextStyle(color: GabayColors.mute, fontSize: 17)),
              const SizedBox(height: 12),
              if (simple) ...[
                LayoutBuilder(builder: (context, box) {
                  // Two columns on phones; text size grows the squares instead of cutting the words.
                  final scale = MediaQuery.textScalerOf(context).scale(1);
                  return GridView.count(
                    crossAxisCount: box.maxWidth > 600 ? 3 : 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: (1.0 / scale).clamp(0.6, 1.0),
                    children: [for (final m in mine) _square(context, m)],
                  );
                }),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _showAll = true),
                  icon: const Icon(Icons.apps),
                  label: Text(L('More modules')),
                ),
              ] else ...[
                SectionLabel(L('Recommended for you')),
                for (final m in mine) _tile(context, m),
                SectionLabel(L('Other modules')),
                for (final m in others) _tile(context, m),
                if (state.simpleHome)
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _showAll = false),
                    icon: const Icon(Icons.grid_view),
                    label: Text(L('Show fewer')),
                  ),
              ],
              if (state.caregiverPhone.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Row(children: [
                    Icon(Icons.info_outline, color: GabayColors.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(L('Add a caregiver number in Settings so SOS can reach them.'), style: TextStyle(color: GabayColors.ink, fontSize: 17)),
                    ),
                  ]),
                ),
            ],
          ),
          // Always-visible bottom bar: voice command + SOS, both large and in the same place on every visit.
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(children: [
                SizedBox(
                  width: 96,
                  height: 84,
                  child: FilledButton(
                    style: FilledButton.styleFrom(padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
                    onPressed: () async {
                      final m = await VoiceCommands.listen();
                      if (m != null && context.mounted) _open(context, m);
                    },
                    child: Semantics(label: L('Voice command'), excludeSemantics: true, child: const Icon(Icons.mic, size: 44)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 84,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: GabayColors.danger,
                        foregroundColor: GabayColors.onDanger,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      ),
                      onPressed: () => _open(context, Module.sos),
                      icon: const Icon(Icons.sos, size: 40),
                      label: Text(L('SOS help'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}
