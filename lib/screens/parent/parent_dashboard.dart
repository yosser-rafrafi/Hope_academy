import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/user_model.dart';
import '../../models/activity_model.dart';
import '../../services/activity_service.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/announcements_feed_widget.dart';
import '../../widgets/ai_report_export_dialog.dart';
import '../../services/ai_report_service.dart';
import '../../services/student_service.dart';
import '../../models/student_model.dart';
import '../auth/login_screen.dart';
import '../profile/profile_screen.dart';
import '../shared/portfolio_screen.dart';
import '../../l10n/app_strings.dart';
import '../pei/pei_screen.dart';
import '../finance/student_finance_screen.dart';

class ParentDashboard extends StatefulWidget {
  const ParentDashboard({super.key});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  int _selectedIndex = 0;

  static const _navItems = [
    _NavItem(Icons.home_outlined, 'Home'),
    _NavItem(Icons.calendar_today_outlined, 'Daily Activities'),
    _NavItem(Icons.auto_awesome_outlined, 'AI Reports'),
    _NavItem(Icons.campaign_outlined, 'Announcements'),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final parent = auth.currentUser;
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: isWide
          ? null
          : AppBar(
              title: const Text('Hope Academy'),
              actions: [
                IconButton(
                  icon: Icon(
                    themeProvider.isDarkMode
                        ? Icons.wb_sunny_outlined
                        : Icons.nightlight_round_outlined,
                  ),
                  tooltip: 'Toggle Theme',
                  onPressed: () =>
                      themeProvider.toggleTheme(!themeProvider.isDarkMode),
                ),
                if (parent != null) ...[
                  UserAvatar(user: parent, radius: 16),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.keyboard_arrow_down),
                    onSelected: (v) {
                      if (v == 'logout') _signOut();
                      if (v == 'profile') _openProfile();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'profile',
                        child: Row(
                          children: [
                            Icon(Icons.person_outline,
                                size: 18, color: context.brand),
                            SizedBox(width: 8),
                            Text('My Profile'),
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
          if (isWide) _buildSidebar(parent, themeProvider),
          Expanded(child: _buildContent()),
        ],
      ),
      bottomNavigationBar: isWide ? null : _buildBottomNav(),
    );
  }

  Widget _buildSidebar(UserModel? parent, ThemeProvider themeProvider) {
    return Container(
      width: 230,
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
                    color: context.cardBg,
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
          // Theme switch tile in sidebar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: InkWell(
              onTap: () =>
                  themeProvider.toggleTheme(!themeProvider.isDarkMode),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      themeProvider.isDarkMode
                          ? Icons.wb_sunny_outlined
                          : Icons.nightlight_round_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      themeProvider.isDarkMode
                          ? 'Light Mode'
                          : 'Dark Mode',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
      case 2:
        return _ParentReportsTab();
      case 3:
        return const SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: AnnouncementsFeedWidget(),
        );
      default:
        return _buildOverview();
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
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, ${parent?.firstName ?? 'Parent'} 👋',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Stay connected with your child\'s growth & activities at Hope Academy',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.88),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.family_restroom,
                    color: Colors.white60, size: 44),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Announcements feed preview
          const AnnouncementsFeedWidget(compact: true),
          const SizedBox(height: 24),

          // Recent activities preview
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Activities',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
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

// ─── Parent AI Reports Tab ───────────────────────────────────────────────────

class _ParentReportsTab extends StatefulWidget {
  @override
  State<_ParentReportsTab> createState() => _ParentReportsTabState();
}

class _ParentReportsTabState extends State<_ParentReportsTab> {
  final AiReportService _reportService = AiReportService();
  final StudentService _studentService = StudentService();
  final ActivityService _activityService = ActivityService();
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    final parent = context.watch<AuthProvider>().currentUser;
    final theme = Theme.of(context);

    if (parent == null) return const SizedBox.shrink();

    return StreamBuilder<List<StudentModel>>(
      stream: _studentService.streamByParent(parent.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        final students = snapshot.data ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: context.brand, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'AI Progress Reports',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Generate and export structured daily & weekly summary reports generated for your children.',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 20),

              if (students.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text('No student profiles linked to your parent account.'),
                  ),
                )
              else
                ...students.map((student) => _buildStudentReportCard(context, student)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStudentReportCard(BuildContext context, StudentModel student) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(student.initials,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: context.brand)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.fullName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Class: ${student.className.isNotEmpty ? student.className : "Assigned Group"}',
                    style: TextStyle(fontSize: 12, color: context.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isGenerating
                      ? null
                      : () async {
                          setState(() => _isGenerating = true);
                          final weekStart =
                              DateTime.now().subtract(const Duration(days: 7));
                          // Previously always called with `logs: []` because
                          // ActivityLogModel had no service to populate it —
                          // now pulled from the same ActivityService the
                          // teacher's Daily Activity screen already writes to.
                          final weekActivities = await _activityService
                              .streamByStudent(student.uid)
                              .first
                              .then((all) =>
                                  all.where((a) => a.date.isAfter(weekStart)).toList());
                          final report = await _reportService.generateWeeklySummary(
                            student: student,
                            activities: weekActivities,
                            weekStart: weekStart,
                          );
                          setState(() => _isGenerating = false);
                          if (context.mounted) {
                            AiReportExportDialog.show(
                              context,
                              title: 'Weekly Summary Report',
                              reportText: report,
                              student: student,
                            );
                          }
                        },
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: const Text('Weekly Report'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final recent = await _activityService
                        .streamByStudent(student.uid)
                        .first;
                    final suggestions = await _reportService.suggestActivities(
                      student: student,
                      recentActivities: recent,
                    );
                    final text = '💡 Recommended Support Activities for ${student.firstName}:\n\n${suggestions.map((s) => '• $s').join('\n')}';
                    if (context.mounted) {
                      AiReportExportDialog.show(
                        context,
                        title: 'Recommended Activities',
                        reportText: text,
                        student: student,
                      );
                    }
                  },
                  icon: const Icon(Icons.lightbulb_outline, size: 18),
                  label: const Text('AI Suggestions'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.grape,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                final viewer = context.read<AuthProvider>().currentUser;
                if (viewer == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PortfolioScreen(student: student, viewer: viewer),
                  ),
                );
              },
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('Portfolio (PDF)',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.grape,
                side: const BorderSide(color: AppColors.grape, width: 1.5),
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                final viewer = context.read<AuthProvider>().currentUser;
                if (viewer == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PeiScreen(student: student, viewer: viewer),
                  ),
                );
              },
              icon: const Icon(Icons.flag_rounded, size: 18),
              label: Text(context.tr('pei.button'),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.success,
                side: const BorderSide(color: AppColors.success, width: 1.5),
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                final viewer = context.read<AuthProvider>().currentUser;
                if (viewer == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        StudentFinanceScreen(student: student, viewer: viewer),
                  ),
                );
              },
              icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
              label: Text(context.tr('fin.button'),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Recent Activities Preview (overview tab) ─────────────────────────────────

class _RecentActivitiesPreview extends StatelessWidget {
  final VoidCallback onSeeAll;
  const _RecentActivitiesPreview({required this.onSeeAll});

  List<List<ActivityModel>> _group(List<ActivityModel> all) {
    final map = <String, List<ActivityModel>>{};
    for (final a in all) {
      final key =
          '${a.title}__${a.date.year}-${a.date.month}-${a.date.day}__${a.category.name}';
      map.putIfAbsent(key, () => []).add(a);
    }
    return map.values.toList();
  }

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
            child: Center(child: CircularProgressIndicator.adaptive()),
          );
        }
        final activities = snapshot.data ?? [];
        if (activities.isEmpty) return const _EmptyActivities();

        final groups = _group(activities);
        final preview = groups.take(3).toList();
        return Column(
          children: preview
              .map((g) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ActivityCard(group: g),
                  ))
              .toList(),
        );
      },
    );
  }
}

