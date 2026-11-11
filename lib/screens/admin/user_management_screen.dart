import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/permissions.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../widgets/role_badge.dart';
import '../../widgets/user_avatar.dart';
import 'create_user_screen.dart';
import 'user_details_screen.dart';

class UserManagementScreen extends StatefulWidget {
  final UserModel currentUser;
  final UserRole? initialRole;
  const UserManagementScreen({super.key, required this.currentUser, this.initialRole});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with SingleTickerProviderStateMixin {
  final UserService _userService = UserService();
  late TabController _tabCtrl;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  bool get _isAdmin => widget.currentUser.role == UserRole.admin;

  // Tabs depend on role
  List<_TabDef> get _tabs {
    if (_isAdmin) {
      return [
        _TabDef('All', null),
        _TabDef('Admins', UserRole.admin),
        _TabDef('Sub-Admins', UserRole.subAdmin),
        _TabDef('Teachers', UserRole.teacher),
        _TabDef('Students', UserRole.student),
      ];
    }
    // SubAdmin: only teachers and students
    return [
      _TabDef('All', null),
      _TabDef('Teachers', UserRole.teacher),
      _TabDef('Students', UserRole.student),
    ];
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    if (widget.initialRole != null) {
      final idx = _tabs.indexWhere((t) => t.role == widget.initialRole);
      if (idx >= 0) {
        _tabCtrl.index = idx;
      }
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildTabBar(),
        Expanded(child: _buildTabContent()),
      ],
    );
  }

  Widget _buildHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Management',
                      style: textTheme.titleLarge,
                    ),
                    Text(
                      _isAdmin
                          ? 'Full access — manage all accounts'
                          : 'Delegated access — Teachers & Students only',
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _openCreateUser,
                icon: const Icon(Icons.person_add, size: 17),
                label: const Text('Add User'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // SubAdmin restriction notice
          if (!_isAdmin)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF6A0DAD).withAlpha(15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF6A0DAD).withAlpha(50)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 15, color: Color(0xFF6A0DAD)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sub-Admin: you can create and manage Teacher and Student accounts only. '
                      'Admin and Sub-Admin accounts are managed by the Administrator.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6A0DAD),),
                    ),
                  ),
                ],
              ),
            ),
          // Search bar
          TextField(
            controller: _searchCtrl,
            onChanged: (v) =>
                setState(() => _searchQuery = v.toLowerCase()),
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: 'Search by name or email…',
              prefixIcon: Icon(Icons.search,
                  color: colorScheme.onSurfaceVariant, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear,
                          color: colorScheme.onSurfaceVariant, size: 17),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: colorScheme.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surface,
      child: TabBar(
        controller: _tabCtrl,
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        indicatorColor: colorScheme.primary,
        indicatorWeight: 2.5,
        isScrollable: _tabs.length > 4,
        labelStyle: const TextStyle(fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 12,
        ),
        tabs: _tabs.map((t) => Tab(text: t.label)).toList(),
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabCtrl,
      children: _tabs.map((t) => _buildUserList(t.role)).toList(),
    );
  }

  Widget _buildUserList(UserRole? filterRole) {
    // SubAdmin: limit to teachers and students
    final Stream<List<UserModel>> stream;
    if (!_isAdmin) {
      stream = filterRole == null
          ? _userService.streamUsersForSubAdmin()
          : _userService.streamUsersByRole(filterRole);
    } else {
      stream = filterRole == null
          ? _userService.streamAllUsers()
          : _userService.streamUsersByRole(filterRole);
    }

    return StreamBuilder<List<UserModel>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(color: context.brand));
        }
        if (snap.hasError) {
          return _buildErrorState(snap.error.toString());
        }

        final allUsers = snap.data ?? [];
        final users = _searchQuery.isEmpty
            ? allUsers
            : allUsers
                .where((u) =>
                    u.fullName
                        .toLowerCase()
                        .contains(_searchQuery) ||
                    u.email.toLowerCase().contains(_searchQuery))
                .toList();

        if (users.isEmpty) return _buildEmptyState(filterRole);

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          itemCount: users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _UserCard(
            user: users[i],
            actor: widget.currentUser,
            onToggleActive: (uid, active) =>
                _userService.toggleUserActive(uid, active),
            onEdit: _openEditUser,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(UserRole? role) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off_outlined,
              size: 48,
              color: colorScheme.onSurfaceVariant.withAlpha(100)),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isNotEmpty
                ? 'No results for "$_searchQuery"'
                : 'No ${role?.label ?? 'users'} found',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openCreateUser,
              icon: const Icon(Icons.person_add, size: 15),
              label: const Text('Add First User'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline,
              size: 44, color: AppColors.error),
          const SizedBox(height: 10),
          Text('Failed to load users',
              style: textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(error,
              style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  void _openCreateUser() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          CreateUserScreen(currentUser: widget.currentUser),
    ));
  }

  void _openEditUser(UserModel user) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          CreateUserScreen(currentUser: widget.currentUser, editUser: user),
    ));
  }
}

