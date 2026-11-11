import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/app_colors.dart';
import '../../core/finance_utils.dart';
import '../../core/permissions.dart';
import '../../l10n/app_strings.dart';
import '../../models/finance_model.dart';
import '../../models/student_model.dart';
import '../../models/user_model.dart';
import '../../services/finance_report_service.dart';
import '../../services/finance_service.dart';
import '../../widgets/kid_ui.dart';
import '../pei/pei_widgets.dart' show PeiPill, PeiProgressBar;
import 'finance_sheets.dart';

Color chargeStatusColor(ChargeStatus s) {
  switch (s) {
    case ChargeStatus.paid:    return AppColors.success;
    case ChargeStatus.partial: return AppColors.sky;
    case ChargeStatus.unpaid:  return AppColors.warning;
    case ChargeStatus.overdue: return AppColors.error;
  }
}

/// Fee account of ONE student: charges, payments, receipts, statement.
/// Staff (admin / sub-admin) manage it; parents get a read-only view
/// (they can still download receipts and the statement).
class StudentFinanceScreen extends StatefulWidget {
  final UserModel student;
  final UserModel viewer;
  const StudentFinanceScreen({super.key, required this.student, required this.viewer});

  @override
  State<StudentFinanceScreen> createState() => _StudentFinanceScreenState();
}

class _StudentFinanceScreenState extends State<StudentFinanceScreen> {
  final _service = FinanceService();
  late final Stream<List<FeeCharge>> _charges =
      _service.streamChargesByStudent(widget.student.uid);
  late final Stream<List<FeePayment>> _payments =
      _service.streamPaymentsByStudent(widget.student.uid);

  List<FeeCharge> _lastCharges = const [];
  List<FeePayment> _lastPayments = const [];
  bool _busy = false;

  bool get _canManage => Permissions.canManageFees(widget.viewer);
  bool get _canDelete => Permissions.canDeleteFinance(widget.viewer);

  String? get _className {
    final s = widget.student;
    return s is StudentModel ? s.className : null;
  }

