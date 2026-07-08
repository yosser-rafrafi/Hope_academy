import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/permissions.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../widgets/role_badge.dart';
import '../../widgets/user_avatar.dart';
import 'create_user_screen.dart';

class UserManagementScreen extends StatefulWidget {
  final UserModel currentUser;
  const UserManagementScreen({super.key, required this.currentUser});

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
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'User Management',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontFamily: 'Georgia',
                      ),
                    ),
                    Text(
                      _isAdmin
                          ? 'Full access — manage all accounts'
                          : 'Delegated access — Teachers & Students only',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontFamily: 'Georgia',
                      ),
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
                        color: Color(0xFF6A0DAD),
                        fontFamily: 'Georgia',
                      ),
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
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Search by name or email…',
              prefixIcon: const Icon(Icons.search,
                  color: AppColors.textSecondary, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear,
                          color: AppColors.textSecondary, size: 17),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.backgroundLight,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                    color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppColors.background,
      child: TabBar(
        controller: _tabCtrl,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        indicatorWeight: 2.5,
        isScrollable: _tabs.length > 4,
        labelStyle: const TextStyle(
          fontFamily: 'Georgia',
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Georgia',
          fontSize: 12,
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
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off_outlined,
              size: 48,
              color: AppColors.textSecondary.withAlpha(100)),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isNotEmpty
                ? 'No results for "$_searchQuery"'
                : 'No ${role?.label ?? 'users'} found',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontFamily: 'Georgia',
            ),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline,
              size: 44, color: AppColors.error),
          const SizedBox(height: 10),
          const Text('Failed to load users',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                fontFamily: 'Georgia',
              )),
          const SizedBox(height: 4),
          Text(error,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontFamily: 'Georgia'),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: user.isActive
              ? AppColors.divider
              : AppColors.error.withAlpha(64),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 5,
              offset: const Offset(0, 2)),
        ],
      ),
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
                          color: AppColors.background, width: 1.5),
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
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontFamily: 'Georgia',
                        ),
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontFamily: 'Georgia',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (user.speciality != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    user.speciality!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.success,
                      fontFamily: 'Georgia',
                    ),
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
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Georgia',
                        )),
                  ),
              ],
            ),
          ),
          if (canEdit)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert,
                  color: AppColors.textSecondary, size: 19),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onSelected: (a) => _handleAction(context, a),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined,
                          size: 17, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('Edit',
                          style: TextStyle(fontFamily: 'Georgia')),
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
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          color: user.isActive
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
            const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.lock_outline,
                  size: 17, color: AppColors.textSecondary),
            ),
        ],
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
          style: const TextStyle(
              fontFamily: 'Georgia', fontWeight: FontWeight.bold),
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 14,
                color: AppColors.textPrimary,
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
                style: TextStyle(fontFamily: 'Georgia')),
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
                style: const TextStyle(fontFamily: 'Georgia')),
          ),
        ],
      ),
    );
  }
}
