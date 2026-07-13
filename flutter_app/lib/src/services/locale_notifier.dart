import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleNotifier extends ChangeNotifier {
  LocaleNotifier._();

  static final LocaleNotifier instance = LocaleNotifier._();

  static const _localeKey = 'app_locale';
  static const supportedCodes = ['en', 'ta'];

  Locale? _locale;

  Locale? get locale => _locale;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localeKey);
    if (code != null && supportedCodes.contains(code)) {
      _locale = Locale(code);
      notifyListeners();
    }
  }

  Future<void> setLocale(String code) async {
    if (!supportedCodes.contains(code)) return;
    _locale = Locale(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, code);
    notifyListeners();
  }
}
