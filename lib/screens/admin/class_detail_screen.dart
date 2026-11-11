import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/class_model.dart';
import '../../models/user_model.dart';
import '../../services/class_service.dart';
import '../../services/user_service.dart';
import '../../widgets/user_avatar.dart';
import 'class_management_screen.dart';

// ─── Class Detail Screen ──────────────────────────────────────────────────────

class ClassDetailScreen extends StatelessWidget {
  final ClassModel cls;
  final ClassService classService;

  const ClassDetailScreen({
    super.key,
    required this.cls,
    required this.classService,
  });

  @override
  Widget build(BuildContext context) {
    // Stream the class live so edits reflect immediately
    return StreamBuilder<ClassModel?>(
      stream: classService.streamById(cls.id),
      builder: (context, snap) {
        final c = snap.data ?? cls;
        return _ClassDetailView(cls: c, classService: classService);
      },
    );
  }
}

class _ClassDetailView extends StatelessWidget {
  final ClassModel cls;
  final ClassService classService;
  const _ClassDetailView({required this.cls, required this.classService});

  @override
  Widget build(BuildContext context) {
    final levelColor = _levelColor(cls.level);

    return Scaffold(
      backgroundColor: context.pageBg,
      body: CustomScrollView(
        slivers: [
          // ── App bar with class info ──────────────────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            leading: const BackButton(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
                tooltip: 'Edit',
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ClassFormScreen(
                        classService: classService, editClass: cls))),
              ),
              const SizedBox(width: 4),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, Color(0xFF4A5F8A)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(20, 56, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: levelColor.withAlpha(40),
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: levelColor.withAlpha(120)),
                            ),
                            child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.class_outlined,
                                      size: 12, color: levelColor),
                                  const SizedBox(width: 4),
                                  Text(cls.level.label,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: levelColor,
                                          fontWeight: FontWeight.w600,)),
                                ]),
                          ),
                          if (!cls.isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.error.withAlpha(40),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('Inactive',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,)),
                            ),
                          ],
                        ]),
                        const SizedBox(height: 8),
                        Text(cls.name,
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,)),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 13, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text(cls.academicYear,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,)),
                          if (cls.room != null) ...[
                            const SizedBox(width: 12),
                            const Icon(Icons.room_outlined,
                                size: 13, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(cls.room!,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white70,)),
                          ],
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Stats cards ──────────────────────────────────────────
                  Row(children: [
                    Expanded(
                        child: _StatCard(
                      icon: Icons.people_outline,
                      value: '${cls.studentCount}',
                      label: 'Students',
                      sub: '/ ${cls.capacity} capacity',
                      color: cls.isFull
                          ? AppColors.error
                          : AppColors.success,
                    )),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _StatCard(
                      icon: Icons.school_outlined,
                      value: '${cls.teacherCount}',
                      label: 'Teachers',
                      color: AppColors.warning,
                    )),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _StatCard(
                      icon: Icons.event_seat_outlined,
                      value: '${cls.spotsLeft}',
                      label: 'Spots left',
                      color: AppColors.primary,
                    )),
                  ]),

                  // ── Schedule ─────────────────────────────────────────────
                  if (cls.schedule.day.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _SectionHeader(
                        title: 'Schedule',
                        icon: Icons.schedule_outlined),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.surfaceBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.divider),
                      ),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.access_time_outlined,
                              color: context.brand, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(cls.schedule.day,
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: context.textPrimary,)),
                              const SizedBox(height: 2),
                              Text(
                                '${cls.schedule.startTime} – ${cls.schedule.endTime}',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: context.textSecondary,),
                              ),
                            ]),
                      ]),
                    ),
                  ],

                  // ── Teachers ─────────────────────────────────────────────
                  const SizedBox(height: 24),
                  _SectionHeader(
                    title: 'Teachers',
                    icon: Icons.school_outlined,
                    color: AppColors.warning,
                    actionLabel: 'Manage',
                    onAction: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => AssignTeachersScreen(
                                cls: cls,
                                classService: classService))),
                  ),
                  const SizedBox(height: 12),
                  _UserIdList(
                    ids: cls.teacherIds,
                    emptyMessage: 'No teachers assigned yet',
                    emptyIcon: Icons.school_outlined,
                    accentColor: AppColors.warning,
                  ),

                  // ── Students ─────────────────────────────────────────────
                  const SizedBox(height: 24),
                  _SectionHeader(
                    title: 'Students',
                    icon: Icons.people_outline,
                    color: AppColors.success,
                    actionLabel: 'Manage',
                    onAction: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => AssignStudentsScreen(
                                cls: cls,
                                classService: classService))),
                  ),
                  const SizedBox(height: 12),
                  _UserIdList(
                    ids: cls.studentIds,
                    emptyMessage: 'No students enrolled yet',
                    emptyIcon: Icons.people_outline,
                    accentColor: AppColors.success,
                    showRole: false,
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _levelColor(ClassLevel l) {
    switch (l) {
      case ClassLevel.beginner:
        return AppColors.success;
      case ClassLevel.intermediate:
        return AppColors.warning;
      case ClassLevel.advanced:
        return AppColors.primary;
    }
  }
}