// ─── Tab definition ───────────────────────────────────────────────────────────

class _TabDef {
  final String label;
  final UserRole? role;
  const _TabDef(this.label, this.role);
}

// ─── User card ────────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final UserModel user;
  final UserModel actor;
  final Future<void> Function(String uid, bool active) onToggleActive;
  final void Function(UserModel) onEdit;

  const _UserCard({
    required this.user,
    required this.actor,
    required this.onToggleActive,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final canEdit = Permissions.canEditUser(actor, user);
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: user.isActive
              ? colorScheme.outline
              : AppColors.error.withAlpha(64),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 5,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => UserDetailsScreen(user: user, currentUser: actor),
            ));
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Stack(
                  children: [
                    UserAvatar(user: user, radius: 22),
                    if (!user.isActive)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: context.surfaceBg, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.fullName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: user.isActive
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurfaceVariant,),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          RoleBadge(role: user.role, small: true),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (user.speciality != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          user.speciality!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.success,),
                        ),
                      ],
                      if (!user.isActive)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error.withAlpha(25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Deactivated',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,)),
                        ),
                    ],
                  ),
                ),
                if (canEdit)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert,
                        color: colorScheme.onSurfaceVariant, size: 19),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onSelected: (a) => _handleAction(context, a),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined,
                                size: 17, color: colorScheme.primary),
                            const SizedBox(width: 8),
                            const Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Row(
                          children: [
                            Icon(
                              user.isActive
                                  ? Icons.block
                                  : Icons.check_circle_outline,
                              size: 17,
                              color: user.isActive
                                  ? AppColors.error
                                  : AppColors.success,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              user.isActive ? 'Deactivate' : 'Activate',
                              style: TextStyle(color: user.isActive
                                    ? AppColors.error
                                    : AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(Icons.lock_outline,
                        size: 17, color: colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, String action) {
    if (action == 'edit') {
      onEdit(user);
    } else if (action == 'toggle') {
      _confirmToggle(context);
    }
  }

  void _confirmToggle(BuildContext context) {
    final willDeactivate = user.isActive;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          willDeactivate ? 'Deactivate Account' : 'Activate Account',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.5),
            children: [
              TextSpan(
                  text: willDeactivate
                      ? 'Deactivate '
                      : 'Activate '),
              TextSpan(
                  text: user.fullName,
                  style:
                      const TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(
                  text: willDeactivate
                      ? '? They will lose access immediately.'
                      : '? They will regain platform access.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: willDeactivate
                  ? AppColors.error
                  : AppColors.success,
              minimumSize: const Size(0, 36),
            ),
            onPressed: () {
              Navigator.pop(context);
              onToggleActive(user.uid, !user.isActive);
            },
            child: Text(willDeactivate ? 'Deactivate' : 'Activate',
                style: const TextStyle()),
          ),
        ],
      ),
    );
  }
}
