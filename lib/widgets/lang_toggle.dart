import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/haptics.dart';
import '../core/output.dart';
import '../core/strings.dart';
import '../core/theme.dart';

/// English | Tagalog switch, shown on every screen.
class LangToggle extends StatelessWidget {
  final bool onCamera; // dark pill style over the camera view
  const LangToggle({super.key, this.onCamera = false});

  @override
  Widget build(BuildContext context) {
    final tl = S.lang == Lang.fil;
    Widget seg(String text, bool on) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: on ? GabayColors.accent : Colors.transparent, borderRadius: BorderRadius.circular(99)),
          child: Text(text,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: on ? GabayColors.onAccent : (onCamera ? Colors.white : GabayColors.ink))),
        );
    return Semantics(
      button: true,
      label: tl ? 'Wika: Tagalog. Pindutin para mag-English.' : 'Language: English. Double tap to switch to Tagalog.',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Material(
          color: onCamera ? Colors.black54 : GabayColors.card,
          shape: StadiumBorder(side: BorderSide(color: onCamera ? Colors.transparent : GabayColors.line, width: 2)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () {
              final next = tl ? Lang.en : Lang.fil;
              AppState.I.setLang(next);
              Haptics.play(const [40]);
              Output.speak(next == Lang.fil ? 'Tagalog' : 'English', force: true);
            },
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Row(mainAxisSize: MainAxisSize.min, children: [seg('EN', !tl), seg('TL', tl)]),
            ),
          ),
        ),
      ),
    );
  }
}
