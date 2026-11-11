import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/class_model.dart';
import '../../models/user_model.dart';
import '../../services/class_service.dart';
import '../../services/user_service.dart';
import 'group_activities_screen.dart';
import 'student_activities_screen.dart';

class AdminActivitiesScreen extends StatefulWidget {
  const AdminActivitiesScreen({super.key});

  @override
  State<AdminActivitiesScreen> createState() => _AdminActivitiesScreenState();
}

class _AdminActivitiesScreenState extends State<AdminActivitiesScreen> {
  final ClassService _classService = ClassService();
  final UserService _userService = UserService();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: TabBarView(
              children: [
                _buildClassesTab(),
                _buildStudentsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: context.cardBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Text(
              'Activities Log',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,),
            ),
          ),
          TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: context.textSecondary,
            indicatorColor: AppColors.primary,
            labelStyle: TextStyle(fontWeight: FontWeight.bold,),
            unselectedLabelStyle: TextStyle(),
            tabs: [
              Tab(text: 'By Group / Class', icon: Icon(Icons.class_)),
              Tab(text: 'By Student', icon: Icon(Icons.person)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClassesTab() {
    return StreamBuilder<List<ClassModel>>(
      stream: _classService.streamAll(activeOnly: false), // show all, even inactive maybe? Let's just do all
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final classes = snapshot.data ?? [];
        if (classes.isEmpty) {
          return const Center(child: Text('No classes found.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: classes.length,
          itemBuilder: (context, index) {
            final cls = classes[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                leading: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.class_outlined, color: context.brand),
                ),
                title: Text(cls.name, style: const TextStyle(fontWeight: FontWeight.bold,fontSize: 16)),
                subtitle: Text('${cls.studentCount} Students • ${cls.level.label} Level'),
                trailing: Icon(Icons.arrow_forward_ios, size: 16, color: context.textSecondary),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => GroupActivitiesScreen(classModel: cls)),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStudentsTab() {
    return StreamBuilder<List<UserModel>>(
      stream: _userService.streamUsersByRole(UserRole.student),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final students = snapshot.data ?? [];
        if (students.isEmpty) {
          return const Center(child: Text('No students found.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: students.length,
          itemBuilder: (context, index) {
            final student = students[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                leading: CircleAvatar(
                  radius: 25,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage: student.profileImageUrl != null ? NetworkImage(student.profileImageUrl!) : null,
                  child: student.profileImageUrl == null ? Icon(Icons.person, color: context.brand) : null,
                ),
                title: Text(student.fullName, style: const TextStyle(fontWeight: FontWeight.bold,fontSize: 16)),
                subtitle: Text(student.group ?? 'No group'),
                trailing: Icon(Icons.arrow_forward_ios, size: 16, color: context.textSecondary),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => StudentActivitiesScreen(student: student)),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
