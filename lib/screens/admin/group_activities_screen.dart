import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../models/activity_model.dart';
import '../../models/class_model.dart';
import '../../services/activity_service.dart';
import '../../services/user_service.dart';
import '../../models/user_model.dart';
import 'group_activity_details_screen.dart';

class GroupActivitiesScreen extends StatefulWidget {
  final ClassModel classModel;
  const GroupActivitiesScreen({super.key, required this.classModel});

  @override
  State<GroupActivitiesScreen> createState() => _GroupActivitiesScreenState();
}

class _GroupActivitiesScreenState extends State<GroupActivitiesScreen> {
  final _activityService = ActivityService();
  final _userService = UserService();
  final Map<String, UserModel> _studentsMap = {};

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    for (final sid in widget.classModel.studentIds) {
      final user = await _userService.getUserById(sid);
      if (user != null) {
        if (mounted) {
          setState(() {
            _studentsMap[sid] = user;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('${widget.classModel.name} Activities', style: const TextStyle(fontFamily: 'Georgia')),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<ActivityModel>>(
        stream: _activityService.streamAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final allActivities = snapshot.data ?? [];
          // Filter activities that belong to students in this class
          final classActivities = allActivities.where((a) => widget.classModel.studentIds.contains(a.studentId)).toList();

          if (classActivities.isEmpty) {
            return const Center(child: Text('No activities recorded for this group yet.', style: TextStyle(color: AppColors.textSecondary)));
          }

          // Group by Date + Title (Unified View)
          final grouped = <String, List<ActivityModel>>{};
          for (final a in classActivities) {
            final dateKey = '${a.date.year}-${a.date.month.toString().padLeft(2, '0')}-${a.date.day.toString().padLeft(2, '0')}';
            final key = '${dateKey}_${a.title}';
            if (!grouped.containsKey(key)) grouped[key] = [];
            grouped[key]!.add(a);
          }

          final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a)); // Newest first

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedKeys.length,
            itemBuilder: (context, index) {
              final key = sortedKeys[index];
              final activities = grouped[key]!;
              final first = activities.first;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppColors.divider.withValues(alpha: 0.5)),
                ),
                elevation: 0,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupActivityDetailsScreen(
                          dateKey: key.split('_')[0],
                          title: first.title,
                          classModel: widget.classModel,
                          activities: activities,
                          studentsMap: _studentsMap,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(first.category.emoji, style: const TextStyle(fontSize: 24)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                first.title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Georgia'),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatDate(first.date),
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.people, size: 14, color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${activities.length} Students',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundLight,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

}
