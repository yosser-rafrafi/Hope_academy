import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/app_colors.dart';
import '../../core/permissions.dart';
import '../../l10n/app_strings.dart';
import '../../models/pei_model.dart';
import '../../models/user_model.dart';
import '../../services/pei_report_service.dart';
import '../../services/pei_service.dart';
import '../../widgets/kid_ui.dart';
import 'pei_form_screen.dart';
import 'pei_sheets.dart';
import 'pei_widgets.dart';

/// One PEI: header (status, dates, overall progress), student profile, goals
/// with progress bars, and — per goal — the observation history + chart.
/// Teachers/admins edit; parents get the same screen in read-only mode.
class PeiDetailScreen extends StatefulWidget {
  final String planId;
  final UserModel student;
  final UserModel viewer;
  const PeiDetailScreen({
    super.key,
    required this.planId,
    required this.student,
    required this.viewer,
  });

  @override
  State<PeiDetailScreen> createState() => _PeiDetailScreenState();
}

class _PeiDetailScreenState extends State<PeiDetailScreen> {
  final _service = PeiService();
  late final Stream<PeiModel?> _planStream = _service.streamPlan(widget.planId);
  bool _busy = false;

  bool get _canEdit => Permissions.canEditPei(widget.viewer);
  bool get _canManage => Permissions.canManagePei(widget.viewer);

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : AppColors.success,
    ));
  }

  Future<void> _guard(Future<void> Function() action, {String? ok}) async {
    try {
      await action();
      if (ok != null) _toast(ok);
    } catch (e) {
      _toast(context.tr('common.error', args: {'error': '$e'}), error: true);
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _addGoal() async {
    final goal = await showPeiGoalSheet(context);
    if (goal == null) return;
    await _guard(() => _service.saveGoal(widget.planId, goal),
        ok: context.tr('common.saved'));
  }

  Future<void> _editPlan(PeiModel plan) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PeiFormScreen(
            student: widget.student, author: widget.viewer, existing: plan),
      ),
    );
  }

  Future<void> _export(PeiModel plan, {required bool print}) async {
    setState(() => _busy = true);
    try {
      final strings = context.strings;
      final entries = await _service.getProgress(plan.id);
      final bytes = await PeiReportService.buildPdf(
          plan: plan, entries: entries, s: strings);
      final name = 'PEI_${plan.studentName.replaceAll(' ', '_')}_'
          '${plan.academicYear.replaceAll('/', '-')}';
      if (print) {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
      } else {
        await Printing.sharePdf(bytes: bytes, filename: '$name.pdf');
      }
    } catch (e) {
      _toast(context.tr('common.error', args: {'error': '$e'}), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openGoal(PeiModel plan, PeiGoal goal) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GoalDetailSheet(
        service: _service,
        planId: plan.id,
        goalId: goal.id,
        viewer: widget.viewer,
        canEdit: _canEdit,
        canDelete: _canManage,
      ),
    );
  }

  Future<void> _recordProgress(PeiGoal goal) async {
    final entry = await showPeiProgressSheet(context,
        goal: goal, recorder: widget.viewer);
    if (entry == null) return;
    await _guard(() => _service.addProgress(widget.planId, entry),
        ok: context.tr('pei.progress.recorded'));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PeiModel?>(
      stream: _planStream,
      builder: (context, snap) {
        final plan = snap.data;
        return Scaffold(
          backgroundColor: context.pageBg,
          appBar: AppBar(
            title: Text(
              context.tr('pei.of', args: {'name': widget.student.firstName}),
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              if (plan != null) ...[
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  )
                else
                  PopupMenuButton<String>(
                    tooltip: context.tr('common.export'),
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    onSelected: (v) => _export(plan, print: v == 'print'),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                          value: 'share',
                          child: ListTile(
                            leading: const Icon(Icons.ios_share_rounded),
                            title: Text(context.tr('common.share')),
                            contentPadding: EdgeInsets.zero,
                          )),
                      PopupMenuItem(
                          value: 'print',
                          child: ListTile(
                            leading: const Icon(Icons.print_rounded),
                            title: Text(context.tr('common.print')),
                            contentPadding: EdgeInsets.zero,
                          )),
                    ],
                  ),
                if (_canEdit)
                  IconButton(
                    tooltip: context.tr('pei.edit'),
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editPlan(plan),
                  ),
              ],
            ],
          ),
          floatingActionButton: (plan != null && _canEdit)
              ? FloatingActionButton.extended(
                  onPressed: _addGoal,
                  icon: const Icon(Icons.flag_rounded),
                  label: Text(context.tr('pei.addGoal')),
                )
              : null,
          body: () {
            if (snap.hasError) {
              return Center(
                child: Text(
                    context.tr('common.error', args: {'error': '${snap.error}'}),
                    style: const TextStyle(color: AppColors.error)),
              );
            }
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (plan == null) {
              return EmptyState(title: context.tr('pei.noPlan.title'));
            }
            return _body(plan);
          }(),
        );
      },
    );
  }

  Widget _body(PeiModel plan) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        FadeSlideIn(child: _HeaderCard(plan: plan)),
        const SizedBox(height: 14),
        if (_canEdit)
          _StatusRow(
            plan: plan,
            onChanged: (s) =>
                _guard(() => _service.setStatus(plan.id, s), ok: context.tr('common.saved')),
          ),
        if (_hasProfile(plan)) ...[
          const SizedBox(height: 6),
          _ProfileCard(plan: plan),
        ],
        const SizedBox(height: 18),
        SectionTitle(
          title:
              '${context.tr('pei.goals')} · ${context.tr('pei.goals.count', args: {'n': plan.goals.length})}',
          icon: Icons.flag_rounded,
          color: AppColors.grape,
        ),
        const SizedBox(height: 10),
        if (plan.goals.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(context.tr('pei.goals.empty'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textSecondary)),
            ),
          )
        else
          for (final g in plan.goals)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _GoalCard(
                goal: g,
                canRecord: _canEdit && plan.isOpen,
                onTap: () => _openGoal(plan, g),
                onRecord: () => _recordProgress(g),
              ),
            ),
        if (!_canEdit)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: PeiPill(
                label: context.tr('common.readOnly'),
                color: AppColors.textSecondary,
                icon: Icons.visibility_outlined,
              ),
            ),
          ),
      ],
    );
  }

  bool _hasProfile(PeiModel p) =>
      (p.strengths ?? '').trim().isNotEmpty ||
      (p.needs ?? '').trim().isNotEmpty ||
      p.accommodations.isNotEmpty ||
      (p.familyInput ?? '').trim().isNotEmpty;
}

