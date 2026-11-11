import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../l10n/app_strings.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../services/user_service.dart';

/// Compact language menu (FR / EN / AR) — meant for the login screen and
/// app bars. Works without a signed-in user (choice stored on the device).
class LanguageMenuButton extends StatelessWidget {
  const LanguageMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LocaleProvider>();
    final current = provider.locale.languageCode;
    return PopupMenuButton<String>(
      tooltip: context.tr('lang.choose'),
      onSelected: (code) => _apply(context, code),
      itemBuilder: (_) => [
        for (final l in AppStrings.supportedLocales)
          PopupMenuItem(
            value: l.languageCode,
            child: Row(children: [
              Icon(
                l.languageCode == current
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Text(AppStrings.nativeNames[l.languageCode] ?? l.languageCode),
            ]),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.softFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.divider),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.language_rounded, size: 18, color: context.brand),
          const SizedBox(width: 6),
          Text(current.toUpperCase(),
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary)),
          Icon(Icons.arrow_drop_down_rounded, color: context.textSecondary),
        ]),
      ),
    );
  }
}

/// Card with the three languages — for the profile / settings screen.
/// Also saves the choice on the user profile so it follows the account
/// across devices (applied at login by [LanguageAccountSync]).
class LanguageSection extends StatelessWidget {
  const LanguageSection({super.key});

  @override
  Widget build(BuildContext context) {
    final current = context.watch<LocaleProvider>().locale.languageCode;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.divider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.language_rounded, size: 20, color: context.brand),
          const SizedBox(width: 8),
          Text(context.tr('lang.title'),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary)),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final l in AppStrings.supportedLocales)
            ChoiceChip(
              selected: current == l.languageCode,
              showCheckmark: false,
              label: Text(AppStrings.nativeNames[l.languageCode]!,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: current == l.languageCode
                          ? Colors.white
                          : context.textPrimary)),
              selectedColor: AppColors.primary,
              onSelected: (_) => _apply(context, l.languageCode),
            ),
        ]),
      ]),
    );
  }
}

Future<void> _apply(BuildContext context, String code) async {
  final locale = context.read<LocaleProvider>();
  final auth = context.read<AuthProvider>();
  await locale.setLocale(Locale(code));
  final user = auth.currentUser;
  if (user == null) return;
  try {
    await UserService().updateUserFields(user.uid, {'language': code});
    await auth.refreshCurrentUser();
  } catch (_) {
    // Non-critical: the device preference is already saved.
  }
}

/// Wrap the app (inside the providers) to apply the signed-in user's saved
/// language once per login.
class LanguageAccountSync extends StatefulWidget {
  final Widget child;
  const LanguageAccountSync({super.key, required this.child});

  @override
  State<LanguageAccountSync> createState() => _LanguageAccountSyncState();
}

class _LanguageAccountSyncState extends State<LanguageAccountSync> {
  String? _syncedUid;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    if (user == null) {
      _syncedUid = null;
    } else if (user.uid != _syncedUid) {
      _syncedUid = user.uid;
      final lang = user.language;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<LocaleProvider>().applyUserLanguage(lang);
        }
      });
    }
    return widget.child;
  }
}
