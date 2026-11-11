import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/activity_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/activity_service.dart';
import '../../services/user_service.dart';
import 'activity_detail_screen.dart';
import 'create_activity_screen.dart';

class MyActivitiesScreen extends StatefulWidget {
  final bool showAsPage;
  const MyActivitiesScreen({super.key, this.showAsPage = false});

  @override
  State<MyActivitiesScreen> createState() => _MyActivitiesScreenState();
}

class _MyActivitiesScreenState extends State<MyActivitiesScreen>
    with SingleTickerProviderStateMixin {
  final _activityService = ActivityService();
  final _userService = UserService();

  ActivityCategory? _filterCategory;
  String _searchQuery = '';
  late AnimationController _headerAnim;
  late Animation<double> _headerFade;

  final Map<String, UserModel> _studentCache = {};
  bool _isFetchingStudents = false;
  List<ActivityModel> _lastActivities = [];

  @override
  void initState() {
    super.initState();
    _headerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _headerFade =
        CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _headerAnim.dispose();
    super.dispose();
  }

  Future<void> _prefetchStudents(List<ActivityModel> activities) async {
    // Guard: skip if already fetching
    if (_isFetchingStudents) return;
    final missing = activities
        .map((a) => a.studentId)
        .toSet()
        .where((id) => !_studentCache.containsKey(id))
        .toList();
    // Guard: skip if nothing new to load → no setState → no rebuild
    if (missing.isEmpty) return;

    _isFetchingStudents = true;
    for (final id in missing) {
      final u = await _userService.getUserById(id);
      if (u != null) _studentCache[id] = u;
    }
    _isFetchingStudents = false;
    if (mounted) setState(() {}); // single rebuild, only when new data arrived
  }

  Map<String, List<ActivityModel>> _group(List<ActivityModel> all) {
    final map = <String, List<ActivityModel>>{};
    for (final a in all) {
      final key =
          '${a.title}__${a.date.year}-${a.date.month}-${a.date.day}__${a.category.name}';
      map.putIfAbsent(key, () => []).add(a);
    }
    return map;
  }

  List<ActivityModel> _applyFilters(List<ActivityModel> all) {
    return all.where((a) {
      final matchCat =
          _filterCategory == null || a.category == _filterCategory;
      final matchSearch = _searchQuery.isEmpty ||
          a.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          a.description
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());
      return matchCat && matchSearch;
    }).toList();
  }

  Future<void> _deleteGroup(List<ActivityModel> group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Activity'),
        content: Text(
            'Delete "${group.first.title}" for ${group.length} student(s)?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    for (final a in group) {
      await _activityService.delete(a.id);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Activity deleted'),
            backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final teacherId = context.read<AuthProvider>().currentUser!.uid;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerHighest,
      appBar: widget.showAsPage
          ? AppBar(
              title: const Text('My Activities'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'New Activity',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CreateActivityScreen()),
                  ),
                ),
              ],
            )
          : null,
      body: StreamBuilder<List<ActivityModel>>(
        stream: _activityService.streamByTeacher(teacherId),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final all = snap.data ?? [];
          // Only prefetch when the activity list actually changes
          final ids = all.map((a) => a.studentId).toSet();
          final lastIds = _lastActivities.map((a) => a.studentId).toSet();
          if (ids.difference(lastIds).isNotEmpty) {
            _lastActivities = all;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _prefetchStudents(all);
            });
          }
          final filtered = _applyFilters(all);
          final groups = _group(filtered);
          final keys = groups.keys.toList();

          // Stats for the banner
          final today = DateTime.now();
          final todayActivities = all
              .where((a) =>
                  a.date.year == today.year &&
                  a.date.month == today.month &&
                  a.date.day == today.day)
              .toList();
          final inProgressCount = all
              .where((a) => a.status == ActivityStatus.inProgress)
              .length;
          final completedCount = all
              .where((a) => a.status == ActivityStatus.completed)
              .length;

          return Column(
            children: [
              // ── Stats banner ──────────────────────────────────────
              FadeTransition(
                opacity: _headerFade,
                child: _StatsBanner(
                  total: all.length,
                  todayCount: todayActivities.length,
                  inProgress: inProgressCount,
                  completed: completedCount,
                ),
              ),

              // ── Search + Filter bar ────────────────────────────
              Container(
                color: colorScheme.surface,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search activities…',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        filled: true,
                        fillColor:
                            colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (v) =>
                          setState(() => _searchQuery = v),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 34,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _FilterChip(
                            label: 'All',
                            selected: _filterCategory == null,
                            onTap: () =>
                                setState(() => _filterCategory = null),
                          ),
                          ...ActivityCategory.values
                              .map((c) => _FilterChip(
                                    label: '${c.emoji} ${c.label}',
                                    selected: _filterCategory == c,
                                    onTap: () => setState(
                                        () => _filterCategory = c),
                                  )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Activity list ──────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? _EmptyState(
                        hasFilter: _filterCategory != null ||
                            _searchQuery.isNotEmpty)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                            16, 12, 16, 100),
                        itemCount: keys.length,
                        itemBuilder: (_, i) {
                          final group = groups[keys[i]]!;
                          final rep = group.first;
                          return _AnimatedCard(
                            index: i,
                            child: _ActivityGroupCard(
                              group: group,
                              representative: rep,
                              studentCache: _studentCache,
                              onDelete: () => _deleteGroup(group),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ActivityDetailScreen(
                                        group: group),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
                builder: (_) => const CreateActivityScreen()),
          );
          if (created == true && mounted) setState(() {});
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Activity',
            style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

// ── Stats Banner ──────────────────────────────────────────────────────────────

class _StatsBanner extends StatelessWidget {
  final int total;
  final int todayCount;
  final int inProgress;
  final int completed;

  const _StatsBanner({
    required this.total,
    required this.todayCount,
    required this.inProgress,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E2D4A), const Color(0xFF253553)]
              : [AppColors.primary, const Color(0xFF4A6FA5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting
          Row(
            children: [
              const Text('📋 ',
                  style: TextStyle(fontSize: 18)),
              Text(
                'My Activities',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$total total',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stat pills
          Row(
            children: [
              _StatPill(
                icon: Icons.today_outlined,
                label: 'Today',
                value: '$todayCount',
                color: const Color(0xFFFDCE77),
              ),
              const SizedBox(width: 10),
              _StatPill(
                icon: Icons.play_circle_outline,
                label: 'In Progress',
                value: '$inProgress',
                color: const Color(0xFF60D394),
              ),
              const SizedBox(width: 10),
              _StatPill(
                icon: Icons.check_circle_outline,
                label: 'Done',
                value: '$completed',
                color: const Color(0xFF90ABDC),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.7))),
            ]),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Animated card wrapper ─────────────────────────────────────────────────────

class _AnimatedCard extends StatefulWidget {
  final int index;
  final Widget child;

  const _AnimatedCard({required this.index, required this.child});

  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    // Stagger by index
    Future.delayed(
        Duration(milliseconds: 60 * widget.index.clamp(0, 8)),
        () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ── Group Card ────────────────────────────────────────────────────────────────

class _ActivityGroupCard extends StatelessWidget {
  final List<ActivityModel> group;
  final ActivityModel representative;
  final Map<String, UserModel> studentCache;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _ActivityGroupCard({
    required this.group,
    required this.representative,
    required this.studentCache,
    required this.onDelete,
    required this.onTap,
  });

  Color get _statusColor {
    final statuses = group.map((a) => a.status).toSet();
    if (statuses.every((s) => s == ActivityStatus.completed)) {
      return AppColors.success;
    }
    if (statuses.any((s) => s == ActivityStatus.inProgress)) {
      return AppColors.warning;
    }
    return AppColors.textSecondary;
  }

  String get _statusLabel {
    final completed =
        group.where((a) => a.status == ActivityStatus.completed).length;
    return '$completed/${group.length} completed';
  }

  double get _completionRatio {
    final done =
        group.where((a) => a.status == ActivityStatus.completed).length;
    return group.isEmpty ? 0 : done / group.length;
  }

  bool get _isToday {
    final now = DateTime.now();
    final d = representative.date;
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final d = representative.date;
    final dateStr = _isToday
        ? 'Today'
        : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final timeStr = '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = _statusColor;
    final ratio = _completionRatio;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outline),
          boxShadow: [
            BoxShadow(
              color: statusColor.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Left color accent ──────────────────────
                    Container(width: 4, color: statusColor),

                    // ── Card content ───────────────────────────
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header row
                          Container(
                            padding: const EdgeInsets.fromLTRB(
                                14, 14, 10, 14),
                            decoration: BoxDecoration(
                              color: statusColor
                                  .withValues(alpha: 0.04),
                            ),
                            child: Row(
                              children: [
                                // Category emoji badge
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: statusColor
                                        .withValues(alpha: 0.12),
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      representative
                                          .category.emoji,
                                      style: const TextStyle(
                                          fontSize: 22),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        if (_isToday) ...[
                                          Container(
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal: 6,
                                                vertical: 2),
                                            margin:
                                                const EdgeInsets.only(
                                                    right: 6),
                                            decoration: BoxDecoration(
                                              color: AppColors.accent
                                                  .withValues(
                                                      alpha: 0.25),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      6),
                                            ),
                                            child: const Text(
                                              '✨ Today',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight:
                                                    FontWeight.bold,
                                                color: AppColors.accent,
                                              ),
                                            ),
                                          ),
                                        ],
                                        Expanded(
                                          child: Text(
                                            representative.title,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight:
                                                  FontWeight.bold,
                                              color:
                                                  colorScheme.onSurface,
                                            ),
                                            overflow:
                                                TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ]),
                                      const SizedBox(height: 2),
                                      Text(
                                        representative.category.label,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert,
                                      color: colorScheme
                                          .onSurfaceVariant),
                                  onSelected: (v) {
                                    if (v == 'delete') onDelete();
                                    if (v == 'edit') onTap();
                                  },
                                  itemBuilder: (_) => [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Row(children: [
                                        Icon(Icons.edit_outlined,
                                            color: context.brand,
                                            size: 18),
                                        SizedBox(width: 8),
                                        Text('Modifier'),
                                      ]),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(children: [
                                        Icon(Icons.delete_outline,
                                            color: AppColors.error,
                                            size: 18),
                                        SizedBox(width: 8),
                                        Text('Supprimer',
                                            style: TextStyle(
                                                color: AppColors.error)),
                                      ]),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Body
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                                14, 12, 14, 14),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                // Meta row
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  children: [
                                    _MetaChip(
                                      icon: Icons.calendar_today,
                                      label: '$dateStr  $timeStr',
                                      color:
                                          colorScheme.onSurfaceVariant,
                                    ),
                                    if (representative.duration !=
                                        null)
                                      _MetaChip(
                                        icon: Icons.timer_outlined,
                                        label:
                                            '${representative.duration} min',
                                        color: colorScheme
                                            .onSurfaceVariant,
                                      ),
                                    _MetaChip(
                                      icon: Icons.people_outline,
                                      label:
                                          '${group.length} student${group.length > 1 ? 's' : ''}',
                                      color:
                                          colorScheme.onSurfaceVariant,
                                    ),
                                  ],
                                ),

                                if (representative
                                    .description.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    representative.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: colorScheme
                                            .onSurfaceVariant,
                                        height: 1.4),
                                  ),
                                ],

                                const SizedBox(height: 12),

                                // Status + visibility row
                                Row(
                                  children: [
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor
                                            .withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        border: Border.all(
                                            color: statusColor
                                                .withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                              Icons
                                                  .check_circle_outline,
                                              size: 13,
                                              color: statusColor),
                                          const SizedBox(width: 5),
                                          Text(
                                            _statusLabel,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight:
                                                  FontWeight.w600,
                                              color: statusColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    if (!representative
                                        .isVisibleToParent)
                                      Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.warning
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.visibility_off,
                                                size: 12,
                                                color: AppColors.warning),
                                            SizedBox(width: 4),
                                            Text('Private',
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors
                                                        .warning)),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),

                                // Student chips / class badge
                                if (representative.targetMode ==
                                        ActivityTargetMode.fullClass &&
                                    representative.className !=
                                        null) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary
                                          .withValues(alpha: 0.08),
                                      borderRadius:
                                          BorderRadius.circular(20),
                                      border: Border.all(
                                          color: colorScheme.primary
                                              .withValues(alpha: 0.25)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.group_outlined,
                                            size: 14,
                                            color: colorScheme.primary),
                                        const SizedBox(width: 6),
                                        Text(
                                          representative.className!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else if (group.length <= 5) ...[
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: group.map((a) {
                                      final student =
                                          studentCache[a.studentId];
                                      final name =
                                          student?.fullName ?? '…';
                                      final isDone = a.status ==
                                          ActivityStatus.completed;
                                      return Container(
                                        padding: const EdgeInsets
                                            .symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isDone
                                              ? AppColors.success
                                                  .withValues(alpha: 0.10)
                                              : colorScheme
                                                  .surfaceContainerHighest,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isDone
                                                ? AppColors.success
                                                    .withValues(alpha: 0.3)
                                                : colorScheme.outline,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (isDone) ...[
                                              const Icon(Icons.check,
                                                  size: 11,
                                                  color:
                                                      AppColors.success),
                                              const SizedBox(width: 4),
                                            ],
                                            Text(
                                              name,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDone
                                                    ? AppColors.success
                                                    : colorScheme
                                                        .onSurface,
                                                fontWeight:
                                                    FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
          ),
        ),
      ),
    );
  }
}

// ── Meta chip ─────────────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                selected ? AppColors.primary : colorScheme.outline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.normal,
            color: selected
                ? Colors.white
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilter;
  const _EmptyState({required this.hasFilter});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.event_note_outlined,
                  size: 52, color: colorScheme.primary),
            ),
            const SizedBox(height: 20),
            Text(
              hasFilter
                  ? 'No activities match your filters'
                  : 'No activities yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilter
                  ? 'Try adjusting your search or filters.'
                  : 'Tap + New Activity to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
