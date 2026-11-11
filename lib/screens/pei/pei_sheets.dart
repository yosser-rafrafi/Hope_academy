import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../l10n/app_strings.dart';
import '../../models/pei_model.dart';
import '../../models/user_model.dart';
import '../../services/pei_service.dart';
import 'pei_widgets.dart';

Widget _sheetShell(BuildContext context, {required Widget child}) {
  return Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              child,
            ],
          ),
        ),
      ),
    ),
  );
}

Future<DateTime?> _pickDate(BuildContext context, DateTime initial,
    {DateTime? first, DateTime? last}) {
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first ?? DateTime(2020),
    lastDate: last ?? DateTime(2100),
    helpText: context.tr('common.pickDate'),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Goal sheet  →  returns the goal to save (or null if cancelled)
// ═════════════════════════════════════════════════════════════════════════════

Future<PeiGoal?> showPeiGoalSheet(BuildContext context, {PeiGoal? existing}) {
  return showModalBottomSheet<PeiGoal>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GoalSheet(existing: existing),
  );
}

class _GoalSheet extends StatefulWidget {
  final PeiGoal? existing;
  const _GoalSheet({this.existing});

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _desc = TextEditingController(text: widget.existing?.description);
  late final _strategies =
      TextEditingController(text: widget.existing?.strategies);
  late final _criteria = TextEditingController(text: widget.existing?.criteria);

  late PeiDomain _domain = widget.existing?.domain ?? PeiDomain.communication;
  late GoalStatus _status = widget.existing?.status ?? GoalStatus.notStarted;
  late int _baseline = widget.existing?.baselineLevel ?? 0;
  late int _target = widget.existing?.targetLevel ?? kPeiMaxLevel;
  late DateTime? _targetDate = widget.existing?.targetDate;

  bool get _editing => widget.existing != null;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _strategies.dispose();
    _criteria.dispose();
    super.dispose();
  }

  String? _clean(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final old = widget.existing;
    // No observation yet → the current level simply follows the baseline.
    final current =
        (old == null || old.lastObservedAt == null) ? _baseline : old.currentLevel;
    Navigator.pop(
      context,
      PeiGoal(
        id: old?.id ?? PeiService.newGoalId(),
        title: _title.text.trim(),
        description: _clean(_desc),
        domain: _domain,
        status: _status,
        baselineLevel: _baseline,
        targetLevel: _target,
        currentLevel: current,
        targetDate: _targetDate,
        strategies: _clean(_strategies),
        criteria: _clean(_criteria),
        lastObservedAt: old?.lastObservedAt,
        createdAt: old?.createdAt ?? DateTime.now(),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text(text,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: context.textPrimary)),
      );

  @override
  Widget build(BuildContext context) {
    return _sheetShell(
      context,
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr(_editing ? 'pei.editGoal' : 'pei.addGoal'),
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary)),
          const SizedBox(height: 14),
          TextFormField(
            controller: _title,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: context.tr('pei.goal.title')),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? context.tr('common.required')
                : null,
          ),
          _label(context.tr('pei.goal.domain')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in PeiDomain.values)
                ChoiceChip(
                  selected: _domain == d,
                  showCheckmark: false,
                  label: Text('${d.emoji} ${context.tr('pei.domain.${d.name}')}',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _domain == d
                              ? Colors.white
                              : context.textPrimary)),
                  selectedColor: AppColors.primary,
                  onSelected: (_) => setState(() => _domain = d),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _desc,
            minLines: 2,
            maxLines: 4,
            decoration:
                InputDecoration(labelText: context.tr('pei.goal.description')),
          ),
          _label('${context.tr('pei.goal.baseline')}  ·  ${context.tr('pei.scale')}'),
          PeiLevelPicker(
            value: _baseline,
            max: _target,
            onChanged: (v) => setState(() => _baseline = v),
          ),
          _label(context.tr('pei.goal.target')),
          PeiLevelPicker(
            value: _target,
            min: _baseline,
            onChanged: (v) => setState(() => _target = v),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _criteria,
            decoration: InputDecoration(
                labelText:
                    '${context.tr('pei.goal.criteria')} (${context.tr('common.optional')})'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _strategies,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
                labelText:
                    '${context.tr('pei.goal.strategies')} (${context.tr('common.optional')})'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final d = await _pickDate(
                  context, _targetDate ?? DateTime.now().add(const Duration(days: 90)));
              if (d != null) setState(() => _targetDate = d);
            },
            icon: const Icon(Icons.event_outlined, size: 18),
            label: Text(_targetDate == null
                ? context.tr('pei.goal.targetDate')
                : '${context.tr('pei.goal.targetDate')} : ${peiFmtDate(_targetDate!)}'),
          ),
          if (_targetDate != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => setState(() => _targetDate = null),
                child: Text(context.tr('common.delete')),
              ),
            ),
          if (_editing) ...[
            _label(context.tr('pei.status')),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in GoalStatus.values)
                ChoiceChip(
                  selected: _status == s,
                  showCheckmark: false,
                  label: Text(context.tr('pei.goal.status.${s.name}'),
                      style: TextStyle(
                          fontSize: 12.5,
                          color:
                              _status == s ? Colors.white : context.textPrimary)),
                  selectedColor: peiGoalStatusColor(s),
                  onSelected: (_) => setState(() => _status = s),
                ),
            ]),
          ],
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.tr('common.cancel')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(context.tr('common.save')),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Progress sheet  →  returns the observation to record (or null)
// ═════════════════════════════════════════════════════════════════════════════