// ═════════════════════════════════════════════════════════════════════════════
// Header
// ═════════════════════════════════════════════════════════════════════════════

class _HeaderCard extends StatelessWidget {
  final PeiModel plan;
  const _HeaderCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final pct = (plan.overallProgress * 100).round();
    final days = plan.daysToReview;
    String? reviewText;
    Color reviewColor = AppColors.info;
    if (days != null && plan.isOpen) {
      if (days < 0) {
        reviewText = context.tr('pei.reviewOverdue', args: {'n': -days});
        reviewColor = AppColors.error;
      } else if (days == 0) {
        reviewText = context.tr('pei.reviewToday');
        reviewColor = AppColors.warning;
      } else {
        reviewText = context.tr('pei.reviewIn', args: {'n': days});
        reviewColor = days <= 14 ? AppColors.warning : AppColors.info;
      }
    }

    return PlayfulCard(
      accent: peiStatusColor(plan.status),
      padding: const EdgeInsets.all(18),
      child: Row(children: [
        SizedBox(
          width: 78,
          height: 78,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: plan.overallProgress,
                strokeWidth: 8,
                color: AppColors.success,
                backgroundColor: AppColors.success.withAlpha(30),
              ),
            ),
            Text('$pct%',
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary)),
          ]),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('pei.progress.overall'),
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary)),
            const SizedBox(height: 2),
            Text(
              context.tr('pei.progress.achieved', args: {
                'done': plan.achievedCount,
                'total': plan.goals.length,
              }),
              style: TextStyle(fontSize: 12.5, color: context.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              PeiPill(
                  label: context.tr('pei.status.${plan.status.name}'),
                  color: peiStatusColor(plan.status)),
              PeiPill(
                  label: plan.academicYear,
                  color: AppColors.primaryLight,
                  icon: Icons.school_outlined),
              if (reviewText != null)
                PeiPill(
                    label: reviewText,
                    color: reviewColor,
                    icon: Icons.event_repeat_rounded),
            ]),
            const SizedBox(height: 6),
            Text(
              '${peiFmtDate(plan.startDate)}'
              '${plan.endDate != null ? '  →  ${peiFmtDate(plan.endDate!)}' : ''}'
              '  ·  ${context.tr('pei.createdBy', args: {'name': plan.createdByName})}',
              style: TextStyle(fontSize: 11, color: context.textSecondary),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final PeiModel plan;
  final ValueChanged<PeiStatus> onChanged;
  const _StatusRow({required this.plan, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        Text('${context.tr('pei.changeStatus')} :',
            style: TextStyle(fontSize: 12, color: context.textSecondary)),
        const SizedBox(width: 8),
        for (final s in PeiStatus.values)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 6),
            child: ChoiceChip(
              selected: plan.status == s,
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              label: Text(context.tr('pei.status.${s.name}'),
                  style: TextStyle(
                      fontSize: 12,
                      color: plan.status == s ? Colors.white : context.textPrimary)),
              selectedColor: peiStatusColor(s),
              onSelected: (_) {
                if (plan.status != s) onChanged(s);
              },
            ),
          ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Profile
// ═════════════════════════════════════════════════════════════════════════════

class _ProfileCard extends StatelessWidget {
  final PeiModel plan;
  const _ProfileCard({required this.plan});

  Widget _block(BuildContext context, String title, Widget body) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: context.brand)),
          const SizedBox(height: 4),
          body,
        ]),
      );

  Widget _text(BuildContext context, String t) => Text(t,
      style: TextStyle(fontSize: 13.5, height: 1.4, color: context.textPrimary));

  @override
  Widget build(BuildContext context) {
    return PlayfulCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: SizedBox(
        width: double.infinity,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionTitle(
            title: context.tr('pei.section.profile'),
            icon: Icons.person_outline_rounded,
            color: AppColors.sky,
          ),
          const SizedBox(height: 12),
          if ((plan.strengths ?? '').trim().isNotEmpty)
            _block(context, '💪 ${context.tr('pei.strengths')}',
                _text(context, plan.strengths!.trim())),
          if ((plan.needs ?? '').trim().isNotEmpty)
            _block(context, '🎯 ${context.tr('pei.needs')}',
                _text(context, plan.needs!.trim())),
          if (plan.accommodations.isNotEmpty)
            _block(
              context,
              '🧰 ${context.tr('pei.accommodations')}',
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final a in plan.accommodations)
                  PeiPill(label: a, color: AppColors.primaryLight),
              ]),
            ),
          if ((plan.familyInput ?? '').trim().isNotEmpty)
            _block(context, '🏠 ${context.tr('pei.family')}',
                _text(context, plan.familyInput!.trim())),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Goal card
