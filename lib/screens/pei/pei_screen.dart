import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/permissions.dart';
import '../../l10n/app_strings.dart';
import '../../models/pei_model.dart';
import '../../models/user_model.dart';
import '../../services/pei_service.dart';
import '../../widgets/kid_ui.dart';
import '../../widgets/user_avatar.dart';
import 'pei_detail_screen.dart';
import 'pei_form_screen.dart';
import 'pei_widgets.dart';

/// Entry point of the PEI module for one student: lists all his/her plans.
///
/// Used by: admin (user details), teacher (my students), parent (dashboard).
/// Parents only see non-draft plans and cannot edit.
class PeiScreen extends StatefulWidget {
  final UserModel student;
  final UserModel viewer;
  const PeiScreen({super.key, required this.student, required this.viewer});

  @override
  State<PeiScreen> createState() => _PeiScreenState();
}

class _PeiScreenState extends State<PeiScreen> {
  final _service = PeiService();
  late final Stream<List<PeiModel>> _stream =
      _service.streamByStudent(widget.student.uid);

  bool get _canEdit => Permissions.canEditPei(widget.viewer);
  bool get _viewerIsParent => widget.viewer.role == UserRole.student;

  Future<void> _create() async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PeiFormScreen(student: widget.student, author: widget.viewer),
      ),
    );
    if (id != null && mounted) _open(id);
  }

  void _open(String planId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PeiDetailScreen(
          planId: planId,
          student: widget.student,
          viewer: widget.viewer,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    return Scaffold(
      backgroundColor: context.pageBg,
      floatingActionButton: _canEdit
          ? FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.add_rounded),
              label: Text(context.tr('pei.new')),
            )
          : null,
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: PlayfulHeader(
            gradient: AppColors.mintGradient,
            child: SafeArea(
              bottom: false,
              child: Column(children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: const BackButton(color: Colors.white),
                ),
                UserAvatar(user: s, radius: 42),
                const SizedBox(height: 10),
                Text(s.fullName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('🎯 ${context.tr('pei.fullTitle')}',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          sliver: SliverToBoxAdapter(
            child: StreamBuilder<List<PeiModel>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                        context.tr('common.error', args: {'error': '${snap.error}'}),
                        style: const TextStyle(color: AppColors.error)),
                  );
                }
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                var plans = snap.data ?? const <PeiModel>[];
                if (_viewerIsParent) {
                  plans =
                      plans.where((p) => p.status != PeiStatus.draft).toList();
                }
                if (plans.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: EmptyState(
                      emoji: '🎯',
                      title: context.tr('pei.noPlan.title'),
                      subtitle: context.tr(
                          _canEdit ? 'pei.noPlan.edit' : 'pei.noPlan.view'),
                    ),
                  );
                }
                return Column(children: [
                  for (final p in plans)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: FadeSlideIn(
                          child: _PlanCard(plan: p, onTap: () => _open(p.id))),
                    ),
                ]);
              },
            ),
          ),
        ),
      ]),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PeiModel plan;
  final VoidCallback onTap;
  const _PlanCard({required this.plan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pct = (plan.overallProgress * 100).round();
    final days = plan.daysToReview;
    final overdue = days != null && days < 0 && plan.isOpen;

    return PlayfulCard(
      accent: peiStatusColor(plan.status),
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('${context.tr('pei.title')} ${plan.academicYear}',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary)),
          ),
          PeiPill(
              label: context.tr('pei.status.${plan.status.name}'),
              color: peiStatusColor(plan.status)),
        ]),
        const SizedBox(height: 4),
        Text(
          '${peiFmtDate(plan.startDate)}'
          '${plan.endDate != null ? '  →  ${peiFmtDate(plan.endDate!)}' : ''}',
          style: TextStyle(fontSize: 12, color: context.textSecondary),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: PeiProgressBar(value: plan.overallProgress, color: AppColors.success)),
          const SizedBox(width: 10),
          Text('$pct%',
              style: TextStyle(
                  fontWeight: FontWeight.w800, color: context.textPrimary)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          PeiPill(
              label: context.tr('pei.progress.achieved',
                  args: {'done': plan.achievedCount, 'total': plan.goals.length}),
              color: AppColors.grape,
              icon: Icons.flag_rounded),
          if (overdue)
            PeiPill(
                label: context.tr('pei.reviewOverdue', args: {'n': -(days ?? 0)}),
                color: AppColors.error,
                icon: Icons.event_repeat_rounded),
        ]),
      ]),
    );
  }
}
