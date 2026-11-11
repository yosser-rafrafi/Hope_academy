import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/finance_utils.dart';
import '../../l10n/app_strings.dart';
import '../../models/class_model.dart';
import '../../models/finance_model.dart';

String finFmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

double? parseMoney(String raw) {
  final v = double.tryParse(raw.trim().replaceAll(',', '.').replaceAll(' ', ''));
  return v == null ? null : roundMoney(v);
}

Widget _shell(BuildContext context, {required Widget child}) => Padding(
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

Widget _label(BuildContext context, String t) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(t,
          style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: context.textPrimary)),
    );

Future<DateTime?> _pick(BuildContext c, DateTime initial) => showDatePicker(
      context: c,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: c.tr('common.pickDate'),
    );

// ═════════════════════════════════════════════════════════════════════════════
// Charge sheet (single student, bulk billing, or edit)
// ═════════════════════════════════════════════════════════════════════════════

class ChargeDraft {
  final FeeCategory category;
  final String title;
  final double amount;
  final double discount;
  final DateTime dueDate;
  final String? note;

  /// Bulk only: null = whole academy, otherwise the class to bill.
  final String? targetClassId;
  const ChargeDraft({
    required this.category,
    required this.title,
    required this.amount,
    required this.discount,
    required this.dueDate,
    this.note,
    this.targetClassId,
  });
}

/// [classes] non-null ⇒ bulk mode (shows the "bill whom" selector).
Future<ChargeDraft?> showChargeSheet(
  BuildContext context, {
  FeeCharge? existing,
  List<ClassModel>? classes,
}) {
  return showModalBottomSheet<ChargeDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ChargeSheet(existing: existing, classes: classes),
  );
}

class _ChargeSheet extends StatefulWidget {
  final FeeCharge? existing;
  final List<ClassModel>? classes;
  const _ChargeSheet({this.existing, this.classes});

  @override
  State<_ChargeSheet> createState() => _ChargeSheetState();
}

class _ChargeSheetState extends State<_ChargeSheet> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _amount = TextEditingController(
      text: widget.existing == null ? '' : '${widget.existing!.amount}');
  late final _discount = TextEditingController(
      text: (widget.existing?.discount ?? 0) > 0 ? '${widget.existing!.discount}' : '');
  late final _note = TextEditingController(text: widget.existing?.note);
  late FeeCategory _category = widget.existing?.category ?? FeeCategory.tuition;
  late DateTime _due =
      widget.existing?.dueDate ?? DateTime.now().add(const Duration(days: 30));
  String? _classId; // bulk target

  bool get _bulk => widget.classes != null;
  bool get _editing => widget.existing != null;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _discount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final amount = parseMoney(_amount.text)!;
    final discount = parseMoney(_discount.text) ?? 0;
    Navigator.pop(
      context,
      ChargeDraft(
        category: _category,
        title: _title.text.trim(),
        amount: amount,
        discount: discount,
        dueDate: DateTime(_due.year, _due.month, _due.day),
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        targetClassId: _classId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleKey = _bulk
        ? 'fin.charge.bulk'
        : (_editing ? 'fin.charge.edit' : 'fin.charge.new');
    return _shell(
      context,
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr(titleKey),
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary)),
          if (_bulk) ...[
            _label(context, context.tr('fin.charge.target')),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ChoiceChip(
                selected: _classId == null,
                showCheckmark: false,
                label: Text(context.tr('fin.charge.target.academy'),
                    style: TextStyle(
                        color: _classId == null ? Colors.white : context.textPrimary)),
                selectedColor: AppColors.primary,
                onSelected: (_) => setState(() => _classId = null),
              ),
              for (final c in widget.classes!)
                ChoiceChip(
                  selected: _classId == c.id,
                  showCheckmark: false,
                  label: Text(c.name,
                      style: TextStyle(
                          color: _classId == c.id ? Colors.white : context.textPrimary)),
                  selectedColor: AppColors.primary,
                  onSelected: (_) => setState(() => _classId = c.id),
                ),
            ]),
          ],
          _label(context, context.tr('fin.charge.category')),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in FeeCategory.values)
              ChoiceChip(
                selected: _category == c,
                showCheckmark: false,
                label: Text('${c.emoji} ${context.tr('fin.category.${c.name}')}',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: _category == c ? Colors.white : context.textPrimary)),
                selectedColor: AppColors.primary,
                onSelected: (_) => setState(() => _category = c),
              ),
          ]),
          const SizedBox(height: 12),
          TextFormField(
            controller: _title,
            decoration: InputDecoration(labelText: context.tr('fin.charge.title')),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? context.tr('common.required')
                : null,
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: '${context.tr('fin.charge.amount')} ($kCurrencyCode)'),
                validator: (v) {
                  final n = parseMoney(v ?? '');
                  return (n == null || n <= 0) ? context.tr('fin.err.amount') : null;
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _discount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: '${context.tr('fin.charge.discount')} ($kCurrencyCode)'),
                validator: (v) {
                  if ((v ?? '').trim().isEmpty) return null;
                  final d = parseMoney(v!);
                  final a = parseMoney(_amount.text) ?? 0;
                  return (d == null || d < 0 || d > a)
                      ? context.tr('fin.err.amount')
                      : null;
                },
              ),
            ),
          ]),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final d = await _pick(context, _due);
              if (d != null) setState(() => _due = d);
            },
            icon: const Icon(Icons.event_outlined, size: 18),
            label: Text('${context.tr('fin.charge.dueDate')} : ${finFmtDate(_due)}'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _note,
            decoration: InputDecoration(
                labelText:
                    '${context.tr('fin.charge.note')} (${context.tr('common.optional')})'),
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
// Payment sheet
// ═════════════════════════════════════════════════════════════════════════════

class PaymentDraft {
  final double amount;
  final PaymentMethod method;
  final DateTime date;
  final String? reference;
  const PaymentDraft(this.amount, this.method, this.date, this.reference);
}

Future<PaymentDraft?> showPaymentSheet(BuildContext context,
    {required FeeCharge charge}) {
  return showModalBottomSheet<PaymentDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PaymentSheet(charge: charge),
  );
}

