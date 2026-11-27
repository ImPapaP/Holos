import 'package:flutter/material.dart';

/// One Gabay theme. Every theme exists for a specific need.
class GabayPalette {
  final String id;
  final String name;
  final String purpose;
  final bool dark;
  final bool still; // no animation / flashing (Calm)
  final Color bg, card, line, ink, mute, accent, onAccent, danger, onDanger, ok, selected;

  const GabayPalette({
    required this.id,
    required this.name,
    required this.purpose,
    required this.dark,
    this.still = false,
    required this.bg,
    required this.card,
    required this.line,
    required this.ink,
    required this.mute,
    required this.accent,
    required this.onAccent,
    required this.danger,
    required this.onDanger,
    required this.ok,
    required this.selected,
  });
}

class GabayThemes {
  static const night = GabayPalette(
    id: 'night',
    name: 'Gabay Night',
    purpose: 'Yellow on black for visibility. Saves battery on long walks.',
    dark: true,
    bg: Color(0xFF0E1116),
    card: Color(0xFF1A1F27),
    line: Color(0xFF2C333E),
    ink: Color(0xFFF4F1EA),
    mute: Color(0xFFA9B0BA),
    accent: Color(0xFFF5C542),
    onAccent: Color(0xFF14110A),
    danger: Color(0xFFC62F35),
    onDanger: Color(0xFFFFFFFF),
    ok: Color(0xFF5FD38D),
    selected: Color(0xFF2A2610),
  );

  static const contrast = GabayPalette(
    id: 'contrast',
    name: 'High Contrast',
    purpose: 'Strongest contrast, no gray text. For low vision.',
    dark: true,
    bg: Color(0xFF000000),
    card: Color(0xFF000000),
    line: Color(0xFFFFFFFF),
    ink: Color(0xFFFFFFFF),
    mute: Color(0xFFFFFFFF),
    accent: Color(0xFFFFE14D),
    onAccent: Color(0xFF000000),
    danger: Color(0xFFFF5A5A),
    onDanger: Color(0xFF000000),
    ok: Color(0xFF7CFF9B),
    selected: Color(0xFF332D00),
  );

  static const day = GabayPalette(
    id: 'day',
    name: 'Daylight',
    purpose: 'Readable in direct sunlight outdoors.',
    dark: false,
    bg: Color(0xFFF6F4EF),
    card: Color(0xFFFFFFFF),
    line: Color(0xFFD9D5CC),
    ink: Color(0xFF15171A),
    mute: Color(0xFF5A5F66),
    accent: Color(0xFF1F5FD6),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFC62F35),
    onDanger: Color(0xFFFFFFFF),
    ok: Color(0xFF1E7A46),
    selected: Color(0xFFE3ECFB),
  );

  static const colorblind = GabayPalette(
    id: 'cb',
    name: 'Colorblind-safe',
    purpose: 'Blue and orange instead of red and green.',
    dark: true,
    bg: Color(0xFF101418),
    card: Color(0xFF1B222A),
    line: Color(0xFF33404D),
    ink: Color(0xFFF2F4F7),
    mute: Color(0xFFAEB7C2),
    accent: Color(0xFF4DA3FF),
    onAccent: Color(0xFF04121F),
    danger: Color(0xFFF28C28),
    onDanger: Color(0xFF1A0D00),
    ok: Color(0xFF4DA3FF),
    selected: Color(0xFF13283F),
  );

  static const calm = GabayPalette(
    id: 'calm',
    name: 'Calm',
    purpose: 'Soft colors, no flashing. For sensory-sensitive users.',
    dark: false,
    still: true,
    bg: Color(0xFFEEF2EF),
    card: Color(0xFFFFFFFF),
    line: Color(0xFFD3DCD6),
    ink: Color(0xFF22302A),
    mute: Color(0xFF55655D),
    accent: Color(0xFF4F7A68),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFA8443E),
    onDanger: Color(0xFFFFFFFF),
    ok: Color(0xFF4F7A68),
    selected: Color(0xFFDDE9E2),
  );

  static const all = [night, contrast, day, colorblind, calm];

  static GabayPalette byId(String id) => all.firstWhere((p) => p.id == id, orElse: () => night);

  /// The palette in use right now (set by AppState).
  static GabayPalette current = night;
}

