import 'package:flutter/material.dart';

class AppColors {
  // Primary palette
  static const Color primary = Color(0xFF354463);      // Deep Blue
  static const Color secondary = Color(0xFFC1F7D5);    // Soft Teal
  static const Color accent = Color(0xFFFDCE77);       // Warm Orange
  static const Color success = Color(0xFF0D9546);      // Soft Green

  // Backgrounds
  static const Color background = Color(0xFFFFFFFF);
  static const Color backgroundLight = Color(0xFFF7F9FC);
  static const Color surfaceCard = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFF2C3E50);
  static const Color textSecondary = Color(0xFF6C757D);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Role colors
  static const Color adminColor = Color(0xFF354463);
  static const Color teacherColor = Color(0xFF0D9546);
  static const Color parentColor = Color(0xFFFDCE77);

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
}