// ═════════════════════════════════════════════════════════════════════════════

class _GoalCard extends StatelessWidget {
  final PeiGoal goal;
  final bool canRecord;
  final VoidCallback onTap;
  final VoidCallback onRecord;
  const _GoalCard({
    required this.goal,
    required this.canRecord,
    required this.onTap,
    required this.onRecord,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = peiGoalStatusColor(goal.status);
    final pct = (goal.progress * 100).round();
    final overdue = goal.targetDate != null &&
        !goal.isAchieved &&
        goal.targetDate!.isBefore(DateTime.now());

    return PlayfulCard(
      accent: statusColor,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(goal.domain.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(goal.title,
                  style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary)),
              Text(context.tr('pei.domain.${goal.domain.name}'),
                  style: TextStyle(fontSize: 11.5, color: context.textSecondary)),
            ]),
          ),
          PeiPill(
              label: context.tr('pei.goal.status.${goal.status.name}'),
              color: statusColor),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: PeiProgressBar(
                value: goal.progress,
                color: goal.isAchieved ? AppColors.success : AppColors.sky),
          ),
          const SizedBox(width: 10),
          Text('$pct%',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          PeiLevelChip(level: goal.currentLevel),
          Text('→ ${goal.targetLevel}',
              style: TextStyle(fontSize: 12, color: context.textSecondary)),
          if (goal.targetDate != null)
            PeiPill(
              label: peiFmtDate(goal.targetDate!),
              color: overdue ? AppColors.error : AppColors.textSecondary,
              icon: Icons.event_outlined,
            ),
        ]),
        if (canRecord) ...[
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: onRecord,
              icon: const Icon(Icons.trending_up_rounded, size: 18),
              label: Text(context.tr('pei.progress.add')),
            ),
          ),
        ],
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Goal detail sheet: info + chart + history (live)
// ═════════════════════════════════════════════════════════════════════════════