/// Shortcuts to the current palette's colors.
class GabayColors {
  static Color get bg => GabayThemes.current.bg;
  static Color get card => GabayThemes.current.card;
  static Color get line => GabayThemes.current.line;
  static Color get ink => GabayThemes.current.ink;
  static Color get mute => GabayThemes.current.mute;
  static Color get accent => GabayThemes.current.accent;
  static Color get onAccent => GabayThemes.current.onAccent;
  static Color get danger => GabayThemes.current.danger;
  static Color get onDanger => GabayThemes.current.onDanger;
  static Color get ok => GabayThemes.current.ok;
  static Color get selected => GabayThemes.current.selected;
  static Color get calm => GabayThemes.current.accent;
}

/// Theme with large text and big touch targets, built from a palette.
ThemeData gabayTheme(GabayPalette p) {
  final base = (p.dark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true)).copyWith(
    // Atkinson Hyperlegible: made for low-vision readers (falls back to the system font if missing).
    textTheme: (p.dark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true)).textTheme.apply(fontFamily: 'Atkinson'),
  );
  final scheme = p.dark
      ? ColorScheme.dark(primary: p.accent, onPrimary: p.onAccent, secondary: p.accent, surface: p.card, onSurface: p.ink, error: p.danger)
      : ColorScheme.light(primary: p.accent, onPrimary: p.onAccent, secondary: p.accent, surface: p.card, onSurface: p.ink, error: p.danger);
  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    colorScheme: scheme,
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.ink,
      centerTitle: false,
      toolbarHeight: 72,
      iconTheme: IconThemeData(size: 32, color: p.ink),
      titleTextStyle: TextStyle(fontFamily: 'Atkinson', fontSize: 26, fontWeight: FontWeight.w800, color: p.accent),
    ),
    // Big, easy-to-grab controls everywhere.
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.comfortable,
    iconTheme: IconThemeData(size: 30, color: p.ink),
    focusColor: p.accent.withAlpha(90),
    sliderTheme: SliderThemeData(
      trackHeight: 10,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 16),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 30),
      activeTrackColor: p.accent,
      inactiveTrackColor: p.line,
      thumbColor: p.accent,
      valueIndicatorTextStyle: TextStyle(fontSize: 20, color: p.onAccent),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.onAccent : p.mute),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.accent : p.card),
      trackOutlineColor: WidgetStateProperty.all(p.line),
    ),
    listTileTheme: ListTileThemeData(minVerticalPadding: 14, textColor: p.ink, iconColor: p.ink),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(minimumSize: const Size(64, 56), textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
    ),
    snackBarTheme: SnackBarThemeData(contentTextStyle: TextStyle(fontSize: 18, color: p.onAccent), backgroundColor: p.accent),
    dialogTheme: DialogThemeData(
      backgroundColor: p.card,
      titleTextStyle: TextStyle(fontFamily: 'Atkinson', fontSize: 26, fontWeight: FontWeight.w800, color: p.ink),
      contentTextStyle: TextStyle(fontFamily: 'Atkinson', fontSize: 20, color: p.ink),
    ),
    textTheme: base.textTheme.apply(bodyColor: p.ink, displayColor: p.ink, fontSizeFactor: 1.15, fontFamily: 'Atkinson'),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(72),
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        textStyle: const TextStyle(fontFamily: 'Atkinson', fontSize: 22, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(64),
        foregroundColor: p.ink,
        side: BorderSide(color: p.line, width: 2),
        textStyle: const TextStyle(fontFamily: 'Atkinson', fontSize: 20, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.card,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: p.line, width: 2)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: p.accent, width: 3)),
      labelStyle: TextStyle(fontSize: 20, color: p.mute),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
    ),
  );
}
