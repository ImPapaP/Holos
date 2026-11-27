import 'dart:convert';

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

  bool testMode = false;
  double textScale = 1.15; // 1.0 normal, 1.15 large, 1.35 larger, 1.6 largest
  bool simpleHome = true;
  bool speakTaps = false;
  bool speedBoost = false;
  bool offlineCaptions = false;
  String geminiKey = '';
  String geminiModel = 'gemini-2.5-flash';
  List<SavedPlace> places = [];

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
    testMode = _prefs.getBool('testMode') ?? false;
    textScale = _prefs.getDouble('textScale') ?? 1.15;
    simpleHome = _prefs.getBool('simpleHome') ?? true;
    speakTaps = _prefs.getBool('speakTaps') ?? (profile == Profile.blind);
    speedBoost = _prefs.getBool('speedBoost') ?? false;
    offlineCaptions = _prefs.getBool('offlineCaptions') ?? false;
    geminiKey = _prefs.getString('geminiKey') ?? '';
    geminiModel = _prefs.getString('geminiModel') ?? 'gemini-2.5-flash';
    try {
      places = (jsonDecode(_prefs.getString('places') ?? '[]') as List).map((e) => SavedPlace.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      places = [];
    }
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

  Future<void> setFlag(String key, bool v) async {
    switch (key) {
      case 'testMode':
        testMode = v;
      case 'speedBoost':
        speedBoost = v;
      case 'offlineCaptions':
        offlineCaptions = v;
      case 'simpleHome':
        simpleHome = v;
      case 'speakTaps':
        speakTaps = v;
    }
    await _prefs.setBool(key, v);
    notifyListeners();
  }

  Future<void> setTextScale(double v) async {
    textScale = v;
    await _prefs.setDouble('textScale', v);
    notifyListeners();
  }

  Future<void> setGemini(String key, String model) async {
    geminiKey = key.trim();
    geminiModel = model.trim().isEmpty ? 'gemini-2.5-flash' : model.trim();
    await _prefs.setString('geminiKey', geminiKey);
    await _prefs.setString('geminiModel', geminiModel);
    notifyListeners();
  }

  Future<void> savePlaces(List<SavedPlace> list) async {
    places = list;
    await _prefs.setString('places', jsonEncode(list.map((p) => p.toJson()).toList()));
    notifyListeners();
  }
}

class SavedPlace {
  final String name;
  final double lat, lon;
  const SavedPlace(this.name, this.lat, this.lon);
  Map<String, dynamic> toJson() => {'name': name, 'lat': lat, 'lon': lon};
  factory SavedPlace.fromJson(Map<String, dynamic> j) => SavedPlace(j['name'] as String, (j['lat'] as num).toDouble(), (j['lon'] as num).toDouble());
}
