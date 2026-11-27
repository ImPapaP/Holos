import 'package:flutter/material.dart';

class GabayColors {
  static const bg = Color(0xFF0B0B0C);
  static const card = Color(0xFF1C1C1F);
  static const line = Color(0xFF2E2E33);
  static const ink = Color(0xFFF5F5F0);
  static const mute = Color(0xFFA3A39B);
  static const accent = Color(0xFFFFD23F);
  static const danger = Color(0xFFFF5A4E);
  static const ok = Color(0xFF5FD38D);
  static const calm = Color(0xFF3A6EA5);
}

/// High-contrast dark theme with large text and big touch targets.
ThemeData gabayTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: GabayColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: GabayColors.accent,
      onPrimary: Colors.black,
      secondary: GabayColors.accent,
      surface: GabayColors.card,
      error: GabayColors.danger,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: GabayColors.bg,
      foregroundColor: GabayColors.ink,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: GabayColors.accent),
    ),
    textTheme: base.textTheme.apply(bodyColor: GabayColors.ink, displayColor: GabayColors.ink, fontSizeFactor: 1.15),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(72),
        backgroundColor: GabayColors.accent,
        foregroundColor: Colors.black,
        textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(64),
        foregroundColor: GabayColors.ink,
        side: const BorderSide(color: GabayColors.line, width: 2),
        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: GabayColors.card,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
