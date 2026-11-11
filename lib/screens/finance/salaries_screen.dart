import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/app_colors.dart';
import '../../core/finance_utils.dart';
import '../../core/permissions.dart';
import '../../l10n/app_strings.dart';
import '../../models/finance_model.dart';
import '../../models/user_model.dart';
import '../../services/finance_report_service.dart';
import '../../services/finance_service.dart';
import '../../services/user_service.dart';
import '../../widgets/kid_ui.dart';
import '../pei/pei_widgets.dart' show PeiPill, PeiProgressBar;
import 'finance_sheets.dart';

/// Monthly payroll (admin only): base salary comes from the user profile,
/// each month can be adjusted (bonus / deduction / note), marked as paid,
/// and exported as payroll statement or individual payslip.
class SalariesScreen extends StatefulWidget {
  final UserModel currentUser;
  const SalariesScreen({super.key, required this.currentUser});

  @override
  State<SalariesScreen> createState() => _SalariesScreenState();
}

class _SalariesScreenState extends State<SalariesScreen> {
  final _service = FinanceService();
  final _users = UserService();
  late final Stream<List<UserModel>> _teachers =
      _users.streamUsersByRole(UserRole.teacher);
  late final Stream<List<UserModel>> _subAdmins =
      _users.streamUsersByRole(UserRole.subAdmin);

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late Stream<List<SalaryRecord>> _records =
      _service.streamSalaries(monthKey(_month));
  bool _busy = false;

  String get _key => monthKey(_month);