class _GoalDetailSheet extends StatefulWidget {
  final PeiService service;
  final String planId;
  final String goalId;
  final UserModel viewer;
  final bool canEdit;
  final bool canDelete;
  const _GoalDetailSheet({
    required this.service,
    required this.planId,
    required this.goalId,
    required this.viewer,
    required this.canEdit,
    required this.canDelete,
  });

  @override
  State<_GoalDetailSheet> createState() => _GoalDetailSheetState();
}

class _GoalDetailSheetState extends State<_GoalDetailSheet> {
  late final Stream<PeiModel?> _plan = widget.service.streamPlan(widget.planId);
  late final Stream<List<PeiProgressEntry>> _progress =
      widget.service.streamProgress(widget.planId);

  Future<void> _edit(PeiGoal goal) async {
    final updated = await showPeiGoalSheet(context, existing: goal);
    if (updated == null) return;
    try {
      await widget.service.saveGoal(widget.planId, updated);
    } catch (e) {
      _err(e);
    }
  }

  Future<void> _record(PeiGoal goal) async {
    final entry = await showPeiProgressSheet(context,
        goal: goal, recorder: widget.viewer);
    if (entry == null) return;
    try {
      await widget.service.addProgress(widget.planId, entry);
    } catch (e) {
      _err(e);
    }
  }