// ─── Period filter enum ────────────────────────────────────────────────────────

enum _PeriodFilter { day, week, month, all }

extension _PeriodFilterExt on _PeriodFilter {
  String get label {
    switch (this) {
      case _PeriodFilter.day:   return 'Today';
      case _PeriodFilter.week:  return 'This Week';
      case _PeriodFilter.month: return 'This Month';
      case _PeriodFilter.all:   return 'All';
    }
  }

  IconData get icon {
    switch (this) {
      case _PeriodFilter.day:   return Icons.today_outlined;
      case _PeriodFilter.week:  return Icons.view_week_outlined;
      case _PeriodFilter.month: return Icons.calendar_month_outlined;
      case _PeriodFilter.all:   return Icons.all_inclusive;
    }
  }

  bool matches(DateTime date) {
    final now = DateTime.now();
    switch (this) {
      case _PeriodFilter.day:
        return date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      case _PeriodFilter.week:
        final startOfWeek =
            now.subtract(Duration(days: now.weekday - 1));
        final start = DateTime(
            startOfWeek.year, startOfWeek.month, startOfWeek.day);
        final end = start.add(const Duration(days: 7));
        return date.isAfter(start.subtract(const Duration(seconds: 1))) &&
            date.isBefore(end);
      case _PeriodFilter.month:
        return date.year == now.year && date.month == now.month;
      case _PeriodFilter.all:
        return true;
    }
  }
}

