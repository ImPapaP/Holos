import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/haptics.dart';
import '../core/output.dart';
import '../core/theme.dart';
import '../widgets/big_tile.dart';
import 'practice_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _name = TextEditingController(text: AppState.I.caregiverName);
  late final TextEditingController _phone = TextEditingController(text: AppState.I.caregiverPhone);

  void _pickTheme(BuildContext context, String id, String name) {
    Haptics.play(Haptics.start);
    Output.speak('Theme: $name', force: true);
    AppState.I.setTheme(id);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SectionLabel('Caregiver (for SOS)'),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Caregiver name')),
            const SizedBox(height: 10),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Caregiver mobile number', hintText: '09XXXXXXXXX'),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () {
                s.setCaregiver(_name.text, _phone.text);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Caregiver saved')));
              },
              child: const Text('Save caregiver'),
            ),
            const SectionLabel('Safety'),
            SwitchListTile(
              value: s.fallDetection,
              onChanged: s.setFallDetection,
              title: const Text('Fall detection', style: TextStyle(fontSize: 20)),
              subtitle: Text('Starts SOS if the phone detects a hard fall while Gabay is open',
                  style: TextStyle(color: GabayColors.mute)),
            ),
            const SectionLabel('Appearance'),
            Text('Each theme serves a need. Alerts always use color plus an icon, text and vibration.',
                style: TextStyle(color: GabayColors.mute, fontSize: 16)),
            const SizedBox(height: 10),
            BigTile(
              title: 'Auto',
              subtitle: 'Uses the light sensor when Gabay opens: Daylight outdoors, Gabay Night indoors',
              icon: Icons.brightness_auto,
              selected: s.themeChoice == 'auto',
              onTap: () => _pickTheme(context, 'auto', 'Auto'),
            ),
            for (final t in GabayThemes.all) ...[
              const SizedBox(height: 10),
              BigTile(
                title: t.name,
                subtitle: t.purpose,
                icon: Icons.palette_outlined,
                selected: s.themeChoice == t.id,
                onTap: () => _pickTheme(context, t.id, t.name),
              ),
            ],
            const SectionLabel('Learn'),
            BigTile(
              title: 'Practice vibration patterns',
              subtitle: 'Feel what each alert means',
              icon: Icons.school,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PracticeScreen())),
            ),
            const SectionLabel('Profile'),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).popUntil((r) => r.isFirst);
                s.setProfile(null);
              },
              child: const Text('Change profile'),
            ),
          ],
        ),
      ),
    );
  }
}
