import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/activity_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/activity_service.dart';
import '../../services/user_service.dart';
import 'create_activity_screen.dart';

class MyActivitiesScreen extends StatefulWidget {
  final bool showAsPage;
  const MyActivitiesScreen({super.key, this.showAsPage = false});

  @override
  State<MyActivitiesScreen> createState() => _MyActivitiesScreenState();
}

class _MyActivitiesScreenState extends State<MyActivitiesScreen> {
  final _activityService = ActivityService();
  final _userService = UserService();

  ActivityCategory? _filterCategory;
  String _searchQuery = '';

  // student uid → name cache
  final Map<String, UserModel> _studentCache = {};

  Future<void> _prefetchStudents(List<ActivityModel> activities) async {
    final ids = activities.map((a) => a.studentId).toSet();
    for (final id in ids) {
      if (!_studentCache.containsKey(id)) {
        final u = await _userService.getUserById(id);
        if (u != null && mounted) setState(() => _studentCache[id] = u);
      }
    }
  }

  /// Group activities by (title, date-day) → list of per-student records
  Map<String, List<ActivityModel>> _group(List<ActivityModel> all) {
    final map = <String, List<ActivityModel>>{};
    for (final a in all) {
      final key = '${a.title}__${a.date.year}-${a.date.month}-${a.date.day}__${a.category.name}';
      map.putIfAbsent(key, () => []).add(a);
    }
    return map;
  }

  List<ActivityModel> _applyFilters(List<ActivityModel> all) {
    return all.where((a) {
      final matchCat = _filterCategory == null || a.category == _filterCategory;
      final matchSearch = _searchQuery.isEmpty ||
          a.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          a.description.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchCat && matchSearch;
    }).toList();
  }

  Future<void> _deleteGroup(List<ActivityModel> group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Activity', style: TextStyle(fontFamily: 'Georgia')),
        content: Text(
          'Delete "${group.first.title}" for ${group.length} student(s)?',
          style: const TextStyle(fontFamily: 'Georgia'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
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
        const SnackBar(content: Text('Activity deleted'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final teacherId = context.read<AuthProvider>().currentUser!.uid;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
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
                    MaterialPageRoute(builder: (_) => const CreateActivityScreen()),
                  ),
                ),
              ],
            )
          : null,
      body: Column(
        children: [
          // ── Search + Filter bar ──────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search activities…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.backgroundLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
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
              ],
            ),
          ),

          // ── Activity list ────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<ActivityModel>>(
              stream: _activityService.streamByTeacher(teacherId),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }

                final all = snap.data ?? [];
                _prefetchStudents(all);

                final filtered = _applyFilters(all);
                if (filtered.isEmpty) {
                  return _EmptyState(hasFilter: _filterCategory != null || _searchQuery.isNotEmpty);
                }

                final groups = _group(filtered);
                final keys = groups.keys.toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: keys.length,
                  itemBuilder: (_, i) {
                    final group = groups[keys[i]]!;
                    final rep = group.first; // representative activity
                    return _ActivityGroupCard(
                      group: group,
                      representative: rep,
                      studentCache: _studentCache,
                      onDelete: () => _deleteGroup(group),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateActivityScreen()),
        ),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Activity', style: TextStyle(color: Colors.white, fontFamily: 'Georgia')),
      ),
    );
  }
}

// ── Group Card ────────────────────────────────────────────────────────────────

class _ActivityGroupCard extends StatelessWidget {
  final List<ActivityModel> group;
  final ActivityModel representative;
  final Map<String, UserModel> studentCache;
  final VoidCallback onDelete;

  const _ActivityGroupCard({
    required this.group,
    required this.representative,
    required this.studentCache,
    required this.onDelete,
  });

  Color get _statusColor {
    final statuses = group.map((a) => a.status).toSet();
    if (statuses.every((s) => s == ActivityStatus.completed)) return AppColors.success;
    if (statuses.any((s) => s == ActivityStatus.inProgress)) return AppColors.warning;
    if (statuses.every((s) => s == ActivityStatus.skipped)) return AppColors.error;
    return AppColors.textSecondary;
  }

  String get _statusLabel {
    final completed = group.where((a) => a.status == ActivityStatus.completed).length;
    return '$completed/${group.length} completed';
  }

  @override
  Widget build(BuildContext context) {
    final d = representative.date;
    final dateStr = '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
    final timeStr = '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.04),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      representative.category.emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        representative.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          fontFamily: 'Georgia',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        representative.category.label,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontFamily: 'Georgia',
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                  onSelected: (v) {
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: AppColors.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Meta row
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('$dateStr  $timeStr',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(width: 16),
                    if (representative.duration != null) ...[
                      const Icon(Icons.timer_outlined, size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('${representative.duration} min',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(width: 16),
                    ],
                    const Icon(Icons.people_outline, size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('${group.length} student${group.length > 1 ? 's' : ''}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),

                if (representative.description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    representative.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  ),
                ],

                const SizedBox(height: 12),

                // Status badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _statusColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, size: 13, color: _statusColor),
                          const SizedBox(width: 5),
                          Text(
                            _statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (!representative.isVisibleToParent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.visibility_off, size: 12, color: AppColors.warning),
                            SizedBox(width: 4),
                            Text('Private', style: TextStyle(fontSize: 11, color: AppColors.warning)),
                          ],
                        ),
                      ),
                  ],
                ),

                // Students chips
                if (group.length <= 5) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: group.map((a) {
                      final student = studentCache[a.studentId];
                      final name = student?.fullName ?? '…';
                      final isCompleted = a.status == ActivityStatus.completed;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? AppColors.success.withOpacity(0.08)
                              : AppColors.backgroundLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isCompleted
                                ? AppColors.success.withOpacity(0.3)
                                : AppColors.divider,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isCompleted)
                              const Icon(Icons.check, size: 11, color: AppColors.success),
                            if (isCompleted) const SizedBox(width: 4),
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 11,
                                color: isCompleted ? AppColors.success : AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
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
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? Colors.white : AppColors.textSecondary,
            fontFamily: 'Georgia',
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_note_outlined, size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            hasFilter ? 'No activities match your filters' : 'No activities yet',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasFilter ? 'Try adjusting your search or filters.' : 'Create your first activity!',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