  void _shift(int delta) => setState(() {
        _month = DateTime(_month.year, _month.month + delta);
        _records = _service.streamSalaries(_key);
      });

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : AppColors.success,
    ));
  }

  Future<void> _guard(Future<void> Function() fn) async {
    try {
      await fn();
    } catch (e) {
      _toast(context.tr('common.error', args: {'error': '$e'}), error: true);
    }
  }

  /// Existing record, or a virtual one built from the profile salary.
  SalaryRecord _recordFor(UserModel u, Map<String, SalaryRecord> saved) =>
      saved[SalaryRecord.idFor(u.uid, _key)] ??
      SalaryRecord(
        id: SalaryRecord.idFor(u.uid, _key),
        staffId: u.uid,
        staffName: u.fullName,
        roleLabel: u.role.label,
        month: _key,
        baseSalary: u.salary ?? 0,
      );

  Future<void> _adjust(SalaryRecord r) async {
    final updated = await showModalBottomSheet<SalaryRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdjustSheet(record: r),
    );
    if (updated == null) return;
    await _guard(() => _service.saveSalary(
        updated.copyWith(recordedByName: widget.currentUser.fullName)));
  }

  Future<void> _togglePaid(SalaryRecord r) => _guard(() => _service.saveSalary(
        r.paid
            ? r.copyWith(paid: false, clearPaidAt: true, recordedByName: widget.currentUser.fullName)
            : r.copyWith(paid: true, paidAt: DateTime.now(), recordedByName: widget.currentUser.fullName),
      ));

  Future<void> _pdf(Future<Uint8List> Function() build, String name,
      {bool print = false}) async {
    setState(() => _busy = true);
    try {
      final bytes = await build();
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

  @override
  Widget build(BuildContext context) {
    if (!Permissions.canViewSalaries(widget.currentUser)) {
      return Center(child: Text(context.tr('sal.accessDenied')));
    }
    return Scaffold(
      backgroundColor: context.pageBg,
      body: StreamBuilder<List<UserModel>>(
        stream: _teachers,
        builder: (context, tSnap) => StreamBuilder<List<UserModel>>(
          stream: _subAdmins,
          builder: (context, aSnap) => StreamBuilder<List<SalaryRecord>>(
            stream: _records,
            builder: (context, rSnap) {
              if (!tSnap.hasData || !aSnap.hasData || !rSnap.hasData) {
                if (tSnap.hasError || aSnap.hasError || rSnap.hasError) {
                  return Center(
                      child: Text(
                          context.tr('common.error', args: {
                            'error': '${tSnap.error ?? aSnap.error ?? rSnap.error}'
                          }),
                          style: const TextStyle(color: AppColors.error)));
                }
                return const Center(child: CircularProgressIndicator());
              }
              final saved = {for (final r in rSnap.data!) r.id: r};
              final staff = [...tSnap.data!, ...aSnap.data!]
                  .where((u) => u.isActive && (u.salary != null || saved.containsKey(SalaryRecord.idFor(u.uid, _key))))
                  .toList()
                ..sort((a, b) => a.fullName.compareTo(b.fullName));
              final records = [for (final u in staff) _recordFor(u, saved)];
              return _body(records);
            },
          ),
        ),
      ),
    );
  }

  Widget _body(List<SalaryRecord> records) {
    final total = records.fold<double>(0, (a, r) => a + r.net);
    final paidTotal = records.where((r) => r.paid).fold<double>(0, (a, r) => a + r.net);
    final paidCount = records.where((r) => r.paid).length;
    final strings = context.strings;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        Row(children: [
          Expanded(
            child: Text(context.tr('sal.title'),
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary)),
          ),
          if (_busy)
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
          else if (records.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: context.tr('sal.payroll'),
              icon: const Icon(Icons.picture_as_pdf_rounded),
              onSelected: (v) => _pdf(
                () => FinanceReportService.payrollPdf(
                    month: _key, records: records, s: strings),
                'payroll_$_key',
                print: v == 'print',
              ),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'share', child: Text(context.tr('common.share'))),
                PopupMenuItem(value: 'print', child: Text(context.tr('common.print'))),
              ],
            ),
        ]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
              onPressed: () => _shift(-1),
              icon: const Icon(Icons.chevron_left_rounded)),
          Text(_key,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary)),
          IconButton(
              onPressed: () => _shift(1),
              icon: const Icon(Icons.chevron_right_rounded)),
        ]),
        FadeSlideIn(
          child: PlayfulCard(
            accent: AppColors.success,
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.tr('sal.total'),
                  style: TextStyle(fontSize: 12.5, color: context.textSecondary)),
              Text(formatMoney(total),
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary)),
              const SizedBox(height: 10),
              PeiProgressBar(
                  value: total <= 0 ? 0 : paidTotal / total,
                  color: AppColors.success),
              const SizedBox(height: 8),
              Text(
                  context.tr('sal.paidCount',
                      args: {'done': paidCount, 'total': records.length}),
                  style: TextStyle(fontSize: 12.5, color: context.textSecondary)),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        if (records.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
                child: Text(context.tr('sal.noStaff'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.textSecondary))),
          )
        else
          for (final r in records)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _StaffCard(
                record: r,
                onAdjust: () => _adjust(r),
                onTogglePaid: () => _togglePaid(r),
                onPayslip: () => _pdf(
                  () => FinanceReportService.payslipPdf(record: r, s: strings),
                  'payslip_${r.staffName.replaceAll(' ', '_')}_$_key',
                ),
              ),
            ),
      ],
    );
  }
}

class _StaffCard extends StatelessWidget {
  final SalaryRecord record;
  final VoidCallback onAdjust, onTogglePaid, onPayslip;
  const _StaffCard({
    required this.record,
    required this.onAdjust,
    required this.onTogglePaid,
    required this.onPayslip,
  });

