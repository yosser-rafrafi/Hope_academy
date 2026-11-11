import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/user_model.dart';

class UserAvatar extends StatelessWidget {
  final UserModel user;
  final double radius;

  const UserAvatar({super.key, required this.user, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    if (user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(user.profileImageUrl!),
      );
    }

    final (bg, fg) = _avatarColors(user.role);

    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: Text(
        user.initials,
        style: TextStyle(
          color: fg,
          fontSize: radius * 0.75,
          fontWeight: FontWeight.bold,),
      ),
    );
  }

  (Color, Color) _avatarColors(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return (AppColors.primary, Colors.white);
      case UserRole.subAdmin:
        return (const Color(0xFF6A0DAD), Colors.white);
      case UserRole.teacher:
        return (AppColors.success, Colors.white);
      case UserRole.student:
        return (AppColors.accent, const Color(0xFF5A4000));
    }
  }
}
