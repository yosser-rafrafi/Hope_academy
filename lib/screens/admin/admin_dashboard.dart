import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/permissions.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/user_service.dart';
import '../../models/user_model.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/announcements_feed_widget.dart';
import '../finance/finance_hub_screen.dart';
import '../finance/salaries_screen.dart';
import '../auth/login_screen.dart';
import '../profile/profile_screen.dart';
import 'user_management_screen.dart';
import 'class_management_screen.dart';
import 'admin_activities_screen.dart';
import 'absence_management_screen.dart';
import 'absence_reports_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final UserService _userService = UserService();
  int _selectedIndex = 0;

  // Nav items built dynamically per role
  List<_NavItem> _navItems(UserModel user) {
    final sections = Permissions.sectionsFor(user);
    return sections.map((s) => _NavItem(_sectionIcon(s), s.label, s)).toList();
  }

  IconData _sectionIcon(DashboardSection s) {
    switch (s) {
      case DashboardSection.overview:
        return Icons.dashboard_outlined;
      case DashboardSection.userManagement:
        return Icons.people_outline;
      case DashboardSection.studentManagement:
        return Icons.child_care_outlined;
      case DashboardSection.classManagement:
        return Icons.class_outlined;
      case DashboardSection.attendance:
        return Icons.event_available_outlined;
      case DashboardSection.reports:
        return Icons.bar_chart_outlined;
      case DashboardSection.finance:
        return Icons.account_balance_wallet_outlined;
      case DashboardSection.salaries:
        return Icons.payments_outlined;
      case DashboardSection.settings:
        return Icons.settings_outlined;
      case DashboardSection.messages:
        return Icons.message_outlined;
      case DashboardSection.announcements:
        return Icons.campaign_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    final navItems = _navItems(user);
    final safeIndex =
        _selectedIndex < navItems.length ? _selectedIndex : 0;
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      body: Row(
        children: [
          if (isWide) _buildSidebar(user, navItems, safeIndex),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(user, navItems, safeIndex, isWide),
                Expanded(
                  child: _buildContent(user, navItems, safeIndex),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : _buildBottomNav(navItems, safeIndex),
    );
  }

  // ─── Sidebar ───────────────────────────────────────────────────────────────

  Widget _buildSidebar(
      UserModel user, List<_NavItem> navItems, int selected) {
    final isSubAdmin = user.role == UserRole.subAdmin;
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: isSubAdmin ? const Color(0xFF4A2080) : AppColors.primary,
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(2, 0)),
        ],
      ),
      child: Column(
        children: [
          // Logo + portal name
          Container(
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hope Academy',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,),
                      ),
                      Text(
                        isSubAdmin ? 'Sub-Admin Portal' : 'Admin Portal',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white60,),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // SubAdmin info banner
          if (isSubAdmin)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 13, color: Colors.white70),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Limited access — no salary or settings',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white60,),
                    ),
                  ),
                ],
              ),
            ),

          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 8),

          // Nav items
          ...navItems.asMap().entries.map((e) => _SidebarItem(
                icon: e.value.icon,
                label: e.value.label,
                selected: selected == e.key,
                onTap: () => setState(() => _selectedIndex = e.key),
                isSensitive: e.value.section == DashboardSection.salaries ||
                    e.value.section == DashboardSection.settings,
              )),

          const Spacer(),

          // User profile footer
          Container(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                UserAvatar(user: user, radius: 17),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user.role.label,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white60,),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout,
                      color: Colors.white60, size: 18),
                  tooltip: 'Sign Out',
                  onPressed: _signOut,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ─── Top Bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar(UserModel user, List<_NavItem> navItems,
      int selected, bool isWide) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outline)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Page title
          Text(
            navItems[selected].label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,),
          ),

          const Spacer(),

          Builder(
            builder: (context) {
              final themeProvider = context.watch<ThemeProvider>();
              return IconButton(
                icon: Icon(
                  themeProvider.isDarkMode
                      ? Icons.wb_sunny_outlined
                      : Icons.nightlight_round_outlined,
                ),
                tooltip: 'Toggle Dark/Light Theme',
                onPressed: () =>
                    themeProvider.toggleTheme(!themeProvider.isDarkMode),
              );
            },
          ),
          const SizedBox(width: 8),

          // On wide screens: show full name + role + avatar + logout button
          if (isWide) ...[
            // Name + role pill
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  user.fullName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,),
                ),
                Text(
                  user.role.shortLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,),
                ),
              ],
            ),
            const SizedBox(width: 10),

            // Avatar — click → profile
            Tooltip(
              message: 'My Profile',
              child: GestureDetector(
                onTap: _openProfile,
                child: UserAvatar(user: user, radius: 18),
              ),
            ),

            const SizedBox(width: 12),

            // Divider
            Container(
              width: 1,
              height: 28,
              color: colorScheme.outline,
            ),

            const SizedBox(width: 12),

            // Logout button
            Tooltip(
              message: 'Sign Out',
              child: InkWell(
                onTap: _signOut,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.error.withAlpha(12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.error.withAlpha(50)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.logout,
                          size: 15, color: AppColors.error),
                      SizedBox(width: 6),
                      Text(
                        'Sign Out',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ]

          // On narrow screens: compact popup menu with avatar only
          else ...[
            PopupMenuButton<String>(
              offset: const Offset(0, 44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onSelected: (v) {
                if (v == 'logout') _signOut();
                if (v == 'profile') _openProfile();
              },
              child: UserAvatar(user: user, radius: 17),
              itemBuilder: (_) => [
                PopupMenuItem(
                  enabled: false,
                  height: 40,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,),
                      ),
                      Text(
                        user.role.shortLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.textSecondary,),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'profile',
                  child: Row(children: [
                    Icon(Icons.person_outline,
                        size: 18, color: context.brand),
                    SizedBox(width: 8),
                    Text('My Profile',
                        style: TextStyle()),
                  ]),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(children: [
                    Icon(Icons.logout, size: 18, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Sign Out',
                        style: TextStyle(
                            color: AppColors.error,)),
                  ]),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── Content router ────────────────────────────────────────────────────────

  Widget _buildContent(
      UserModel user, List<_NavItem> navItems, int selected) {
    final section = navItems[selected].section;
    switch (section) {
      case DashboardSection.overview:
        return _buildOverview(user);
      case DashboardSection.userManagement:
        return UserManagementScreen(currentUser: user);
      case DashboardSection.studentManagement:
        return UserManagementScreen(currentUser: user, initialRole: UserRole.student);
      case DashboardSection.classManagement:
        return ClassManagementScreen(currentUser: user);
      case DashboardSection.activities:
        return const AdminActivitiesScreen();
      case DashboardSection.attendance:
        return const AbsenceManagementScreen();
      case DashboardSection.reports:
        return const AbsenceReportsScreen();
      case DashboardSection.announcements:
        return const SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: AnnouncementsFeedWidget(),
        );
      case DashboardSection.finance:
        return Permissions.canManageFees(user)
            ? FinanceHubScreen(currentUser: user)
            : _buildAccessDenied();
      case DashboardSection.salaries:
        return _buildSalariesGuard(user);
      case DashboardSection.settings:
        return _buildSettingsGuard(user);
      default:
        return _buildComingSoon(navItems[selected].label);
    }
  }

  // ─── Overview ─────────────────────────────────────────────────────────────

  Widget _buildOverview(UserModel user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeBanner(user),
          const SizedBox(height: 24),
          _buildStatsSection(user),
          const SizedBox(height: 24),
          _buildQuickActions(user),
        ],
      ),
    );
  }

  Widget _buildWelcomeBanner(UserModel user) {
    final isSubAdmin = user.role == UserRole.subAdmin;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSubAdmin
              ? [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)]
              : [AppColors.primary, const Color(0xFF6366F1)],
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
                  'Welcome back, ${user.firstName}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,),
                ),
                const SizedBox(height: 4),
                Text(
                  isSubAdmin
                      ? 'Sub-Administrator — Delegated Management'
                      : 'Full Administrator — Hope Academy',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withAlpha(200),),
                ),
              ],
            ),
          ),
          Icon(
            isSubAdmin ? Icons.manage_accounts : Icons.admin_panel_settings,
            color: Colors.white.withAlpha(100),
            size: 42,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(UserModel user) {
    return FutureBuilder<Map<UserRole, int>>(
      future: _userService.getUserCountByRole(),
      builder: (context, snap) {
        final counts = snap.data;
        final canSeeSalaries = Permissions.canViewSalaries(user);
        final canSeeAllStats = Permissions.canViewGlobalStats(user);
        final textTheme = Theme.of(context).textTheme;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Platform Overview',
              style: textTheme.titleMedium?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(builder: (ctx, constraints) {
              final cols = constraints.maxWidth > 600 ? 4 : 2;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.9,
                children: [
                  if (canSeeAllStats)
                    _StatCard(
                      label: 'Administrators',
                      value: counts?[UserRole.admin]?.toString() ?? '—',
                      icon: Icons.admin_panel_settings,
                      color: AppColors.primary,
                    ),
                  if (canSeeAllStats)
                    _StatCard(
                      label: 'Sub-Admins',
                      value: counts?[UserRole.subAdmin]?.toString() ?? '—',
                      icon: Icons.manage_accounts,
                      color: const Color(0xFF6A0DAD),
                    ),
                  _StatCard(
                    label: 'Teachers',
                    value: counts?[UserRole.teacher]?.toString() ?? '—',
                    icon: Icons.school,
                    color: AppColors.success,
                  ),
                  _StatCard(
                    label: 'Students',
                    value: counts?[UserRole.student]?.toString() ?? '—',
                    icon: Icons.child_care,
                    color: const Color(0xFF0077B6),
                  ),
                  _StatCard(
                    label: 'Total Users',
                    value: counts != null
                        ? counts.values.fold(0, (a, b) => a + b).toString()
                        : '—',
                    icon: Icons.people,
                    color: AppColors.primary,
                  ),
                  if (canSeeSalaries)
                    _StatCard(
                      label: 'Monthly Payroll',
                      value: '—',
                      icon: Icons.payments,
                      color: AppColors.success,
                    ),
                ],
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildQuickActions(UserModel user) {
    final navItems = _navItems(user);
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: textTheme.titleMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _QuickActionButton(
              icon: Icons.person_add,
              label: 'Add User',
              onTap: () {
                final idx = navItems.indexWhere(
                    (n) => n.section == DashboardSection.userManagement);
                if (idx >= 0) setState(() => _selectedIndex = idx);
              },
            ),
            _QuickActionButton(
              icon: Icons.people,
              label: 'Manage Users',
              onTap: () {
                final idx = navItems.indexWhere(
                    (n) => n.section == DashboardSection.userManagement);
                if (idx >= 0) setState(() => _selectedIndex = idx);
              },
            ),
            if (Permissions.canViewGlobalStats(user))
              _QuickActionButton(
                icon: Icons.bar_chart,
                label: 'Reports',
                onTap: () {
                  final idx = navItems.indexWhere(
                      (n) => n.section == DashboardSection.reports);
                  if (idx >= 0) setState(() => _selectedIndex = idx);
                },
              ),
            if (Permissions.canViewSalaries(user))
              _QuickActionButton(
                icon: Icons.payments,
                label: 'Salaries',
                onTap: () {
                  final idx = navItems.indexWhere(
                      (n) => n.section == DashboardSection.salaries);
                  if (idx >= 0) setState(() => _selectedIndex = idx);
                },
              ),
          ],
        ),
      ],
    );
  }

  // ─── Guards for sensitive sections ────────────────────────────────────────

  Widget _buildSalariesGuard(UserModel user) {
    if (!Permissions.canViewSalaries(user)) return _buildAccessDenied();
    return SalariesScreen(currentUser: user);
  }

  Widget _buildSettingsGuard(UserModel user) {
    if (!Permissions.canAccessSettings(user)) return _buildAccessDenied();
    return _buildComingSoon('System Settings');
  }

  Widget _buildAccessDenied() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.error.withAlpha(20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.lock_outline,
                size: 48, color: AppColors.error),
          ),
          const SizedBox(height: 16),
          Text(
            'Access Restricted',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'This section requires Administrator access.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildComingSoon(String section) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.secondary.withAlpha(76),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.construction_outlined,
                size: 48, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            section,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Coming soon',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  BottomNavigationBar _buildBottomNav(
      List<_NavItem> navItems, int selected) {
    final items = navItems.take(5).toList();
    return BottomNavigationBar(
      currentIndex: selected < items.length ? selected : 0,
      onTap: (i) => setState(() => _selectedIndex = i),
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: context.textSecondary,
      items: items
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

// ─── Data classes ─────────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final String label;
  final DashboardSection section;
  const _NavItem(this.icon, this.label, this.section);
}

// ─── Sidebar item ─────────────────────────────────────────────────────────────

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool isSensitive;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.isSensitive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withAlpha(38)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 19,
                  color: selected ? Colors.white : Colors.white60),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? Colors.white : Colors.white70,),
                ),
              ),
              if (isSensitive)
                const Icon(Icons.lock, size: 11, color: Colors.white38),
              if (selected)
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Stat card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outline, width: 1),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color,)),
                ),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSurfaceVariant,)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Quick action button ──────────────────────────────────────────────────────

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outline),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: colorScheme.primary),
            ),
            const SizedBox(width: 10),
            Text(label,
                style: textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                )),
          ],
        ),
      ),
    );
  }
}
