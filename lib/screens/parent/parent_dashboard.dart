import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../models/activity_model.dart';
import '../../services/activity_service.dart';
import '../../widgets/user_avatar.dart';
import '../auth/login_screen.dart';
import '../profile/profile_screen.dart';

class ParentDashboard extends StatefulWidget {
  const ParentDashboard({super.key});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  int _selectedIndex = 0;

  static const _navItems = [
    _NavItem(Icons.home, 'Home'),
    _NavItem(Icons.calendar_today, 'Daily Activities'),
    _NavItem(Icons.trending_up, 'Progress'),
    _NavItem(Icons.description, 'Reports'),
    _NavItem(Icons.notifications, 'Updates'),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final parent = auth.currentUser;
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: isWide
          ? null
          : AppBar(
              title: const Text('Hope Academy'),
              actions: [
                if (parent != null) ...[
                  UserAvatar(user: parent, radius: 16),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.keyboard_arrow_down,
                        color: Colors.white),
                    onSelected: (v) {
                      if (v == 'logout') _signOut();
                      if (v == 'profile') _openProfile();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'profile',
                        child: Row(
                          children: [
                            Icon(Icons.person_outline,
                                size: 18, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text('My Profile',
                                style: TextStyle(fontFamily: 'Georgia')),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout,
                                size: 18, color: AppColors.error),
                            SizedBox(width: 8),
                            Text('Sign Out',
                                style: TextStyle(color: AppColors.error)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
      body: Row(
        children: [
          if (isWide) _buildSidebar(parent),
          Expanded(child: _buildContent()),
        ],
      ),
      bottomNavigationBar: isWide ? null : _buildBottomNav(),
    );
  }

  Widget _buildSidebar(UserModel? parent) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: AppColors.primary,
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 8, offset: Offset(2, 0)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Parent Portal',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Georgia',
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 8),
          ..._navItems.asMap().entries.map((e) => _SidebarTile(
                icon: e.value.icon,
                label: e.value.label,
                selected: _selectedIndex == e.key,
                onTap: () => setState(() => _selectedIndex = e.key),
              )),
          const Spacer(),
          if (parent != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _openProfile,
                    child: UserAvatar(user: parent, radius: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: _openProfile,
                      child: Text(
                        parent.fullName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white,
                          fontFamily: 'Georgia',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout,
                        color: Colors.white60, size: 18),
                    onPressed: _signOut,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildOverview();
      case 1:
        return _DailyActivitiesTab();
      default:
        return _ComingSoon(label: _navItems[_selectedIndex].label);
    }
  }

  Widget _buildOverview() {
    final parent = context.read<AuthProvider>().currentUser;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome banner
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF4A6FA5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, ${parent?.firstName ?? 'Parent'}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Georgia',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Stay connected with your child\'s progress',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontFamily: 'Georgia',
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.family_restroom,
                    color: Colors.white60, size: 40),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Recent activities preview
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Activities',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontFamily: 'Georgia',
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _selectedIndex = 1),
                child: const Text('See all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _RecentActivitiesPreview(
            onSeeAll: () => setState(() => _selectedIndex = 1),
          ),
        ],
      ),
    );
  }

  BottomNavigationBar _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (i) => setState(() => _selectedIndex = i),
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textSecondary,
      items: _navItems
          .map((item) => BottomNavigationBarItem(
                icon: Icon(item.icon),
                label: item.label,
              ))
          .toList(),
    );
  }

  void _signOut() async {
    await context.read<AuthProvider>().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }
}

// ─── Recent Activities Preview (overview tab) ─────────────────────────────────

class _RecentActivitiesPreview extends StatelessWidget {
  final VoidCallback onSeeAll;
  const _RecentActivitiesPreview({required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final parentId =
        context.read<AuthProvider>().currentUser?.uid ?? '';

    if (parentId.isEmpty) {
      return const _EmptyActivities();
    }

    return StreamBuilder<List<ActivityModel>>(
      stream: ActivityService().streamForParent(parentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final activities = snapshot.data ?? [];
        if (activities.isEmpty) return const _EmptyActivities();

        // Show only 3 most recent
        final preview = activities.take(3).toList();
        return Column(
          children: preview
              .map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ActivityCard(activity: a),
                  ))
              .toList(),
        );
      },
    );
  }
}