  Future<void> _delete(PeiGoal goal) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(ctx.tr('pei.goal.deleteConfirm')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.tr('common.cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.tr('common.delete'),
                  style: const TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.service.deleteGoal(widget.planId, goal.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _err(e);
    }
  }

  void _err(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(context.tr('common.error', args: {'error': '$e'})),
      backgroundColor: AppColors.error,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scroll) => Container(
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: StreamBuilder<PeiModel?>(
          stream: _plan,
          builder: (context, planSnap) {
            final plan = planSnap.data;
            PeiGoal? goal;
            if (plan != null) {
              for (final g in plan.goals) {
                if (g.id == widget.goalId) goal = g;
              }
            }
            if (goal == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final g = goal;
            final canRecord = widget.canEdit && plan!.isOpen;

            return StreamBuilder<List<PeiProgressEntry>>(
              stream: _progress,
              builder: (context, snap) {
                final entries = (snap.data ?? const <PeiProgressEntry>[])
                    .where((e) => e.goalId == g.id)
                    .toList(); // already newest-first

                return ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                            color: context.divider,
                            borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(children: [
                      Text(g.domain.emoji, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(g.title,
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: context.textPrimary)),
                      ),
                      if (widget.canEdit)
                        IconButton(
                          tooltip: context.tr('common.edit'),
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _edit(g),
                        ),
                      if (widget.canDelete)
                        IconButton(
                          tooltip: context.tr('common.delete'),
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: AppColors.error),
                          onPressed: () => _delete(g),
                        ),
                    ]),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      PeiPill(
                          label: context.tr('pei.goal.status.${g.status.name}'),
                          color: peiGoalStatusColor(g.status)),
                      PeiPill(
                          label: context.tr('pei.domain.${g.domain.name}'),
                          color: AppColors.primaryLight),
                      if (g.targetDate != null)
                        PeiPill(
                            label: peiFmtDate(g.targetDate!),
                            color: AppColors.textSecondary,
                            icon: Icons.event_outlined),
                    ]),
                    if ((g.description ?? '').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(g.description!,
                          style: TextStyle(
                              fontSize: 13.5,
                              height: 1.4,
                              color: context.textPrimary)),
                    ],
                    const SizedBox(height: 14),
                    _infoRow(context, context.tr('pei.goal.baseline'), g.baselineLevel),
                    _infoRow(context, context.tr('pei.goal.current'), g.currentLevel),
                    _infoRow(context, context.tr('pei.goal.target'), g.targetLevel),
                    if (g.baselineLevel != g.currentLevel)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          context.tr('pei.progress.sinceStart', args: {
                            'delta': g.delta > 0 ? '+${g.delta}' : '${g.delta}',
                          }),
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: g.delta >= 0
                                  ? AppColors.success
                                  : AppColors.error),
                        ),
                      ),
                    if ((g.criteria ?? '').isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _titled(context, '✅ ${context.tr('pei.goal.criteria')}', g.criteria!),
                    ],
                    if ((g.strategies ?? '').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _titled(context, '🧰 ${context.tr('pei.goal.strategies')}', g.strategies!),
                    ],
                    const SizedBox(height: 18),
                    SectionTitle(
                      title: context.tr('pei.progress.evolution'),
                      icon: Icons.show_chart_rounded,
                      color: AppColors.sky,
                      trailing: canRecord
                          ? TextButton.icon(
                              onPressed: () => _record(g),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: Text(context.tr('common.add')),
                            )
                          : null,
                    ),
                    const SizedBox(height: 10),
                    if (entries.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Center(
                          child: Text(context.tr('pei.progress.empty'),
                              style: TextStyle(color: context.textSecondary)),
                        ),
                      )
                    else ...[
                      PeiLevelChart(entries: entries, targetLevel: g.targetLevel),
                      const SizedBox(height: 14),
                      Text(context.tr('pei.progress.history'),
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: context.textPrimary)),
                      const SizedBox(height: 8),
                      for (final e in entries) _EntryTile(entry: e),
                    ],
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, int level) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 13, color: context.textSecondary)),
          ),
          PeiLevelChip(level: level),
        ]),
      );

  Widget _titled(BuildContext context, String title, String body) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: context.brand)),
        const SizedBox(height: 4),
        Text(body,
            style: TextStyle(fontSize: 13.5, height: 1.4, color: context.textPrimary)),
      ]);
}

class _EntryTile extends StatelessWidget {
  final PeiProgressEntry entry;
  const _EntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final c = peiLevelColor(entry.level);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.softFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.divider),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text('${entry.level}',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(context.tr('pei.level.${entry.level}'),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary)),
              ),
              Text(peiFmtDate(entry.date),
                  style: TextStyle(fontSize: 11.5, color: context.textSecondary)),
            ]),
            if ((entry.note ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(entry.note!,
                  style: TextStyle(
                      fontSize: 13, height: 1.35, color: context.textPrimary)),
            ],
            const SizedBox(height: 4),
            Text(context.tr('pei.progress.by', args: {'name': entry.recordedByName}),
                style: TextStyle(fontSize: 11, color: context.textSecondary)),
          ]),
        ),
      ]),
    );
  }
}
