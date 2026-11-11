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
        horizontal: small ? 8 : 12,
        vertical: small ? 3 : 6,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: small ? 11 : 14, color: color),
          const SizedBox(width: 4),
          Text(
            role.shortLabel,
            style: TextStyle(
              fontSize: small ? 11 : 12,
              fontWeight: FontWeight.bold,
              color: color,
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
          AppColors.adminColor,
          AppColors.adminColor.withValues(alpha: 0.08),
          Icons.admin_panel_settings_outlined,
        );
      case UserRole.subAdmin:
        return (
          AppColors.subAdminColor,
          AppColors.subAdminColor.withValues(alpha: 0.08),
          Icons.manage_accounts_outlined,
        );
      case UserRole.teacher:
        return (
          AppColors.teacherColor,
          AppColors.teacherColor.withValues(alpha: 0.08),
          Icons.school_outlined,
        );
      case UserRole.student:
        return (
          AppColors.parentColor,
          AppColors.parentColor.withValues(alpha: 0.08),
          Icons.family_restroom_outlined,
        );
    }
  }
}
