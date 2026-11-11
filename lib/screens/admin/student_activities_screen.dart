import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/activity_model.dart';
import '../../models/user_model.dart';
import '../../services/activity_service.dart';

class StudentActivitiesScreen extends StatefulWidget {
  final UserModel student;
  const StudentActivitiesScreen({super.key, required this.student});

  @override
  State<StudentActivitiesScreen> createState() => _StudentActivitiesScreenState();
}

class _StudentActivitiesScreenState extends State<StudentActivitiesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _formatTime(DateTime d) {
    final hour = d.hour == 0 ? 12 : (d.hour > 12 ? d.hour - 12 : d.hour);
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    final minute = d.minute.toString().padLeft(2, '0');
    return '$hour:$minute $ampm';
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ActivityModel>>(
      stream: ActivityService().streamByStudent(widget.student.uid),
      builder: (context, snapshot) {
        final all = snapshot.data ?? [];
        final dailies = all.where((a) => _isToday(a.date)).toList();
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return Scaffold(
          backgroundColor: context.pageBg,
          body: NestedScrollView(
            headerSliverBuilder: (context2, _) => [
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                stretch: true,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.blurBackground, StretchMode.zoomBackground],
                  background: _buildHeroHeader(all),
                ),
                bottom: TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.accent,
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold,fontSize: 14),
                  tabs: [
                    Tab(
                      icon: const Icon(Icons.history, size: 20),
                      text: 'All Activities (${all.length})',
                    ),
                    Tab(
                      icon: const Icon(Icons.today, size: 20),
                      text: 'Today (${dailies.length})',
                    ),
                  ],
                ),
              ),
            ],
            body: isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildActivityList(all, 'No activities recorded yet.'),
                      _buildActivityList(dailies, 'No activities today yet.'),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildHeroHeader(List<ActivityModel> all) {
    final completed = all.where((a) => a.status == ActivityStatus.completed).length;
    final completionPct = all.isEmpty ? 0.0 : (completed / all.length * 100);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF354463), Color(0xFF2A5298), Color(0xFF1E3A5F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 70),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back + title
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 12),
              // Student info
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.accent, width: 3),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 15),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 34,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      backgroundImage: widget.student.profileImageUrl != null
                          ? NetworkImage(widget.student.profileImageUrl!)
                          : null,
                      child: widget.student.profileImageUrl == null
                          ? const Icon(Icons.person, size: 34, color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.student.fullName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
                              ),
                              child: Text(
                                widget.student.group ?? 'No Group',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Completion ring
                  _CompletionRing(percentage: completionPct),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityList(List<ActivityModel> activities, String emptyMsg) {
    if (activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.event_note, size: 56, color: context.brand),
            ),
            const SizedBox(height: 20),
            Text(emptyMsg, style: TextStyle(color: context.textSecondary, fontSize: 16)),
          ],
        ),
      );
    }

    // Group activities by date
    final grouped = <String, List<ActivityModel>>{};
    for (final a in activities) {
      final key = '${a.date.year}-${a.date.month.toString().padLeft(2,'0')}-${a.date.day.toString().padLeft(2,'0')}';
      grouped.putIfAbsent(key, () => []).add(a);
    }
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: sortedKeys.length,
      itemBuilder: (context, idx) {
        final key = sortedKeys[idx];
        final dayActivities = grouped[key]!;
        final date = dayActivities.first.date;
        final isToday = _isToday(date);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Padding(
              padding: EdgeInsets.only(bottom: 12, top: idx == 0 ? 0 : 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: isToday
                          ? const LinearGradient(colors: [AppColors.accent, Color(0xFFF5A623)])
                          : LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.1), AppColors.primary.withValues(alpha: 0.05)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isToday) ...[
                          Container(width: 7, height: 7, decoration: BoxDecoration(color: context.cardBg, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          isToday ? '✨ Today' : _formatDate(date),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isToday ? Colors.white : context.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Divider(color: context.divider.withValues(alpha: 0.6))),
                  const SizedBox(width: 8),
                  Text('${dayActivities.length}', style: TextStyle(fontSize: 12, color: context.textSecondary.withValues(alpha: 0.7))),
                ],
              ),
            ),
            // Activity cards
            ...dayActivities.map((a) => _buildPremiumCard(a)),
          ],
        );
      },
    );
  }

  Widget _buildPremiumCard(ActivityModel a) {
    Color statusColor;
    IconData statusIcon;
    switch (a.status) {
      case ActivityStatus.completed:
        statusColor = AppColors.success; statusIcon = Icons.check_circle;
        break;
      case ActivityStatus.inProgress:
        statusColor = AppColors.accent; statusIcon = Icons.play_circle;
        break;
      case ActivityStatus.pending:
        statusColor = context.textSecondary; statusIcon = Icons.radio_button_unchecked;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 6)),
        ],
        border: Border(left: BorderSide(color: statusColor, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category emoji badge
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [statusColor.withValues(alpha: 0.15), statusColor.withValues(alpha: 0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(child: Text(a.category.emoji, style: const TextStyle(fontSize: 26))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.title,
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: context.textPrimary,),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        a.category.label,
                        style: TextStyle(fontSize: 13, color: context.textSecondary.withValues(alpha: 0.8)),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 13, color: statusColor),
                      const SizedBox(width: 5),
                      Text(a.status.label, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            // Time
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: context.textSecondary.withValues(alpha: 0.7)),
                  const SizedBox(width: 4),
                  Text(_formatTime(a.date), style: TextStyle(fontSize: 12, color: context.textSecondary.withValues(alpha: 0.7))),
                  if (a.duration != null) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.timer_outlined, size: 14, color: context.textSecondary.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Text('${a.duration} min', style: TextStyle(fontSize: 12, color: context.textSecondary.withValues(alpha: 0.7))),
                  ],
                ],
              ),
            ),
            if (a.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(a.description, style: TextStyle(fontSize: 14, color: context.textPrimary, height: 1.5)),
            ],
            if (a.objectives.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: a.objectives.map((o) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(o, style: TextStyle(fontSize: 11, color: context.brand, fontWeight: FontWeight.w600)),
                )).toList(),
              ),
            ],
            if (a.teacherNotes != null && a.teacherNotes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.sticky_note_2, size: 16, color: Color(0xFFF5A623)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Teacher\'s Note', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFB8860B))),
                          const SizedBox(height: 2),
                          Text(a.teacherNotes!, style: TextStyle(fontSize: 13, color: context.textPrimary, fontStyle: FontStyle.italic, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Completion Ring Widget ─────────────────────────────────────────────────

class _CompletionRing extends StatelessWidget {
  final double percentage;
  const _CompletionRing({required this.percentage});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 60,
          height: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: percentage / 100,
                strokeWidth: 5,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  percentage >= 75 ? AppColors.success : percentage >= 50 ? AppColors.accent : Colors.white70,
                ),
              ),
              Text(
                '${percentage.round()}%',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text('Done', style: TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }
}
