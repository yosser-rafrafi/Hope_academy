import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../l10n/app_strings.dart';
import '../../models/pei_model.dart';
import '../../models/student_model.dart';
import '../../models/user_model.dart';
import '../../services/pei_service.dart';
import 'pei_widgets.dart';

/// Create or edit the profile part of a PEI (goals are managed on the detail
/// screen). Pops with the plan id once saved.
class PeiFormScreen extends StatefulWidget {
  final UserModel student;
  final UserModel author;
  final PeiModel? existing;
  const PeiFormScreen({
    super.key,
    required this.student,
    required this.author,
    this.existing,
  });

  @override
  State<PeiFormScreen> createState() => _PeiFormScreenState();
}

class _PeiFormScreenState extends State<PeiFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = PeiService();
  bool _saving = false;

  late final _year = TextEditingController(
      text: widget.existing?.academicYear ?? _defaultYear());
  late final _strengths = TextEditingController(text: widget.existing?.strengths);
  late final _needs = TextEditingController(text: widget.existing?.needs);
  late final _family = TextEditingController(text: widget.existing?.familyInput);
  late final _accommodations = TextEditingController(
      text: (widget.existing?.accommodations ?? const []).join('\n'));

  late DateTime _start = widget.existing?.startDate ?? DateTime.now();
  late DateTime? _review = widget.existing?.reviewDate ??
      DateTime.now().add(const Duration(days: 90));
  late DateTime? _end = widget.existing?.endDate;
  late PeiStatus _status = widget.existing?.status ?? PeiStatus.draft;

  bool get _editing => widget.existing != null;

  /// "2026/2027" from September, "2025/2026" before.
  static String _defaultYear() {
    final n = DateTime.now();
    final y = n.month >= 9 ? n.year : n.year - 1;
    return '$y/${y + 1}';
  }

  @override
  void dispose() {
    _year.dispose();
    _strengths.dispose();
    _needs.dispose();
    _family.dispose();
    _accommodations.dispose();
    super.dispose();
  }

  String? _clean(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _pick(DateTime? current, ValueChanged<DateTime> set) async {
    final d = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: context.tr('common.pickDate'),
    );
    if (d != null) setState(() => set(d));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final errorText = context.tr('common.error', args: {'error': ''});
    try {
      final accommodations = _accommodations.text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final now = DateTime.now();
      final old = widget.existing;
      final student = widget.student;

      final plan = PeiModel(
        id: old?.id ?? '',
        studentId: student.uid,
        studentName: student.fullName,
        classId: student is StudentModel ? student.classId : old?.classId,
        academicYear: _year.text.trim(),
        status: _status,
        startDate: DateTime(_start.year, _start.month, _start.day),
        reviewDate: _review,
        endDate: _end,
        strengths: _clean(_strengths),
        needs: _clean(_needs),
        accommodations: accommodations,
        familyInput: _clean(_family),
        goals: old?.goals ?? const [],
        createdById: old?.createdById ?? widget.author.uid,
        createdByName: old?.createdByName ?? widget.author.fullName,
        createdAt: old?.createdAt ?? now,
        updatedAt: now,
      );

      String id;
      if (old == null) {
        id = await _service.createPlan(plan);
      } else {
        await _service.updatePlanInfo(plan);
        id = old.id;
      }
      nav.pop(id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('$errorText$e'),
        backgroundColor: AppColors.error,
      ));
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _dateTile(String label, DateTime? value, VoidCallback onTap,
      {VoidCallback? onClear}) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 54),
          alignment: AlignmentDirectional.centerStart,
        ),
        child: Row(children: [
          const Icon(Icons.event_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 10.5, color: context.textSecondary)),
                Text(value == null ? '—' : peiFmtDate(value),
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          if (onClear != null && value != null)
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close_rounded, size: 16),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final optional = context.tr('common.optional');
    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        title: Text(context.tr(_editing ? 'pei.edit' : 'pei.new')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            Text(widget.student.fullName,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary)),
            const SizedBox(height: 14),
            TextFormField(
              controller: _year,
              decoration:
                  InputDecoration(labelText: context.tr('pei.academicYear')),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? context.tr('common.required')
                  : null,
            ),
            const SizedBox(height: 12),
            Row(children: [
              _dateTile(context.tr('pei.startDate'), _start,
                  () => _pick(_start, (d) => _start = d)),
              const SizedBox(width: 10),
              _dateTile(context.tr('pei.endDate'), _end,
                  () => _pick(_end ?? _start, (d) => _end = d),
                  onClear: () => setState(() => _end = null)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _dateTile(context.tr('pei.reviewDate'), _review,
                  () => _pick(_review, (d) => _review = d),
                  onClear: () => setState(() => _review = null)),
            ]),
            const SizedBox(height: 16),
            Text(context.tr('pei.status'),
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: context.textPrimary)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in PeiStatus.values)
                ChoiceChip(
                  selected: _status == s,
                  showCheckmark: false,
                  label: Text(context.tr('pei.status.${s.name}'),
                      style: TextStyle(
                          fontSize: 12.5,
                          color: _status == s ? Colors.white : context.textPrimary)),
                  selectedColor: peiStatusColor(s),
                  onSelected: (_) => setState(() => _status = s),
                ),
            ]),
            const SizedBox(height: 18),
            TextFormField(
              controller: _strengths,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: '${context.tr('pei.strengths')} ($optional)',
                hintText: context.tr('pei.strengths.hint'),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _needs,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: '${context.tr('pei.needs')} ($optional)',
                hintText: context.tr('pei.needs.hint'),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _accommodations,
              minLines: 2,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: '${context.tr('pei.accommodations')} ($optional)',
                hintText: context.tr('pei.accommodations.hint'),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _family,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                  labelText: '${context.tr('pei.family')} ($optional)'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check_rounded),
                label: Text(context.tr('common.save')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
