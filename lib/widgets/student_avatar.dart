import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/student_model.dart';

class StudentAvatar extends StatelessWidget {
  final StudentModel student;
  final double radius;

  const StudentAvatar({super.key, required this.student, this.radius = 22});

  @override
  Widget build(BuildContext context) {
    if (student.profileImageUrl != null && student.profileImageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(student.profileImageUrl!),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.secondary,
      child: Text(
        student.initials,
        style: TextStyle(
          color: context.brand,
          fontSize: radius * 0.75,
          fontWeight: FontWeight.bold,),
      ),
    );
  }
}
