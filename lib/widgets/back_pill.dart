import 'package:flutter/material.dart';

import '../core/haptics.dart';
import '../core/l10n.dart';
import '../core/theme.dart';

/// A large, labeled Back button (arrow + word) used on every screen.
/// Easier to find and hit than a small arrow icon, and it reads "Back" to TalkBack.
class BackPill extends StatelessWidget {
  final bool onCamera; // dark style over the camera view
  const BackPill({super.key, this.onCamera = false});

  @override
  Widget build(BuildContext context) {
    final fg = onCamera ? Colors.white : GabayColors.ink;
    return Semantics(
      button: true,
      label: L('Back'),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Material(
          color: onCamera ? Colors.black54 : GabayColors.card,
          shape: StadiumBorder(side: BorderSide(color: onCamera ? Colors.transparent : GabayColors.line, width: 2)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () {
              Haptics.play(const [30]);
              Navigator.of(context).maybePop();
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52, minWidth: 52),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 16, 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.arrow_back_rounded, size: 30, color: fg),
                  const SizedBox(width: 6),
                  Text(L('Back'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: fg)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Gabay mark (wheelchair figure moving forward).
class GabayLogo extends StatelessWidget {
  final double size;
  const GabayLogo({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Gabay',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.asset('assets/icon/gabay_icon.png', width: size, height: size, fit: BoxFit.cover),
      ),
    );
  }
}
