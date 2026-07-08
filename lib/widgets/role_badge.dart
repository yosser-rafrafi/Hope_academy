import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/user_model.dart';

class RoleBadge extends StatelessWidget {
  final UserRole role;
  final bool small;

  const RoleBadge({super.key, required this.role, this.small = false});

  @override
  Widget build(BuildContext context) {
    final (color, bgColor, icon) = _roleStyle(role);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: small ? 11 : 13, color: color),
          const SizedBox(width: 4),
          Text(
            role.shortLabel,
            style: TextStyle(
              fontSize: small ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: color,
              fontFamily: 'Georgia',
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color, IconData) _roleStyle(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return (
          AppColors.primary,
          AppColors.primary.withAlpha(30),
          Icons.admin_panel_settings,
        );
      case UserRole.subAdmin:
        return (
          const Color(0xFF6A0DAD), // purple
          const Color(0xFF6A0DAD).withAlpha(25),
          Icons.manage_accounts,
        );
      case UserRole.teacher:
        return (
          AppColors.success,
          AppColors.success.withAlpha(30),
          Icons.school,
        );
      case UserRole.student:
        return (
          const Color(0xFFB8860B),
          AppColors.accent.withAlpha(90),
          Icons.family_restroom,
        );
    }
  }
}
