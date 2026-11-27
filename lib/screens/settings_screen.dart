import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/haptics.dart';
import '../core/output.dart';
import '../core/theme.dart';
import '../engines/detector.dart';
import '../engines/classifier.dart';
import '../engines/sound_classifier.dart';
import '../services/test_log.dart';
import '../widgets/big_tile.dart';
import 'practice_screen.dart';
import '../core/l10n.dart';
import '../widgets/lang_toggle.dart';
import '../widgets/back_pill.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _name = TextEditingController(text: AppState.I.caregiverName);
  late final TextEditingController _phone = TextEditingController(text: AppState.I.caregiverPhone);
  late final TextEditingController _key = TextEditingController(text: AppState.I.geminiKey);
  late final TextEditingController _model = TextEditingController(text: AppState.I.geminiModel);

  void _pickTheme(BuildContext context, String id, String name) {
    Haptics.play(Haptics.start);
    Output.speak('Theme: $name', force: true);
    AppState.I.setTheme(id);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppState.I;
    return ListenableBuilder(listenable: AppState.I, builder: (context, _) => Scaffold(
      appBar: AppBar(leading: const BackPill(), leadingWidth: 132, actions: const [LangToggle()], title: Text(L('Settings'))),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SectionLabel(L('Display and feedback')),
            Text(L('Text size'), style: TextStyle(fontSize: 18, color: GabayColors.ink, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SegmentedButton<double>(
              showSelectedIcon: false,
              segments: [
                for (final (v, label, size) in const [(1.0, 'Normal', 18.0), (1.15, 'Large', 21.0), (1.35, 'Larger', 24.0), (1.6, 'Largest', 27.0)])
                  ButtonSegment(value: v, label: Text('A', style: TextStyle(fontSize: size, fontWeight: FontWeight.w900)), tooltip: L(label)),
              ],
              selected: {s.textScale},
              onSelectionChanged: (v) {
                s.setTextScale(v.first);
                Output.speak(L('Text size changed'), force: true);
              },
            ),
            const SizedBox(height: 6),
            Text(L('Sample text: Gabay guides you through touch and sound.'), style: TextStyle(fontSize: 18, color: GabayColors.mute)),
            SwitchListTile(
              value: s.simpleHome,
              onChanged: (v) => s.setFlag('simpleHome', v),
              title: Text(L('Simple home screen'), style: const TextStyle(fontSize: 20)),
              subtitle: Text(L('Shows only your modules as big buttons. The rest are under "More modules".'), style: TextStyle(color: GabayColors.mute)),
            ),
            SwitchListTile(
              value: s.speakTaps,
              onChanged: (v) => s.setFlag('speakTaps', v),
              title: Text(L('Speak buttons when tapped'), style: const TextStyle(fontSize: 20)),
              subtitle: Text(L('Says the name of each button you press. Helpful for low vision if you do not use TalkBack.'), style: TextStyle(color: GabayColors.mute)),
            ),
            SectionLabel(L('Caregiver (for SOS)')),
            TextField(controller: _name, decoration: InputDecoration(labelText: L('Caregiver name'))),
            const SizedBox(height: 10),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: L('Caregiver mobile number'), hintText: '09XXXXXXXXX'),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () {
                s.setCaregiver(_name.text, _phone.text);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L('Caregiver saved'))));
              },
              child: Text(L('Save caregiver')),
            ),
            SectionLabel(L('Safety')),
            SwitchListTile(
              value: s.fallDetection,
              onChanged: s.setFallDetection,
              title: Text(L('Fall detection'), style: TextStyle(fontSize: 20)),
              subtitle: Text(L('Starts SOS if the phone detects a hard fall while Gabay is open'),
                  style: TextStyle(color: GabayColors.mute)),
            ),
            SectionLabel(L('Appearance')),
            Text(L('Each theme serves a need. Alerts always use color plus an icon, text and vibration.'),
                style: TextStyle(color: GabayColors.mute, fontSize: 16)),
            const SizedBox(height: 10),
            BigTile(
              title: L('Auto'),
              subtitle: L('Uses the light sensor when Gabay opens: Daylight outdoors, Gabay Night indoors'),
              icon: Icons.brightness_auto,
              selected: s.themeChoice == 'auto',
              onTap: () => _pickTheme(context, 'auto', L('Auto')),
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
            SectionLabel(L('Learn')),
            BigTile(
              title: L('Practice vibration patterns'),
              subtitle: L('Feel what each alert means'),
              icon: Icons.school,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PracticeScreen())),
            ),
            SectionLabel(L('AI engines')),
            Text('Object detection: ${Detector.I.status}\nCustom street model: ${Detector.custom.status}\nSound recognition: ${SoundClassifier.I.status}\nPeso reader: ${ImageClassifier.peso.status}\nText reading: Google ML Kit (on device)',
                style: TextStyle(color: GabayColors.mute, fontSize: 16, height: 1.5)),
            SwitchListTile(
              value: s.speedBoost,
              onChanged: (v) => s.setFlag('speedBoost', v),
              title: Text(L('Speed boost'), style: TextStyle(fontSize: 20)),
              subtitle: Text("Uses the phone's AI chip (NNAPI) if it has one. Applies the next time Gabay opens.", style: TextStyle(color: GabayColors.mute)),
            ),
            SwitchListTile(
              value: s.offlineCaptions,
              onChanged: (v) => s.setFlag('offlineCaptions', v),
              title: Text(L('Offline captions and voice commands'), style: TextStyle(fontSize: 20)),
              subtitle: Text(L('Uses on-device speech recognition when the phone supports it (Android 13+, language pack installed).'), style: TextStyle(color: GabayColors.mute)),
            ),
            SectionLabel(L('Scene description (Ilarawan)')),
            Text(L('Ilarawan works offline on your phone. No key or account needed.'), style: TextStyle(color: GabayColors.mute, fontSize: 16)),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(L('Optional: more detail online (advanced)'), style: const TextStyle(fontSize: 18)),
              children: [
                Text(L('Adds a "More detail" button that sends the photo to Google Gemini. Needs internet and a free key from aistudio.google.com.'),
                    style: TextStyle(color: GabayColors.mute, fontSize: 15)),
                const SizedBox(height: 8),
                TextField(controller: _key, obscureText: true, decoration: InputDecoration(labelText: L('Gemini API key'))),
                const SizedBox(height: 8),
                TextField(controller: _model, decoration: InputDecoration(labelText: L('Model name'), hintText: 'gemini-2.5-flash')),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () {
                    s.setGemini(_key.text, _model.text);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L('Scene description settings saved'))));
                  },
                  child: Text(L('Save key')),
                ),
                const SizedBox(height: 8),
              ],
            ),
            SectionLabel(L('Testing mode (for evaluation)')),
            SwitchListTile(
              value: s.testMode,
              onChanged: (v) => s.setFlag('testMode', v),
              title: Text(L('Testing mode'), style: TextStyle(fontSize: 20)),
              subtitle: Text(L('Logs every alert with time and confidence, and shows Correct / Wrong buttons for the tester.'), style: TextStyle(color: GabayColors.mute)),
            ),
            if (s.testMode) ...[
              Text(TestLog.I.summary(), style: TextStyle(fontSize: 16, color: GabayColors.ink, height: 1.5)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: FilledButton.icon(onPressed: TestLog.I.share, icon: const Icon(Icons.ios_share), label: Text(L('Export log')))),
                const SizedBox(width: 10),
                SizedBox(width: 120, child: OutlinedButton(onPressed: () => TestLog.I.clear().then((_) => setState(() {})), child: Text(L('Clear')))),
              ]),
            ],
            SectionLabel(L('Profile')),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).popUntil((r) => r.isFirst);
                s.setProfile(null);
              },
              child: Text(L('Change profile')),
            ),
          ],
        ),
      ),
    ));
  }
}
