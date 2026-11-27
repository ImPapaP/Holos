import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/haptics.dart';
import '../core/l10n.dart';
import '../core/output.dart';
import '../core/theme.dart';

/// Large, screen-reader friendly button used across the app.
class BigTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData? icon;
  final VoidCallback onTap;
  final bool danger;
  final bool selected;

  const BigTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.icon,
    this.danger = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = danger ? GabayColors.danger : (selected ? GabayColors.selected : GabayColors.card);
    final border = danger ? GabayColors.danger : (selected ? GabayColors.accent : GabayColors.line);
    return Semantics(
      button: true,
      label: '${L(title)}. ${L(subtitle)}',
      selected: selected,
      excludeSemantics: true,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border, width: selected ? 4 : 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            // Every tap is felt, and spoken for users who turned on "Speak buttons".
            Haptics.play(const [25]);
            if (AppState.I.speakTaps) Output.speak(L(title), force: true);
            onTap();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 96),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 40, color: danger ? GabayColors.onDanger : GabayColors.accent),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(L(title),
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: danger ? GabayColors.onDanger : GabayColors.ink)),
                        const SizedBox(height: 2),
                        Text(L(subtitle),
                            style: TextStyle(fontSize: 17, height: 1.3, color: danger ? GabayColors.onDanger : GabayColors.mute)),
                      ],
                    ),
                  ),
                  // Selected is shown with a check mark, not by color alone.
                  if (selected) Icon(Icons.check_circle, size: 34, color: GabayColors.accent)
                  else Icon(Icons.chevron_right, size: 34, color: danger ? GabayColors.onDanger : GabayColors.mute),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(L(text), style: TextStyle(fontSize: 18, color: GabayColors.mute, fontWeight: FontWeight.w600)),
      );
}
