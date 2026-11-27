import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_state.dart';
import 'core/haptics.dart';
import 'core/output.dart';
import 'core/theme.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/auto_theme.dart';
import 'services/fall_detector.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await AppState.I.load();
  await Output.init();
  FallDetector.I.sync();
  AppState.I.addListener(FallDetector.I.sync);
  runApp(const GabayApp());

  // Haptic logo: the braille "g" (four dots) as four pulses, so blind users feel that Gabay opened.
  Haptics.play(Haptics.logo);
  Output.speak('Gabay');
  AutoTheme.pick();
}

class GabayApp extends StatelessWidget {
  const GabayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.I,
      builder: (context, _) {
        final p = AppState.I.palette;
        GabayThemes.current = p;
        return MaterialApp(
          // A new key rebuilds every screen with the new colors when the theme changes.
          key: ValueKey(p.id),
          title: 'Gabay',
          debugShowCheckedModeBanner: false,
          navigatorKey: navKey,
          theme: gabayTheme(p),
          // Calm theme: turn off animations across the app.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: p.still || MediaQuery.of(context).disableAnimations),
            child: child!,
          ),
          home: AppState.I.profile == null ? const OnboardingScreen() : const HomeScreen(),
        );
      },
    );
  }
}
