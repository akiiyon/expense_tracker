import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  late SharedPreferences _prefs;

  ThemeMode _themeMode = ThemeMode.system;
  bool _xpVoice = true;
  bool _smsEnabled = false;
  bool _smsAutoAdd = true;

  ThemeMode get themeMode => _themeMode;

  /// xp reads her replies out loud.
  bool get xpVoice => _xpVoice;

  /// Detect bank / UPI SMS and turn them into transactions.
  bool get smsEnabled => _smsEnabled;

  /// Add detected SMS transactions straight away instead of asking first.
  bool get smsAutoAdd => _smsAutoAdd;

  /// Messages older than this were already scanned (millis since epoch).
  int get smsLastScan => _prefs.getInt('sms_last_scan') ?? 0;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _themeMode = ThemeMode.values[_prefs.getInt('theme_mode') ?? ThemeMode.system.index];
    _xpVoice = _prefs.getBool('xp_voice') ?? true;
    _smsEnabled = _prefs.getBool('sms_enabled') ?? false;
    _smsAutoAdd = _prefs.getBool('sms_auto_add') ?? true;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _prefs.setInt('theme_mode', mode.index);
  }

  Future<void> setXpVoice(bool value) async {
    _xpVoice = value;
    notifyListeners();
    await _prefs.setBool('xp_voice', value);
  }

  Future<void> setSmsEnabled(bool value) async {
    _smsEnabled = value;
    notifyListeners();
    await _prefs.setBool('sms_enabled', value);
  }

  Future<void> setSmsAutoAdd(bool value) async {
    _smsAutoAdd = value;
    notifyListeners();
    await _prefs.setBool('sms_auto_add', value);
  }

  Future<void> setSmsLastScan(int millis) => _prefs.setInt('sms_last_scan', millis);
}
