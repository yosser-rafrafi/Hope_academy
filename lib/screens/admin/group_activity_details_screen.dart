import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/activity_model.dart';
import '../../models/class_model.dart';
import '../../models/user_model.dart';
import 'student_activities_screen.dart';

class GroupActivityDetailsScreen extends StatelessWidget {
  final String dateKey;
  final String title;
  final ClassModel classModel;
  final List<ActivityModel> activities;
  final Map<String, UserModel> studentsMap;

  const GroupActivityDetailsScreen({
    super.key,
    required this.dateKey,
    required this.title,
    required this.classModel,
    required this.activities,
    required this.studentsMap,
  });

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = d.hour == 0 ? 12 : (d.hour > 12 ? d.hour - 12 : d.hour);
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    final minute = d.minute.toString().padLeft(2, '0');
    return '${months[d.month - 1]} ${d.day}, ${d.year} at $hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final first = activities.first; // Use the first activity for shared metadata

    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        title: const Text('Activity Details', style: TextStyle()),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(first),
            const SizedBox(height: 16),
            _buildMetadata(context, first),
            const SizedBox(height: 16),
            _buildStudentList(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ActivityModel a) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(a.category.emoji, style: const TextStyle(fontSize: 32)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      a.category.label,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.8),),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.class_outlined, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(
                classModel.name,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(
                _formatDate(a.date),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetadata(BuildContext context, ActivityModel a) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (a.description.isNotEmpty) ...[
                Text(
                  'Description',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: context.textSecondary),
                ),
                const SizedBox(height: 6),
                Text(a.description, style: TextStyle(fontSize: 15, color: context.textPrimary)),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  if (a.duration != null) ...[
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                            child: Icon(Icons.timer, size: 18, color: context.brand),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Duration', style: TextStyle(fontSize: 12, color: context.textSecondary)),
                              Text('${a.duration} mins', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.people, size: 18, color: AppColors.success),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Students', style: TextStyle(fontSize: 12, color: context.textSecondary)),
                            Text('${activities.length} participants', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (a.objectives.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Text(
                  'Objectives',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: context.textSecondary),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: a.objectives.map((obj) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                    ),
                    child: Text(obj, style: TextStyle(fontSize: 12, color: context.brand, fontWeight: FontWeight.w600)),
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentList(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 8, bottom: 12),
            child: Text(
              'Student Progress',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,color: context.textPrimary,
              ),
            ),
          ),
          ...activities.map((a) {
            final student = studentsMap[a.studentId];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: context.divider.withValues(alpha: 0.5)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: student == null ? null : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => StudentActivitiesScreen(student: student)),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: student?.profileImageUrl != null ? NetworkImage(student!.profileImageUrl!) : null,
                        child: student?.profileImageUrl == null ? const Icon(Icons.person, color: Colors.grey) : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student?.fullName ?? 'Unknown Student',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            if (a.teacherNotes != null && a.teacherNotes!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                a.teacherNotes!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: context.textSecondary, fontStyle: FontStyle.italic),
                              ),
                            ]
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildStatusChip(context, a.status),
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right, size: 20, color: context.textSecondary),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, ActivityStatus status) {
    Color color;
    switch (status) {
      case ActivityStatus.completed: color = AppColors.success; break;
      case ActivityStatus.inProgress: color = AppColors.accent; break;
      case ActivityStatus.pending: color = context.textSecondary; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