  @override
  Widget build(BuildContext context) {
    final r = record;
    final color = r.paid ? AppColors.success : AppColors.warning;
    return PlayfulCard(
      accent: color,
      padding: const EdgeInsets.fromLTRB(18, 12, 8, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.staffName,
                  style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary)),
              Text(r.roleLabel,
                  style: TextStyle(fontSize: 11.5, color: context.textSecondary)),
            ]),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(formatMoney(r.net),
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: context.textPrimary)),
              const SizedBox(height: 4),
              PeiPill(
                  label: context.tr(r.paid ? 'sal.status.paid' : 'sal.status.pending'),
                  color: color),
            ]),
          ),
        ]),
        if (r.bonus > 0 || r.deduction > 0 || r.baseSalary <= 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              r.baseSalary <= 0
                  ? '⚠ ${context.tr('sal.base')} : 0'
                  : '${formatMoney(r.baseSalary, withCode: false)}'
                      '${r.bonus > 0 ? '  + ${formatMoney(r.bonus, withCode: false)}' : ''}'
                      '${r.deduction > 0 ? '  − ${formatMoney(r.deduction, withCode: false)}' : ''}',
              style: TextStyle(fontSize: 11.5, color: context.textSecondary),
            ),
          ),
        if (r.paid && r.paidAt != null)
          Text(context.tr('sal.paidOn', args: {'date': finFmtDate(r.paidAt!)}),
              style: TextStyle(fontSize: 11.5, color: context.textSecondary)),
        Wrap(children: [
          TextButton.icon(
            onPressed: onAdjust,
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: Text(context.tr('sal.edit')),
          ),
          TextButton.icon(
            onPressed: r.baseSalary <= 0 && !r.paid ? null : onTogglePaid,
            icon: Icon(r.paid ? Icons.undo_rounded : Icons.check_circle_outline_rounded, size: 18),
            label: Text(context.tr(r.paid ? 'sal.unpay' : 'sal.markPaid')),
          ),
          TextButton.icon(
            onPressed: onPayslip,
            icon: const Icon(Icons.description_outlined, size: 18),
            label: Text(context.tr('sal.payslip')),
          ),
        ]),
      ]),
    );
  }
}

class _AdjustSheet extends StatefulWidget {
  final SalaryRecord record;
  const _AdjustSheet({required this.record});

  @override
  State<_AdjustSheet> createState() => _AdjustSheetState();
}

class _AdjustSheetState extends State<_AdjustSheet> {
  final _form = GlobalKey<FormState>();
  late final _base = TextEditingController(text: _fmt(widget.record.baseSalary));
  late final _bonus = TextEditingController(text: _fmt(widget.record.bonus));
  late final _deduction = TextEditingController(text: _fmt(widget.record.deduction));
  late final _note = TextEditingController(text: widget.record.note);

  static String _fmt(double v) =>
      v == 0 ? '' : v.toStringAsFixed(v % 1 == 0 ? 0 : 2);

  @override
  void dispose() {
    _base.dispose();
    _bonus.dispose();
    _deduction.dispose();
    _note.dispose();
    super.dispose();
  }

  String? _money(String? v, {bool required = false}) {
    if ((v ?? '').trim().isEmpty) {
      return required ? context.tr('fin.err.amount') : null;
    }
    final n = parseMoney(v!);
    return (n == null || n < 0) ? context.tr('fin.err.amount') : null;
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${context.tr('sal.edit')} · ${r.staffName}',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: context.textPrimary)),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _base,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                        labelText: '${context.tr('sal.base')} ($kCurrencyCode)'),
                    validator: (v) => _money(v, required: true),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _bonus,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: context.tr('sal.bonus')),
                        validator: _money,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _deduction,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: context.tr('sal.deduction')),
                        validator: _money,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _note,
                    decoration: InputDecoration(
                        labelText:
                            '${context.tr('sal.note')} (${context.tr('common.optional')})'),
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
                        onPressed: () {
                          if (!_form.currentState!.validate()) return;
                          Navigator.pop(
                            context,
                            r.copyWith(
                              baseSalary: parseMoney(_base.text) ?? 0,
                              bonus: parseMoney(_bonus.text) ?? 0,
                              deduction: parseMoney(_deduction.text) ?? 0,
                              note: _note.text.trim().isEmpty ? null : _note.text.trim(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: Text(context.tr('common.save')),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
