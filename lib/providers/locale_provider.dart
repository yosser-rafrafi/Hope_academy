import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';

/// Holds the UI language. Persisted locally so the choice survives restarts
/// (also applies on the login screen, before any user is loaded).
class LocaleProvider extends ChangeNotifier {
  static const _prefKey = 'app_locale';

  Locale _locale = AppStrings.fallbackLocale;
  Locale get locale => _locale;
  bool get isRtl => _locale.languageCode == 'ar';

  LocaleProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null) {
        _locale = AppStrings.resolve(saved);
      } else {
        // First launch: follow the device language when supported.
        _locale = AppStrings.resolve(
            WidgetsBinding.instance.platformDispatcher.locale.languageCode);
      }
      notifyListeners();
    } catch (_) {
      // keep the default locale
    }
  }

  Future<void> setLocale(Locale locale) async {
    final next = AppStrings.resolve(locale.languageCode);
    if (next == _locale) return;
    _locale = next;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, next.languageCode);
    } catch (_) {}
  }

  /// Apply the language stored on the user profile (UserModel.language).
  void applyUserLanguage(String? code) {
    if (code == null || code.isEmpty) return;
    final next = AppStrings.resolve(code);
    if (next != _locale) {
      _locale = next;
      notifyListeners();
    }
  }
}