class _PaymentSheet extends StatefulWidget {
  final FeeCharge charge;
  const _PaymentSheet({required this.charge});

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  final _form = GlobalKey<FormState>();
  late final _amount =
      TextEditingController(text: widget.charge.balance.toStringAsFixed(
          widget.charge.balance % 1 == 0 ? 0 : 2));
  final _ref = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _amount.dispose();
    _ref.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
      context,
      PaymentDraft(parseMoney(_amount.text)!, _method, _date,
          _ref.text.trim().isEmpty ? null : _ref.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.charge;
    return _shell(
      context,
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr('fin.pay.record'),
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary)),
          const SizedBox(height: 4),
          Text('${c.category.emoji} ${c.title} · ${c.studentName}',
              style: TextStyle(color: context.textSecondary, fontSize: 13)),
          const SizedBox(height: 4),
          Text('${context.tr('fin.student.balance')} : ${formatMoney(c.balance)}',
              style: TextStyle(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
          const SizedBox(height: 14),
          TextFormField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '${context.tr('fin.pay.amount')} ($kCurrencyCode)',
              suffixIcon: TextButton(
                onPressed: () => setState(() => _amount.text = c.balance
                    .toStringAsFixed(c.balance % 1 == 0 ? 0 : 2)),
                child: Text(context.tr('fin.pay.full')),
              ),
            ),
            validator: (v) {
              final n = parseMoney(v ?? '');
              if (n == null || n <= 0) return context.tr('fin.err.amount');
              if (n > c.balance + 0.005) return context.tr('fin.err.overpay');
              return null;
            },
          ),
          _label(context, context.tr('fin.pay.method')),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in PaymentMethod.values)
              ChoiceChip(
                selected: _method == m,
                showCheckmark: false,
                label: Text(context.tr('fin.method.${m.name}'),
                    style: TextStyle(
                        fontSize: 12.5,
                        color: _method == m ? Colors.white : context.textPrimary)),
                selectedColor: AppColors.primary,
                onSelected: (_) => setState(() => _method = m),
              ),
          ]),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final d = await _pick(context, _date);
              if (d != null) setState(() => _date = d);
            },
            icon: const Icon(Icons.event_outlined, size: 18),
            label: Text('${context.tr('fin.pay.date')} : ${finFmtDate(_date)}'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _ref,
            decoration: InputDecoration(
                labelText:
                    '${context.tr('fin.pay.reference')} (${context.tr('common.optional')})'),
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
                icon: const Icon(Icons.payments_rounded, size: 18),
                label: Text(context.tr('common.save')),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