Future<PeiProgressEntry?> showPeiProgressSheet(
  BuildContext context, {
  required PeiGoal goal,
  required UserModel recorder,
}) {
  return showModalBottomSheet<PeiProgressEntry>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProgressSheet(goal: goal, recorder: recorder),
  );
}

class _ProgressSheet extends StatefulWidget {
  final PeiGoal goal;
  final UserModel recorder;
  const _ProgressSheet({required this.goal, required this.recorder});

  @override
  State<_ProgressSheet> createState() => _ProgressSheetState();
}

class _ProgressSheetState extends State<_ProgressSheet> {
  final _note = TextEditingController();
  late int _level = widget.goal.currentLevel;
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final now = DateTime.now();
    Navigator.pop(
      context,
      PeiProgressEntry(
        id: '',
        goalId: widget.goal.id,
        level: _level,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        date: DateTime(_date.year, _date.month, _date.day),
        recordedById: widget.recorder.uid,
        recordedByName: widget.recorder.fullName,
        createdAt: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.goal;
    return _sheetShell(
      context,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(context.tr('pei.progress.add'),
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: context.textPrimary)),
        const SizedBox(height: 4),
        Text('${g.domain.emoji} ${g.title}',
            style: TextStyle(color: context.textSecondary, fontSize: 13)),
        const SizedBox(height: 16),
        Text('${context.tr('pei.progress.level')}  ·  ${context.tr('pei.scale')}',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: context.textPrimary)),
        const SizedBox(height: 8),
        PeiLevelPicker(value: _level, onChanged: (v) => setState(() => _level = v)),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () async {
            final d = await _pickDate(context, _date, last: DateTime.now());
            if (d != null) setState(() => _date = d);
          },
          icon: const Icon(Icons.event_outlined, size: 18),
          label: Text('${context.tr('pei.progress.date')} : ${peiFmtDate(_date)}'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          minLines: 2,
          maxLines: 5,
          decoration: InputDecoration(
              labelText:
                  '${context.tr('pei.progress.note')} (${context.tr('common.optional')})'),
        ),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('common.cancel')),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.trending_up_rounded, size: 18),
              label: Text(context.tr('common.save')),
            ),
          ),
        ]),
      ]),
    );
  }
}
