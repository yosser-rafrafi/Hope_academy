import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/widgets.dart';

import 'strings_ar.dart';
import 'strings_en.dart';
import 'strings_fr.dart';

/// Lightweight, code-generation-free localisation (fr / en / ar).
///
/// Usage in a widget:      `context.tr('pei.title')`
/// With placeholders:      `context.tr('abs.count', args: {'n': '3'})`
/// Outside a widget (PDF): `AppStrings(const Locale('ar')).t('pei.title')`
///
/// Lookup order: current language → English → French → the key itself
/// (a missing translation is visible but never crashes the app).
class AppStrings {
  final Locale locale;
  const AppStrings(this.locale);

  static const supportedLocales = <Locale>[
    Locale('fr'),
    Locale('en'),
    Locale('ar'),
  ];

  static const fallbackLocale = Locale('fr');

  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();

  static const _tables = <String, Map<String, String>>{
    'fr': stringsFr,
    'en': stringsEn,
    'ar': stringsAr,
  };

  /// Native names, always displayed in their own language.
  static const nativeNames = <String, String>{
    'fr': 'Français',
    'en': 'English',
    'ar': 'العربية',
  };

  bool get isRtl => locale.languageCode == 'ar';

  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings) ??
      const AppStrings(fallbackLocale);

  String t(String key, {Map<String, Object?>? args}) {
    var text = _tables[locale.languageCode]?[key] ??
        stringsEn[key] ??
        stringsFr[key] ??
        key;
    if (args != null) {
      args.forEach((k, v) => text = text.replaceAll('{$k}', '${v ?? ''}'));
    }
    return text;
  }

  /// Picks the closest supported locale for a language code (e.g. "ar_EG").
  static Locale resolve(String? code) {
    final lang = (code ?? '').split(RegExp('[-_]')).first.toLowerCase();
    return supportedLocales.firstWhere(
      (l) => l.languageCode == lang,
      orElse: () => fallbackLocale,
    );
  }
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) => AppStrings.supportedLocales
      .any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppStrings> load(Locale locale) =>
      SynchronousFuture(AppStrings(AppStrings.resolve(locale.languageCode)));

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppStrings> old) => false;
}

extension AppStringsContext on BuildContext {
  AppStrings get strings => AppStrings.of(this);

  /// Translate [key] for the current locale.
  String tr(String key, {Map<String, Object?>? args}) =>
      AppStrings.of(this).t(key, args: args);
}
