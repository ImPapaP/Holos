import 'package:flutter/material.dart';

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
    final bg = danger ? HolosColors.danger : (selected ? const Color(0xFF2A2610) : HolosColors.card);
    final border = danger ? HolosColors.danger : (selected ? HolosColors.accent : HolosColors.line);
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: border, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 84),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 36, color: danger ? Colors.white : HolosColors.accent),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title,
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: danger ? Colors.white : HolosColors.ink)),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: TextStyle(fontSize: 16, color: danger ? Colors.white70 : HolosColors.mute)),
                      ],
                    ),
                  ),
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
        child: Text(text, style: const TextStyle(fontSize: 18, color: HolosColors.mute, fontWeight: FontWeight.w600)),
      );
}
