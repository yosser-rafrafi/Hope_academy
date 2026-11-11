import 'package:flutter/material.dart';

class AppColors {
  // Primary palette
  static const Color primary = Color(0xFF354463);      // Deep Blue
  static const Color primaryLight = Color(0xFF4A6FA5);
  static const Color secondary = Color(0xFFC1F7D5);    // Soft Teal
  static const Color accent = Color(0xFFFDCE77);       // Warm Orange
  static const Color success = Color(0xFF0D9546);      // Soft Green

  // Backgrounds - Light
  static const Color background = Color(0xFFFFFFFF);
  static const Color backgroundLight = Color(0xFFF7F9FC);
  static const Color surfaceCard = Color(0xFFFFFFFF);

  // Backgrounds - Dark
  static const Color darkBackground = Color(0xFF121824);
  static const Color darkSurface = Color(0xFF1E2638);
  static const Color darkSurfaceCard = Color(0xFF263047);
  static const Color darkDivider = Color(0xFF2D3850);

  // Text Light Mode
  static const Color textPrimary = Color(0xFF2C3E50);
  static const Color textSecondary = Color(0xFF6C757D);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Text Dark Mode
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  // Role colors
  static const Color adminColor = Color(0xFF354463);
  static const Color subAdminColor = Color(0xFF8B5CF6); // Violet — was hardcoded inline in role_badge.dart only
  static const Color teacherColor = Color(0xFF0D9546);
  static const Color parentColor = Color(0xFFFDCE77);

  // Absence-type semantic colors — kept together so every screen/badge that
  // renders an AbsenceType uses the same mapping instead of re-deriving it
  // (student_absences_screen, absence_management_screen and absence_badge
  // previously each picked colors independently).
  static const Color absenceExcused = success;
  static const Color absenceUnexcused = error;
  static const Color absenceSick = warning;
  static const Color absenceAuthorized = info;

  // Status
  static const Color error = Color(0xFFE74C3C);
  static const Color warning = Color(0xFFF39C12);
  static const Color info = Color(0xFF0077B6);
  static const Color divider = Color(0xFFE8EDF2);

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF354463), Color(0xFF4A6FA5)],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E2638), Color(0xFF263047)],
  );

  // ── Playful palette (kids UI) ──────────────────────────────────────────────
  static const Color sky = Color(0xFF4FC3F7);
  static const Color sun = Color(0xFFFFC857);
  static const Color mint = Color(0xFF5ED8A9);
  static const Color coral = Color(0xFFFF7A7A);
  static const Color grape = Color(0xFF9B7BFF);
  static const Color bubblegum = Color(0xFFFF8FC7);

  static const LinearGradient skyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4FC3F7), Color(0xFF6C8CFF)],
  );
  static const LinearGradient sunGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFC857), Color(0xFFFF9F68)],
  );
  static const LinearGradient mintGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5ED8A9), Color(0xFF3BB6C9)],
  );
  static const LinearGradient grapeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9B7BFF), Color(0xFFFF8FC7)],
  );
}

/// Theme-aware colours. ALWAYS use these (instead of the static light-only
/// `AppColors.textPrimary`, `AppColors.divider`, `Colors.white` …) for text,
/// card backgrounds and borders so light & dark mode both stay readable.
extension AppThemeContext on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Main text colour.
  Color get textPrimary =>
      isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;

  /// Secondary / hint text colour.
  Color get textSecondary =>
      isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

  /// Card / sheet / dialog background.
  Color get cardBg => isDark ? AppColors.darkSurfaceCard : AppColors.surfaceCard;

  /// Page background (scaffold).
  Color get pageBg => isDark ? AppColors.darkBackground : AppColors.backgroundLight;

  /// Plain surface (inputs, app bars, bottom bars).
  Color get surfaceBg => isDark ? AppColors.darkSurface : AppColors.background;

  /// Subtle fill (chips, tiles on top of a card).
  Color get softFill =>
      isDark ? AppColors.darkSurface : AppColors.backgroundLight;

  /// Borders and dividers.
  Color get divider => isDark ? AppColors.darkDivider : AppColors.divider;

  /// Brand colour that stays visible on the current background
  /// (use for icons / text, NOT for filled buttons with white text).
  Color get brand => isDark ? const Color(0xFF90ABDC) : AppColors.primary;

  /// Soft card shadow (none in dark mode).
  List<BoxShadow> get softShadow => isDark
      ? const []
      : [
          BoxShadow(
            color: const Color(0xFF354463).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ];
}