// ─── Daily Activities Tab ─────────────────────────────────────────────────────

class _DailyActivitiesTab extends StatefulWidget {
  @override
  State<_DailyActivitiesTab> createState() => _DailyActivitiesTabState();
}

class _DailyActivitiesTabState extends State<_DailyActivitiesTab> {
  ActivityCategory? _filterCategory;
  _PeriodFilter _periodFilter = _PeriodFilter.all;

  List<List<ActivityModel>> _group(List<ActivityModel> all) {
    final map = <String, List<ActivityModel>>{};
    for (final a in all) {
      final key =
          '${a.title}__${a.date.year}-${a.date.month}-${a.date.day}__${a.category.name}';
      map.putIfAbsent(key, () => []).add(a);
    }
    return map.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final parentId =
        context.read<AuthProvider>().currentUser?.uid ?? '';
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Text(
            'Daily Activities',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),

        // ── Period filter chips ──────────────────────────────────────────────
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            children: _PeriodFilter.values.map((p) {
              final selected = _periodFilter == p;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _periodFilter = p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? colorScheme.primary
                            : colorScheme.outline,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(p.icon,
                            size: 13,
                            color: selected
                                ? colorScheme.onPrimary
                                : colorScheme.onSurfaceVariant),
                        const SizedBox(width: 5),
                        Text(
                          p.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: selected
                                ? colorScheme.onPrimary
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // ── Category filter chips ────────────────────────────────────────────
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            children: [
              _FilterChip(
                label: 'All',
                selected: _filterCategory == null,
                onTap: () => setState(() => _filterCategory = null),
              ),
              ...ActivityCategory.values.map((c) => _FilterChip(
                    label: '${c.emoji} ${c.label}',
                    selected: _filterCategory == c,
                    onTap: () => setState(() => _filterCategory = c),
                  )),
            ],
          ),
        ),

        // ── Activity list ────────────────────────────────────────────────────
        Expanded(
          child: parentId.isEmpty
              ? const _EmptyActivities()
              : StreamBuilder<List<ActivityModel>>(
                  stream: ActivityService().streamForParent(parentId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator.adaptive());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('Erreur: ${snapshot.error}',
                              style:
                                  const TextStyle(color: Colors.red)),
                        ),
                      );
                    }
                    var activities = snapshot.data ?? [];

                    if (_periodFilter != _PeriodFilter.all) {
                      activities = activities
                          .where((a) => _periodFilter.matches(a.date))
                          .toList();
                    }
                    if (_filterCategory != null) {
                      activities = activities
                          .where((a) => a.category == _filterCategory)
                          .toList();
                    }

                    if (activities.isEmpty) {
                      return _EmptyFiltered(
                        periodLabel: _periodFilter != _PeriodFilter.all
                            ? _periodFilter.label
                            : null,
                        onClear: () => setState(() {
                          _periodFilter = _PeriodFilter.all;
                          _filterCategory = null;
                        }),
                      );
                    }

                    final groups = _group(activities);
                    return ListView.builder(
                      padding:
                          const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: groups.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ActivityCard(group: groups[i]),
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
  final List<ActivityModel> group;
  const _ActivityCard({required this.group});

  ActivityModel get _rep => group.first;

  /// Pour un groupe, afficher le statut le plus "avancé"
  ActivityStatus get _groupStatus {
    if (group.every((a) => a.status == ActivityStatus.completed)) {
      return ActivityStatus.completed;
    }
    if (group.any((a) => a.status == ActivityStatus.inProgress)) {
      return ActivityStatus.inProgress;
    }
    return ActivityStatus.pending;
  }

  /// Taux de concentration moyen du groupe
  double get _avgConcentration =>
      group.map((a) => a.concentrationRate).reduce((a, b) => a + b) /
      group.length;

  @override
  Widget build(BuildContext context) {
    final status = _groupStatus;
    final statusColor = _statusColor(status);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final avgConcentration = _avgConcentration;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.5)),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _rep.category.emoji,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _rep.title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _rep.category.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          if (_rep.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              _rep.description,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          if (avgConcentration > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: avgConcentration / 100,
                      backgroundColor: colorScheme.outline,
                      color: _concentrationColor(avgConcentration),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${avgConcentration.toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],

          if (_rep.teacherNotes != null &&
              _rep.teacherNotes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? const Color(0xFF3A2E00)
                    : const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.brightness == Brightness.dark
                      ? const Color(0xFF7A6000)
                      : const Color(0xFFFFE082),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.note_alt_outlined,
                      size: 14,
                      color: theme.brightness == Brightness.dark
                          ? const Color(0xFFFFD54F)
                          : const Color(0xFFB8860B)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _rep.teacherNotes!,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.brightness == Brightness.dark
                            ? const Color(0xFFFFD54F)
                            : const Color(0xFF795548),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time,
                  size: 13, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                _formatDate(_rep.date),
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (_rep.duration != null) ...[
                const SizedBox(width: 12),
                Icon(Icons.timer_outlined,
                    size: 13, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  '${_rep.duration} min',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              // Badge groupe si fullClass
              if (_rep.targetMode == ActivityTargetMode.fullClass &&
                  _rep.className != null) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.group_outlined,
                          size: 12, color: colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        _rep.className!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
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
      case ActivityStatus.pending:
        return Colors.orange;
    }
  }

  Color _concentrationColor(double rate) {
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
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? colorScheme.primary : colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? colorScheme.primary : colorScheme.outline,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
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
            child: Icon(Icons.event_note_outlined,
                size: 48, color: context.brand),
          ),
          const SizedBox(height: 16),
          const Text(
            'No activities yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Activities shared by the teacher will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyFiltered extends StatelessWidget {
  final String? periodLabel;
  final VoidCallback onClear;
  const _EmptyFiltered({this.periodLabel, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.search_off_outlined,
                size: 48, color: colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            periodLabel != null
                ? 'No activities for $periodLabel'
                : 'No activities match your filters',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Try a different period or category',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.clear_all, size: 16),
            label: const Text('Clear filters'),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
