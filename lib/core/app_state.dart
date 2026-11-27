import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'profiles.dart';
import 'strings.dart';
import 'theme.dart';

/// App-wide settings, saved on the phone.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState I = AppState._();

  late SharedPreferences _prefs;

  Profile? profile;
  Lang lang = Lang.en;
  String caregiverName = '';
  String caregiverPhone = '';
  bool fallDetection = false;
  double soundSensitivity = 0; // -15 (less sensitive) .. +15 (more sensitive)

  /// 'auto' or a palette id (night, contrast, day, cb, calm).
  String themeChoice = 'auto';

  /// Palette Auto mode picked from the light sensor at launch.
  String autoPick = 'night';

  GabayPalette get palette => GabayThemes.byId(themeChoice == 'auto' ? autoPick : themeChoice);

  Outputs get out => profiles[profile ?? Profile.loss]!.out;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs.getInt('profile');
    profile = (p == null || p >= Profile.values.length) ? null : Profile.values[p];
    lang = Lang.values[(_prefs.getInt('lang') ?? 0).clamp(0, Lang.values.length - 1)];
    S.lang = lang;
    caregiverName = _prefs.getString('cgName') ?? '';
    caregiverPhone = _prefs.getString('cgPhone') ?? '';
    fallDetection = _prefs.getBool('fall') ?? false;
    soundSensitivity = _prefs.getDouble('sens') ?? 0;
    themeChoice = _prefs.getString('theme') ?? 'auto';
    GabayThemes.current = palette;
  }

  void setAutoPick(String id) {
    autoPick = id;
    GabayThemes.current = palette;
    notifyListeners();
  }

  Future<void> setTheme(String choice) async {
    themeChoice = choice;
    GabayThemes.current = palette;
    await _prefs.setString('theme', choice);
    notifyListeners();
  }

  Future<void> setProfile(Profile? p) async {
    profile = p;
    if (p == null) {
      await _prefs.remove('profile');
    } else {
      await _prefs.setInt('profile', p.index);
    }
    notifyListeners();
  }

  Future<void> setLang(Lang l) async {
    lang = l;
    S.lang = l;
    await _prefs.setInt('lang', l.index);
    notifyListeners();
  }

  Future<void> setCaregiver(String name, String phone) async {
    caregiverName = name.trim();
    caregiverPhone = phone.trim();
    await _prefs.setString('cgName', caregiverName);
    await _prefs.setString('cgPhone', caregiverPhone);
    notifyListeners();
  }

  Future<void> setFallDetection(bool on) async {
    fallDetection = on;
    await _prefs.setBool('fall', on);
    notifyListeners();
  }

  Future<void> setSoundSensitivity(double v) async {
    soundSensitivity = v;
    await _prefs.setDouble('sens', v);
    notifyListeners();
  }
}
