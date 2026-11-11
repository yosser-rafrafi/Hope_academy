import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/app_colors.dart';
import '../../core/finance_utils.dart';
import '../../core/permissions.dart';
import '../../l10n/app_strings.dart';
import '../../models/class_model.dart';
import '../../models/finance_model.dart';
import '../../models/user_model.dart';
import '../../services/class_service.dart';
import '../../services/finance_report_service.dart';
import '../../services/finance_service.dart';
import '../../services/share_service.dart';
import '../../services/user_service.dart';
import '../../widgets/kid_ui.dart';
import '../pei/pei_widgets.dart' show PeiPill, PeiProgressBar;
import 'finance_sheets.dart';
import 'student_finance_screen.dart';

/// Fee desk for admin / sub-admin: KPIs, outstanding by class, per-student
/// balances, payments of the month, bulk billing and exports.
class FinanceHubScreen extends StatefulWidget {
  final UserModel currentUser;
  const FinanceHubScreen({super.key, required this.currentUser});

  @override
  State<FinanceHubScreen> createState() => _FinanceHubScreenState();
}

/// Aggregated account of one student for the selected academic year.
class _Row {
  final String studentId;
  final String name;
  final String className;
  double billed = 0, paid = 0, overdue = 0;
  _Row(this.studentId, this.name, this.className);
  double get balance => (billed - paid).clamp(0, double.infinity).toDouble();
}

enum _Filter { all, outstanding, overdue, paid }

class _FinanceHubScreenState extends State<FinanceHubScreen> {
  final _service = FinanceService();
  late String _year = currentAcademicYear();
  late Stream<List<FeeCharge>> _charges = _service.streamChargesByYear(_year);
  late final Stream<List<ClassModel>> _classes = ClassService().streamAll();

  bool _lastMonth = false;
  late Stream<List<FeePayment>> _payments = _paymentsStream();

  final _search = TextEditingController();
  _Filter _filter = _Filter.outstanding;
  String? _classFilter;
  bool _busy = false;

  List<_Row> _lastRows = const [];

  bool get _canManage => Permissions.canManageFees(widget.currentUser);