  void _toast(String msg, {bool error = false, SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : AppColors.success,
      action: action,
    ));
  }

  String _errText(Object e) => e is FinanceException
      ? context.tr('fin.err.${e.code}')
      : context.tr('common.error', args: {'error': '$e'});

  Future<void> _run(Future<void> Function() fn) async {
    try {
      await fn();
    } catch (e) {
      _toast(_errText(e), error: true);
    }
  }

  // ── Charges ───────────────────────────────────────────────────────────────

  Future<void> _addCharge() async {
    final d = await showChargeSheet(context);
    if (d == null) return;
    final s = widget.student;
    final v = widget.viewer;
    await _run(() => _service.addCharge(FeeCharge(
          id: '',
          studentId: s.uid,
          studentName: s.fullName,
          classId: s is StudentModel ? s.classId : null,
          academicYear: currentAcademicYear(d.dueDate),
          category: d.category,
          title: d.title,
          amount: d.amount,
          discount: d.discount,
          dueDate: d.dueDate,
          note: d.note,
          createdById: v.uid,
          createdByName: v.fullName,
          createdAt: DateTime.now(),
        )));
  }

  Future<void> _editCharge(FeeCharge c) async {
    final d = await showChargeSheet(context, existing: c);
    if (d == null) return;
    await _run(() => _service.updateCharge(FeeCharge(
          id: c.id,
          studentId: c.studentId,
          studentName: c.studentName,
          classId: c.classId,
          academicYear: c.academicYear,
          category: d.category,
          title: d.title,
          amount: d.amount,
          discount: d.discount,
          paidAmount: c.paidAmount,
          dueDate: d.dueDate,
          note: d.note,
          createdById: c.createdById,
          createdByName: c.createdByName,
          createdAt: c.createdAt,
        )));
  }

  Future<bool> _confirm(String key) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(ctx.tr(key)),
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
    return ok == true;
  }

  Future<void> _deleteCharge(FeeCharge c) async {
    if (!await _confirm('fin.charge.deleteConfirm')) return;
    await _run(() => _service.deleteCharge(c.id));
  }

  // ── Payments & receipts ───────────────────────────────────────────────────

  Future<void> _pay(FeeCharge c) async {
    final d = await showPaymentSheet(context, charge: c);
    if (d == null) return;
    try {
      final p = await _service.recordPayment(
        chargeId: c.id,
        amount: d.amount,
        method: d.method,
        date: d.date,
        reference: d.reference,
        byId: widget.viewer.uid,
        byName: widget.viewer.fullName,
      );
      _toast(
        context.tr('fin.pay.recorded', args: {'no': p.receiptNo}),
        action: SnackBarAction(
          label: context.tr('fin.pay.receipt'),
          textColor: Colors.white,
          onPressed: () => _receipt(p, remaining: (c.balance - p.amount)),
        ),
      );
    } catch (e) {
      _toast(_errText(e), error: true);
    }
  }

  Future<void> _deletePayment(FeePayment p) async {
    if (!await _confirm('fin.pay.deleteConfirm')) return;
    await _run(() => _service.deletePayment(p));
  }

  Future<void> _receipt(FeePayment p,
      {double? remaining, bool print = false}) async {
    setState(() => _busy = true);
    try {
      final strings = context.strings;
      double left = remaining ?? 0;
      if (remaining == null) {
        for (final c in _lastCharges) {
          if (c.id == p.chargeId) left = c.balance;
        }
      }
      final bytes = await FinanceReportService.receiptPdf(
        payment: p,
        remainingOnCharge: left < 0 ? 0 : left,
        className: _className,
        s: strings,
      );
      if (print) {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: p.receiptNo);
      } else {
        await Printing.sharePdf(bytes: bytes, filename: '${p.receiptNo}.pdf');
      }
    } catch (e) {
      _toast(_errText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _statement({required bool print}) async {
    setState(() => _busy = true);
    try {
      final bytes = await FinanceReportService.statementPdf(
        studentName: widget.student.fullName,
        className: _className,
        charges: _lastCharges,
        payments: _lastPayments,
        s: context.strings,
      );
      final name = 'statement_${widget.student.fullName.replaceAll(' ', '_')}';
      if (print) {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
      } else {
        await Printing.sharePdf(bytes: bytes, filename: '$name.pdf');
      }
    } catch (e) {
      _toast(_errText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        title: Text(widget.student.fullName, overflow: TextOverflow.ellipsis),
        actions: [
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
              tooltip: context.tr('fin.export.statement'),
              icon: const Icon(Icons.picture_as_pdf_rounded),
              onSelected: (v) => _statement(print: v == 'print'),
              itemBuilder: (_) => [
                PopupMenuItem(
                    value: 'share',
                    child: ListTile(
                      leading: const Icon(Icons.ios_share_rounded),
                      title: Text(context.tr('fin.export.statement')),
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
        ],
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              onPressed: _addCharge,
              icon: const Icon(Icons.add_rounded),
              label: Text(context.tr('fin.charge.new')),
            )
          : null,
      body: StreamBuilder<List<FeeCharge>>(
        stream: _charges,
        builder: (context, cSnap) {
          if (cSnap.hasError) {
            return Center(
                child: Text(
                    context.tr('common.error', args: {'error': '${cSnap.error}'}),
                    style: const TextStyle(color: AppColors.error)));
          }
          if (!cSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final charges = cSnap.data!;
          _lastCharges = charges;
          return StreamBuilder<List<FeePayment>>(
            stream: _payments,
            builder: (context, pSnap) {
              final payments = pSnap.data ?? const <FeePayment>[];
              _lastPayments = payments;
              return _content(charges, payments);
            },
          );
        },
      ),
    );
  }

  Widget _content(List<FeeCharge> charges, List<FeePayment> payments) {
    final billed = charges.fold<double>(0, (a, c) => a + c.due);
    final paid = charges.fold<double>(0, (a, c) => a + c.paidAmount);
    final balance = charges.fold<double>(0, (a, c) => a + c.balance);
    final overdue = charges.where((c) => c.isOverdue).fold<double>(0, (a, c) => a + c.balance);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        FadeSlideIn(
          child: PlayfulCard(
            accent: balance < 0.005
                ? AppColors.success
                : (overdue > 0 ? AppColors.error : AppColors.warning),
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.tr('fin.student.balance'),
                  style: TextStyle(fontSize: 12.5, color: context.textSecondary)),
              const SizedBox(height: 2),
              Text(formatMoney(balance),
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: balance < 0.005
                          ? AppColors.success
                          : context.textPrimary)),
              const SizedBox(height: 10),
              PeiProgressBar(
                  value: billed <= 0 ? 0 : paid / billed,
                  color: AppColors.success),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                PeiPill(
                    label: '${context.tr('fin.pdf.billed')} ${formatMoney(billed)}',
                    color: AppColors.primaryLight),
                PeiPill(
                    label: '${context.tr('fin.pdf.paid')} ${formatMoney(paid)}',
                    color: AppColors.success),
                if (overdue > 0)
                  PeiPill(
                      label: '${context.tr('fin.kpi.overdue')} ${formatMoney(overdue)}',
                      color: AppColors.error,
                      icon: Icons.warning_amber_rounded),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        SectionTitle(
          title: context.tr('fin.student.charges'),
          icon: Icons.receipt_long_rounded,
          color: AppColors.grape,
        ),
        const SizedBox(height: 10),
        if (charges.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
                child: Text(context.tr('fin.noCharges'),
                    style: TextStyle(color: context.textSecondary))),
          )
        else
          for (final c in charges)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ChargeCard(
                charge: c,
                canPay: _canManage && !c.isSettled,
                canEdit: _canManage,
                canDelete: _canDelete,
                onPay: () => _pay(c),
                onEdit: () => _editCharge(c),
                onDelete: () => _deleteCharge(c),
              ),
            ),
        const SizedBox(height: 14),
        SectionTitle(
          title: context.tr('fin.student.payments'),
          icon: Icons.payments_rounded,
          color: AppColors.success,
        ),
        const SizedBox(height: 10),
        if (payments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
                child: Text(context.tr('fin.noPayments'),
                    style: TextStyle(color: context.textSecondary))),
          )
        else
          for (final p in payments)
            _PaymentTile(
              payment: p,
              canDelete: _canDelete,
              onShare: () => _receipt(p),
              onPrint: () => _receipt(p, print: true),
              onDelete: () => _deletePayment(p),
            ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════

class _ChargeCard extends StatelessWidget {
  final FeeCharge charge;
  final bool canPay, canEdit, canDelete;
  final VoidCallback onPay, onEdit, onDelete;
  const _ChargeCard({
    required this.charge,
    required this.canPay,
    required this.canEdit,
    required this.canDelete,
    required this.onPay,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = charge;
    final color = chargeStatusColor(c.status);
    return PlayfulCard(
      accent: color,
      padding: const EdgeInsets.fromLTRB(18, 14, 8, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(c.category.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.title,
                  style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary)),
              Text(
                  '${context.tr('fin.category.${c.category.name}')} · ${context.tr('fin.due', args: {'date': finFmtDate(c.dueDate)})}',
                  style: TextStyle(fontSize: 11.5, color: context.textSecondary)),
            ]),
          ),
          PeiPill(label: context.tr('fin.status.${c.status.name}'), color: color),
          if (canEdit || canDelete)
            PopupMenuButton<String>(
              onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => [
                if (canEdit)
                  PopupMenuItem(value: 'edit', child: Text(context.tr('common.edit'))),
                if (canDelete)
                  PopupMenuItem(
                      value: 'delete',
                      child: Text(context.tr('common.delete'),
                          style: const TextStyle(color: AppColors.error))),
              ],
            )
          else
            const SizedBox(width: 10),
        ]),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 10),
          child: PeiProgressBar(
              value: c.due <= 0 ? 1 : c.paidAmount / c.due, color: color),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Text(
              context.tr('fin.paidOf', args: {
                'paid': formatMoney(c.paidAmount, withCode: false),
                'total': formatMoney(c.due),
              }),
              style: TextStyle(fontSize: 12.5, color: context.textSecondary),
            ),
          ),
          if (canPay)
            TextButton.icon(
              onPressed: onPay,
              icon: const Icon(Icons.payments_rounded, size: 18),
              label: Text(context.tr('fin.pay.record')),
            ),
        ]),
      ]),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final FeePayment payment;
  final bool canDelete;
  final VoidCallback onShare, onPrint, onDelete;
  const _PaymentTile({
    required this.payment,
    required this.canDelete,
    required this.onShare,
    required this.onPrint,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final p = payment;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: BoxDecoration(
        color: context.softFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.divider),
      ),
      child: Row(children: [
        const Icon(Icons.receipt_rounded, color: AppColors.success),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(formatMoney(p.amount),
                style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary)),
            Text(
                '${p.chargeTitle} · ${context.tr('fin.method.${p.method.name}')} · ${finFmtDate(p.date)}',
                style: TextStyle(fontSize: 11.5, color: context.textSecondary)),
            Text(p.receiptNo,
                style: TextStyle(fontSize: 11, color: context.textSecondary)),
          ]),
        ),
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'share') onShare();
            if (v == 'print') onPrint();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'share', child: Text(context.tr('common.share'))),
            PopupMenuItem(value: 'print', child: Text(context.tr('common.print'))),
            if (canDelete)
              PopupMenuItem(
                  value: 'delete',
                  child: Text(context.tr('common.delete'),
                      style: const TextStyle(color: AppColors.error))),
          ],
        ),
      ]),
    );
  }
}