// ─── Daily Activities Tab ─────────────────────────────────────────────────────

class _DailyActivitiesTab extends StatefulWidget {
  @override
  State<_DailyActivitiesTab> createState() => _DailyActivitiesTabState();
}

class _DailyActivitiesTabState extends State<_DailyActivitiesTab> {
  ActivityCategory? _filterCategory;

  @override
  Widget build(BuildContext context) {
    final parentId =
        context.read<AuthProvider>().currentUser?.uid ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: const Text(
            'Daily Activities',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              fontFamily: 'Georgia',
            ),
          ),
        ),

        // Category filter chips
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            children: [
              _FilterChip(
                label: 'All',
                selected: _filterCategory == null,
                onTap: () => setState(() => _filterCategory = null),
              ),
              ...ActivityCategory.values.map((c) => _FilterChip(
                    label: '${c.emoji} ${c.label}',
                    selected: _filterCategory == c,
                    onTap: () =>
                        setState(() => _filterCategory = c),
                  )),
            ],
          ),
        ),

        // Activities list
        Expanded(
          child: parentId.isEmpty
              ? const _EmptyActivities()
              : StreamBuilder<List<ActivityModel>>(
                  stream: ActivityService().streamForParent(parentId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }
                    var activities = snapshot.data ?? [];
                    if (_filterCategory != null) {
                      activities = activities
                          .where((a) => a.category == _filterCategory)
                          .toList();
                    }
                    if (activities.isEmpty) {
                      return const _EmptyActivities();
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: activities.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ActivityCard(activity: activities[i]),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─── Activity Card ────────────────────────────────────────────────────────────

class _ActivityCard extends StatelessWidget {
  final ActivityModel activity;
  const _ActivityCard({required this.activity});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(activity.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Category emoji badge
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  activity.category.emoji,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        fontFamily: 'Georgia',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activity.category.label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  activity.status.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          if (activity.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              activity.description,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Completion bar
          if (activity.completionRate > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: activity.completionRate / 100,
                      backgroundColor: Colors.grey.shade200,
                      color: _completionColor(activity.completionRate),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${activity.completionRate.toInt()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],

          // Teacher notes (visible to parent)
          if (activity.teacherNotes != null &&
              activity.teacherNotes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFE082)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.note_alt_outlined,
                      size: 14, color: Color(0xFFB8860B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      activity.teacherNotes!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF795548),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),
          // Date & duration footer
          Row(
            children: [
              const Icon(Icons.access_time,
                  size: 13, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                _formatDate(activity.date),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              if (activity.duration != null) ...[
                const SizedBox(width: 12),
                const Icon(Icons.timer_outlined,
                    size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${activity.duration} min',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(ActivityStatus s) {
    switch (s) {
      case ActivityStatus.completed:
        return AppColors.success;
      case ActivityStatus.inProgress:
        return AppColors.primary;
      case ActivityStatus.skipped:
        return AppColors.error;
      case ActivityStatus.pending:
        return Colors.orange;
    }
  }

  Color _completionColor(double rate) {
    if (rate >= 80) return AppColors.success;
    if (rate >= 50) return Colors.orange;
    return AppColors.error;
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (d.year == yesterday.year &&
        d.month == yesterday.month &&
        d.day == yesterday.day) {
      return 'Yesterday';
    }
    return '${d.day}/${d.month}/${d.year}';
  }
}

// ─── Filter Chip ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : Colors.grey.shade300,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight:
                  selected ? FontWeight.w600 : FontWeight.normal,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyActivities extends StatelessWidget {
  const _EmptyActivities();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.event_note_outlined,
                size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text(
            'No activities yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Activities shared by the teacher will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

class _SidebarTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? Colors.white : Colors.white60),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? Colors.white : Colors.white70,
                  fontFamily: 'Georgia',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  final String label;
  const _ComingSoon({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.construction_outlined,
              size: 48,
              color: Color(0xFFB8860B),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Coming soon',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontFamily: 'Georgia',
            ),
          ),
        ],
      ),
    );
  }
}