  Stream<List<FeePayment>> _paymentsStream() {
    final n = DateTime.now();
    final start = DateTime(n.year, n.month - (_lastMonth ? 1 : 0), 1);
    final end = DateTime(start.year, start.month + 1, 0);
    return _service.streamPaymentsBetween(start, end);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : AppColors.success,
    ));
  }

  List<String> get _years {
    final y = int.parse(currentAcademicYear().split('/').first);
    return ['${y - 1}/$y', '$y/${y + 1}'];
  }

  // ── Aggregation ───────────────────────────────────────────────────────────

  List<_Row> _aggregate(List<FeeCharge> charges, List<ClassModel> classes) {
    final classById = {for (final c in classes) c.id: c};
    final classOfStudent = <String, ClassModel>{};
    for (final c in classes) {
      for (final id in c.studentIds) {
        classOfStudent.putIfAbsent(id, () => c);
      }
    }
    final rows = <String, _Row>{};
    for (final ch in charges) {
      final cls = classById[ch.classId] ?? classOfStudent[ch.studentId];
      final r = rows.putIfAbsent(
          ch.studentId,
          () => _Row(ch.studentId, ch.studentName,
              cls?.name ?? context.tr('common.noClass')));
      r.billed += ch.due;
      r.paid += ch.paidAmount;
      if (ch.isOverdue) r.overdue += ch.balance;
    }
    return rows.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  List<OutstandingRow> _outstandingRows() => [
        for (final r in _lastRows)
          OutstandingRow(
              studentName: r.name,
              className: r.className,
              billed: r.billed,
              paid: r.paid,
              overdue: r.overdue)
      ];

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _openStudent(String studentId) async {
    setState(() => _busy = true);
    try {
      final u = await UserService().getUserById(studentId);
      if (!mounted) return;
      if (u == null) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              StudentFinanceScreen(student: u, viewer: widget.currentUser),
        ),
      );
    } catch (e) {
      _toast(context.tr('common.error', args: {'error': '$e'}), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _bulkBill(List<ClassModel> classes) async {
    final d = await showChargeSheet(context, classes: classes);
    if (d == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final all = await UserService().streamUsersByRole(UserRole.student).first;
      var students = all.where((u) => u.isActive).toList();
      if (d.targetClassId != null) {
        final cls = classes.firstWhere((c) => c.id == d.targetClassId);
        students = students.where((u) => cls.studentIds.contains(u.uid)).toList();
      }
      if (students.isEmpty) {
        _toast(context.tr('fin.charge.noStudents'), error: true);
        return;
      }
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(ctx.tr('fin.charge.bulkConfirm', args: {'n': students.length})),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(ctx.tr('common.cancel'))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(ctx.tr('common.save'))),
          ],
        ),
      );
      if (ok != true) return;

      final classOf = <String, String>{};
      for (final c in classes) {
        for (final id in c.studentIds) {
          classOf.putIfAbsent(id, () => c.id);
        }
      }
      final v = widget.currentUser;
      final n = await _service.addChargesBulk([
        for (final s in students)
          FeeCharge(
            id: '',
            studentId: s.uid,
            studentName: s.fullName,
            classId: classOf[s.uid],
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
          ),
      ]);
      _toast(context.tr('fin.charge.created', args: {'n': n}));
    } catch (e) {
      _toast(context.tr('common.error', args: {'error': '$e'}), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportOutstanding(String how) async {
    setState(() => _busy = true);
    try {
      final rows = _outstandingRows();
      if (how == 'csv') {
        await ShareService.shareCsv(FinanceReportService.outstandingCsv(rows),
            name: 'outstanding_${_year.replaceAll('/', '-')}');
      } else {
        final bytes = await FinanceReportService.outstandingPdf(
          rows: rows,
          academicYear: _year,
          scopeLabel: context.tr('abs.scope.academy'),
          s: context.strings,
        );
        final name = 'outstanding_${_year.replaceAll('/', '-')}';
        if (how == 'print') {
          await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
        } else {
          await Printing.sharePdf(bytes: bytes, filename: '$name.pdf');
        }
      }
    } catch (e) {
      _toast(context.tr('common.error', args: {'error': '$e'}), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: context.pageBg,
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
            child: Row(children: [
              Expanded(
                child: Text(context.tr('fin.title'),
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary)),
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              for (final y in _years)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: ChoiceChip(
                    selected: _year == y,
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    label: Text(y,
                        style: TextStyle(
                            fontSize: 12,
                            color: _year == y ? Colors.white : context.textPrimary)),
                    selectedColor: AppColors.primary,
                    onSelected: (_) => setState(() {
                      _year = y;
                      _charges = _service.streamChargesByYear(y);
                    }),
                  ),
                ),
            ]),
          ),
          TabBar(tabs: [
            Tab(text: context.tr('fin.tab.overview')),
            Tab(text: context.tr('fin.tab.fees')),
            Tab(text: context.tr('fin.tab.payments')),
          ]),
          Expanded(
            child: StreamBuilder<List<ClassModel>>(
              stream: _classes,
              builder: (context, clsSnap) {
                final classes = clsSnap.data ?? const <ClassModel>[];
                return StreamBuilder<List<FeeCharge>>(
                  stream: _charges,
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(
                          child: Text(
                              context.tr('common.error', args: {'error': '${snap.error}'}),
                              style: const TextStyle(color: AppColors.error)));
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final charges = snap.data!;
                    final rows = _aggregate(charges, classes);
                    _lastRows = rows;
                    return TabBarView(children: [
                      _overview(charges, rows, classes),
                      _fees(rows, classes),
                      _paymentsTab(),
                    ]);
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  // ── Tab 1: overview ───────────────────────────────────────────────────────

  Widget _overview(List<FeeCharge> charges, List<_Row> rows, List<ClassModel> classes) {
    final billed = charges.fold<double>(0, (a, c) => a + c.due);
    final collected = charges.fold<double>(0, (a, c) => a + c.paidAmount);
    final outstanding = charges.fold<double>(0, (a, c) => a + c.balance);
    final overdue = charges.where((c) => c.isOverdue).fold<double>(0, (a, c) => a + c.balance);
    final rate = billed <= 0 ? 0.0 : (collected / billed).clamp(0.0, 1.0);

    // Outstanding by class
    final byClass = <String, double>{};
    for (final r in rows) {
      if (r.balance > 0.004) {
        byClass[r.className] = (byClass[r.className] ?? 0) + r.balance;
      }
    }
    final classEntries = byClass.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxOut = classEntries.isEmpty ? 1.0 : classEntries.first.value;

    Widget kpi(String key, String value, IconData icon, Color color) => SizedBox(
          width: 170,
          child: PlayfulCard(
            accent: color,
            padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 6),
              Text(value,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary)),
              Text(context.tr(key),
                  style: TextStyle(fontSize: 11.5, color: context.textSecondary)),
            ]),
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        Wrap(spacing: 10, runSpacing: 10, children: [
          kpi('fin.kpi.billed', formatMoney(billed), Icons.request_quote_rounded, AppColors.primaryLight),
          kpi('fin.kpi.collected', formatMoney(collected), Icons.account_balance_wallet_rounded, AppColors.success),
          kpi('fin.kpi.outstanding', formatMoney(outstanding), Icons.hourglass_bottom_rounded, AppColors.warning),
          kpi('fin.kpi.overdue', formatMoney(overdue), Icons.warning_amber_rounded, AppColors.error),
        ]),
        const SizedBox(height: 14),
        PlayfulCard(
          accent: AppColors.success,
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(context.tr('fin.kpi.rate'),
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: context.textPrimary)),
              ),
              Text('${(rate * 100).round()}%',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: context.textPrimary)),
            ]),
            const SizedBox(height: 8),
            PeiProgressBar(value: rate, color: AppColors.success, height: 12),
          ]),
        ),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (_canManage)
            ElevatedButton.icon(
              onPressed: _busy ? null : () => _bulkBill(classes),
              icon: const Icon(Icons.groups_2_outlined, size: 18),
              label: Text(context.tr('fin.charge.bulk')),
            ),
          PopupMenuButton<String>(
            onSelected: _exportOutstanding,
            itemBuilder: (_) => [
              PopupMenuItem(value: 'pdf', child: Text('PDF · ${context.tr('common.share')}')),
              PopupMenuItem(value: 'print', child: Text(context.tr('common.print'))),
              const PopupMenuItem(value: 'csv', child: Text('Excel / CSV')),
            ],
            child: IgnorePointer(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                label: Text(context.tr('fin.export.outstanding')),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 20),
        SectionTitle(
          title: context.tr('fin.byClass'),
          icon: Icons.groups_2_outlined,
          color: AppColors.grape,
        ),
        const SizedBox(height: 10),
        if (classEntries.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
                child: Text(context.tr('fin.noStudents'),
                    style: TextStyle(color: context.textSecondary))),
          )
        else
          for (final e in classEntries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(e.key,
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: context.textPrimary)),
                  ),
                  Text(formatMoney(e.value),
                      style: TextStyle(
                          fontWeight: FontWeight.w800, color: context.textPrimary)),
                ]),
                const SizedBox(height: 4),
                PeiProgressBar(value: e.value / maxOut, color: AppColors.warning, height: 8),
              ]),
            ),
      ],
    );
  }

  // ── Tab 2: student balances ───────────────────────────────────────────────

  Widget _fees(List<_Row> rows, List<ClassModel> classes) {
    final q = _search.text.trim().toLowerCase();
    var list = rows.where((r) {
      if (q.isNotEmpty && !r.name.toLowerCase().contains(q)) return false;
      if (_classFilter != null && r.className != _classFilter) return false;
      switch (_filter) {
        case _Filter.all:         return true;
        case _Filter.outstanding: return r.balance > 0.004;
        case _Filter.overdue:     return r.overdue > 0.004;
        case _Filter.paid:        return r.balance <= 0.004;
      }
    }).toList()
      ..sort((a, b) => b.balance.compareTo(a.balance));

    final classNames = rows.map((r) => r.className).toSet().toList()..sort();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: context.tr('fin.search'),
          ),
        ),
      ),
      SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            for (final f in _Filter.values)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: ChoiceChip(
                  selected: _filter == f,
                  showCheckmark: false,
                  label: Text(context.tr('fin.filter.${f.name}'),
                      style: TextStyle(
                          fontSize: 12,
                          color: _filter == f ? Colors.white : context.textPrimary)),
                  selectedColor: AppColors.primary,
                  onSelected: (_) => setState(() => _filter = f),
                ),
              ),
            const SizedBox(width: 8),
            for (final c in classNames)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: FilterChip(
                  selected: _classFilter == c,
                  showCheckmark: false,
                  label: Text(c, style: const TextStyle(fontSize: 12)),
                  onSelected: (v) => setState(() => _classFilter = v ? c : null),
                ),
              ),
          ],
        ),
      ),
      Expanded(
        child: list.isEmpty
            ? Center(
                child: Text(context.tr('fin.noStudents'),
                    style: TextStyle(color: context.textSecondary)))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final r = list[i];
                  final status = r.balance <= 0.004
                      ? ChargeStatus.paid
                      : (r.overdue > 0.004
                          ? ChargeStatus.overdue
                          : (r.paid > 0.004 ? ChargeStatus.partial : ChargeStatus.unpaid));
                  final color = chargeStatusColor(status);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PlayfulCard(
                      accent: color,
                      onTap: () => _openStudent(r.studentId),
                      padding: const EdgeInsets.fromLTRB(18, 12, 14, 12),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.name,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: context.textPrimary)),
                                Text(r.className,
                                    style: TextStyle(
                                        fontSize: 11.5, color: context.textSecondary)),
                              ]),
                        ),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(formatMoney(r.balance),
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: r.balance <= 0.004
                                      ? AppColors.success
                                      : context.textPrimary)),
                          const SizedBox(height: 4),
                          PeiPill(
                              label: context.tr('fin.status.${status.name}'),
                              color: color),
                        ]),
                      ]),
                    ),
                  );
                },
              ),
      ),
    ]);
  }

  // ── Tab 3: payments of the month ──────────────────────────────────────────

  Widget _paymentsTab() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: false, label: Text(_monthLabel(0))),
            ButtonSegment(value: true, label: Text(_monthLabel(1))),
          ],
          selected: {_lastMonth},
          onSelectionChanged: (v) => setState(() {
            _lastMonth = v.first;
            _payments = _paymentsStream();
          }),
        ),
      ),
      Expanded(
        child: StreamBuilder<List<FeePayment>>(
          stream: _payments,
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(
                  child: Text(
                      context.tr('common.error', args: {'error': '${snap.error}'}),
                      style: const TextStyle(color: AppColors.error)));
            }
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final list = snap.data!;
            final total = list.fold<double>(0, (a, p) => a + p.amount);
            if (list.isEmpty) {
              return Center(
                  child: Text(context.tr('fin.noPayments'),
                      style: TextStyle(color: context.textSecondary)));
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                PlayfulCard(
                  accent: AppColors.success,
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    const Icon(Icons.account_balance_wallet_rounded,
                        color: AppColors.success),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(context.tr('fin.kpi.month'),
                            style: TextStyle(color: context.textSecondary))),
                    Text(formatMoney(total),
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimary)),
                  ]),
                ),
                const SizedBox(height: 10),
                for (final p in list)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: PlayfulCard(
                      accent: AppColors.success,
                      onTap: () => _openStudent(p.studentId),
                      padding: const EdgeInsets.fromLTRB(18, 10, 14, 10),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.studentName,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: context.textPrimary)),
                                Text(
                                    '${p.chargeTitle} · ${context.tr('fin.method.${p.method.name}')} · ${finFmtDate(p.date)}',
                                    style: TextStyle(
                                        fontSize: 11.5, color: context.textSecondary)),
                                Text(p.receiptNo,
                                    style: TextStyle(
                                        fontSize: 11, color: context.textSecondary)),
                              ]),
                        ),
                        Text(formatMoney(p.amount),
                            style: TextStyle(
                                fontWeight: FontWeight.w800, color: context.textPrimary)),
                      ]),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    ]);
  }

  String _monthLabel(int back) {
    final n = DateTime.now();
    final d = DateTime(n.year, n.month - back, 1);
    return '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