// ─── Stat card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String? sub;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaceBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.divider),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 10),
        Text(value,
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,)),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: context.textSecondary,)),
        if (sub != null)
          Text(sub!,
              style: TextStyle(
                  fontSize: 11,
                  color: context.textSecondary,)),
      ]),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    required this.icon,
    this.color = AppColors.primary,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          width: 3,
          height: 20,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Text(title,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,)),
      const Spacer(),
      if (actionLabel != null && onAction != null)
        TextButton.icon(
          onPressed: onAction,
          icon: const Icon(Icons.edit_outlined, size: 14),
          label: Text(actionLabel!,
              style: const TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            foregroundColor: color,
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          ),
        ),
    ]);
  }
}

// ─── User list (loads by IDs) ─────────────────────────────────────────────────

class _UserIdList extends StatelessWidget {
  final List<String> ids;
  final String emptyMessage;
  final IconData emptyIcon;
  final Color accentColor;
  final bool showRole;

  const _UserIdList({
    required this.ids,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.accentColor,
    this.showRole = true,
  });

  @override
  Widget build(BuildContext context) {
    if (ids.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.surfaceBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.divider),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(emptyIcon, size: 18, color: context.textSecondary),
          const SizedBox(width: 8),
          Text(emptyMessage,
              style: TextStyle(
                  fontSize: 13,
                  color: context.textSecondary,)),
        ]),
      );
    }

    return Column(
      children: ids
          .map((uid) => _UserTile(
                uid: uid,
                accentColor: accentColor,
                showRole: showRole,
              ))
          .toList(),
    );
  }
}

class _UserTile extends StatelessWidget {
  final String uid;
  final Color accentColor;
  final bool showRole;

  const _UserTile({
    required this.uid,
    required this.accentColor,
    required this.showRole,
  });

  @override
  Widget build(BuildContext context) {
    final userService = UserService();
    return FutureBuilder<UserModel?>(
      future: userService.getUserById(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: context.surfaceBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.divider),
            ),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.softFill,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                  height: 12,
                  width: 140,
                  color: context.softFill),
            ]),
          );
        }

        final user = snap.data;
        if (user == null) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: context.surfaceBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.divider),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: UserAvatar(user: user, radius: 20),
            title: Text(user.fullName,
                style: const TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w600)),
            subtitle: Text(
              showRole
                  ? (user.speciality?.isNotEmpty == true
                      ? user.speciality!
                      : user.email)
                  : user.email,
              style: TextStyle(fontSize: 12,
                  color: context.textSecondary),
            ),
            trailing: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accentColor.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                user.isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                    fontSize: 11,
                    color: user.isActive ? accentColor : AppColors.error,
                    fontWeight: FontWeight.w600,),
              ),
            ),
          ),
        );
      },
    );
  }
}
