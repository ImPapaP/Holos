import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_state.dart';
import 'core/output.dart';
import 'core/theme.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/fall_detector.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await AppState.I.load();
  await Output.init();
  FallDetector.I.sync();
  AppState.I.addListener(FallDetector.I.sync);
  runApp(const GabayApp());
}

class GabayApp extends StatelessWidget {
  const GabayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gabay',
      debugShowCheckedModeBanner: false,
      navigatorKey: navKey,
      theme: gabayTheme(),
      home: ListenableBuilder(
        listenable: AppState.I,
        builder: (context, _) =>
            AppState.I.profile == null ? const OnboardingScreen() : const HomeScreen(),
      ),
    );
  }
}
