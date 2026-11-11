import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/app_colors.dart';
import '../../models/absence_model.dart';
import '../../models/class_model.dart';
import '../../services/absence_service.dart';
import '../../services/class_service.dart';

// ─── Filter mode ─────────────────────────────────────────────────────────────

enum _FilterMode { day, week, month, custom }

extension _FilterModeLabel on _FilterMode {
  String get label {
    switch (this) {
      case _FilterMode.day:    return 'Day';
      case _FilterMode.week:   return 'Week';
      case _FilterMode.month:  return 'Month';
      case _FilterMode.custom: return 'Custom';
    }
  }

  IconData get icon {
    switch (this) {
      case _FilterMode.day:    return Icons.today_outlined;
      case _FilterMode.week:   return Icons.date_range_outlined;
      case _FilterMode.month:  return Icons.calendar_month_outlined;
      case _FilterMode.custom: return Icons.tune_outlined;
    }
  }
}

// ─── Main screen ─────────────────────────────────────────────────────────────

class AbsenceReportsScreen extends StatefulWidget {
  const AbsenceReportsScreen({super.key});

  @override
  State<AbsenceReportsScreen> createState() => _AbsenceReportsScreenState();
}

class _AbsenceReportsScreenState extends State<AbsenceReportsScreen> {
  final _absenceService = AbsenceService();
  final _classService   = ClassService();

  // ── Filter state ──────────────────────────────────────────────────────────
  _FilterMode  _mode      = _FilterMode.week;
  DateTime     _anchor    = DateTime.now(); // reference point for day/week/month
  DateTime?    _customStart;
  DateTime?    _customEnd;
  ClassModel?  _selectedClass;

  // ── Derived date range ────────────────────────────────────────────────────
  DateTime get _start {
    switch (_mode) {
      case _FilterMode.day:
        return DateTime(_anchor.year, _anchor.month, _anchor.day);
      case _FilterMode.week:
        final wd = _anchor.weekday; // 1=Mon … 7=Sun
        return DateTime(_anchor.year, _anchor.month, _anchor.day - (wd - 1));
      case _FilterMode.month:
        return DateTime(_anchor.year, _anchor.month, 1);
      case _FilterMode.custom:
        return _customStart ?? DateTime(_anchor.year, _anchor.month, _anchor.day);
    }
  }

  DateTime get _end {
    switch (_mode) {
      case _FilterMode.day:
        return DateTime(_anchor.year, _anchor.month, _anchor.day, 23, 59, 59);
      case _FilterMode.week:
        final wd = _anchor.weekday;
        final endDay = _anchor.add(Duration(days: 7 - wd));
        return DateTime(endDay.year, endDay.month, endDay.day, 23, 59, 59);
      case _FilterMode.month:
        final lastDay = DateTime(_anchor.year, _anchor.month + 1, 0);
        return DateTime(lastDay.year, lastDay.month, lastDay.day, 23, 59, 59);
      case _FilterMode.custom:
        final e = _customEnd ?? _start;
        return DateTime(e.year, e.month, e.day, 23, 59, 59);
    }
  }

  String get _periodLabel {
    final f = _fmt(_start);
    final t = _fmt(_end);
    if (_mode == _FilterMode.day) return f;
    return '$f → $t';
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  // ── Navigation helpers ────────────────────────────────────────────────────
  void _prev() {
    setState(() {
      switch (_mode) {
        case _FilterMode.day:   _anchor = _anchor.subtract(const Duration(days: 1));
        case _FilterMode.week:  _anchor = _anchor.subtract(const Duration(days: 7));
        case _FilterMode.month: _anchor = DateTime(_anchor.year, _anchor.month - 1, 1);
        case _FilterMode.custom: break;
      }
    });
  }

  void _next() {
    setState(() {
      switch (_mode) {
        case _FilterMode.day:   _anchor = _anchor.add(const Duration(days: 1));
        case _FilterMode.week:  _anchor = _anchor.add(const Duration(days: 7));
        case _FilterMode.month: _anchor = DateTime(_anchor.year, _anchor.month + 1, 1);
        case _FilterMode.custom: break;
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(child: _buildBody()),
      ],
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      color: context.surfaceBg,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.bar_chart_outlined,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Absence Reports',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary)),
              Text('Filter, analyse & export PDF',
                  style: TextStyle(
                      fontSize: 12, color: context.textSecondary)),
            ]),
          ]),

          const SizedBox(height: 14),

          // Mode chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _FilterMode.values.map((m) {
                final sel = _mode == m;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: sel,
                    avatar: Icon(m.icon,
                        size: 15,
                        color: sel ? Colors.white : context.textSecondary),
                    label: Text(m.label,
                        style: TextStyle(
                            fontSize: 12,
                            color: sel ? Colors.white : context.textPrimary)),
                    selectedColor: AppColors.primary,
                    backgroundColor: context.softFill,
                    side: BorderSide(
                        color: sel ? AppColors.primary : context.divider),
                    showCheckmark: false,
                    onSelected: (_) async {
                      if (m == _FilterMode.custom) {
                        await _pickCustomRange();
                      } else {
                        setState(() {
                          _mode = m;
                          _anchor = DateTime.now();
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 10),

          // Period navigator
          Row(children: [
            if (_mode != _FilterMode.custom) ...[
              _NavButton(
                  icon: Icons.chevron_left,
                  onTap: _prev),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: GestureDetector(
                onTap: _mode == _FilterMode.day ? _pickDay : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.primary.withAlpha(40)),
                  ),
                  child: Row(children: [
                    Icon(Icons.event_outlined,
                        size: 15, color: context.brand),
                    const SizedBox(width: 8),
                    Text(_periodLabel,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary)),
                  ]),
                ),
              ),
            ),
            if (_mode != _FilterMode.custom) ...[
              const SizedBox(width: 8),
              _NavButton(icon: Icons.chevron_right, onTap: _next),
            ],
          ]),

          const SizedBox(height: 10),

          // Class filter
          StreamBuilder<List<ClassModel>>(
            stream: _classService.streamAll(),
            builder: (context, snap) {
              final classes = snap.data ?? [];
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _ClassChip(
                    label: 'All Classes',
                    selected: _selectedClass == null,
                    onTap: () =>
                        setState(() => _selectedClass = null),
                  ),
                  ...classes.map((c) => Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: _ClassChip(
                          label: c.name,
                          selected: _selectedClass?.id == c.id,
                          onTap: () =>
                              setState(() => _selectedClass = c),
                        ),
                      )),
                ]),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    return StreamBuilder<List<AbsenceModel>>(
      stream: _absenceService.streamAbsencesByDateRange(
        startDate: _start,
        endDate: _end,
      ),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (snap.hasError) {
          return Center(
              child: Text('Error: ${snap.error}',
                  style: const TextStyle(color: AppColors.error)));
        }

        var absences = snap.data ?? [];

        // Filter by class if selected
        if (_selectedClass != null) {
          absences = absences
              .where((a) =>
                  _selectedClass!.studentIds.contains(a.studentId))
              .toList();
        }

        return _AbsenceReportBody(
          absences: absences,
          start: _start,
          end: _end,
          periodLabel: _periodLabel,
          className: _selectedClass?.name,
          onExportPdf: () => _exportPdf(absences),
        );
      },
    );
  }

  // ── Date pickers ──────────────────────────────────────────────────────────

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchor,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _anchor = picked);
  }

  Future<void> _pickCustomRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: (_customStart != null && _customEnd != null)
          ? DateTimeRange(start: _customStart!, end: _customEnd!)
          : null,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (range != null) {
      setState(() {
        _mode = _FilterMode.custom;
        _customStart = range.start;
        _customEnd = range.end;
      });
    }
  }

  // ── PDF export ────────────────────────────────────────────────────────────

  Future<void> _exportPdf(List<AbsenceModel> absences) async {
    final pdfBytes = await _buildPdf(
      absences: absences,
      periodLabel: _periodLabel,
      className: _selectedClass?.name ?? 'All Classes',
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name:
          'Absence_Report_${_periodLabel.replaceAll('/', '-').replaceAll(' ', '_')}.pdf',
    );
  }

  static Future<Uint8List> _buildPdf({
    required List<AbsenceModel> absences,
    required String periodLabel,
    required String className,
  }) async {
    final pdf = pw.Document();

    // ── colour helpers ──────────────────────────────────────────────────────
    PdfColor typeColor(AbsenceType t) {
      switch (t) {
        case AbsenceType.excused:    return PdfColors.green700;
        case AbsenceType.unexcused:  return PdfColors.red700;
        case AbsenceType.sick:       return PdfColors.orange700;
        case AbsenceType.authorized: return PdfColors.blue700;
      }
    }

    // ── Stats ───────────────────────────────────────────────────────────────
    final statsByType = <AbsenceType, int>{};
    for (final a in absences) {
      statsByType[a.type] = (statsByType[a.type] ?? 0) + 1;
    }

    // Group by date for the table
    final byDate = <DateTime, List<AbsenceModel>>{};
    for (final a in absences) {
      final d = a.normalizedDate;
      byDate.putIfAbsent(d, () => []).add(a);
    }
    final sortedDates = byDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    String fmtDate(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Hope Academy Egypt',
                    style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey800)),
                pw.Text('Absence Report',
                    style: pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.blueGrey600)),
              ],
            ),
            pw.Divider(color: PdfColors.blueGrey200),
            pw.SizedBox(height: 4),
            pw.Row(children: [
              pw.Text('Period: ',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold,
                      fontSize: 10)),
              pw.Text(periodLabel,
                  style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(width: 24),
              pw.Text('Class: ',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold,
                      fontSize: 10)),
              pw.Text(className,
                  style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(width: 24),
              pw.Text('Generated: ',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold,
                      fontSize: 10)),
              pw.Text(fmtDate(DateTime.now()),
                  style: const pw.TextStyle(fontSize: 10)),
            ]),
            pw.SizedBox(height: 12),
          ],
        ),
        build: (ctx) => [
          // ── Summary stats ────────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.blueGrey50,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Summary',
                    style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey700)),
                pw.SizedBox(height: 8),
                pw.Row(children: [
                  _pdfStat('Total absences', absences.length.toString(),
                      PdfColors.blueGrey700),
                  pw.SizedBox(width: 20),
                  ...AbsenceType.values.map((t) => pw.Row(children: [
                        pw.SizedBox(width: 20),
                        _pdfStat(
                            t.label,
                            (statsByType[t] ?? 0).toString(),
                            typeColor(t)),
                      ])),
                ]),
              ],
            ),
          ),

          pw.SizedBox(height: 16),

          // ── Per-day tables ───────────────────────────────────────────────
          if (absences.isEmpty)
            pw.Center(
              child: pw.Text('No absences recorded for this period.',
                  style: pw.TextStyle(
                      color: PdfColors.grey600, fontSize: 12)),
            )
          else
            ...sortedDates.map((date) {
              final dayAbsences = byDate[date]!;
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    margin:
                        const pw.EdgeInsets.only(top: 12, bottom: 6),
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blueGrey800,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      fmtDate(date),
                      style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10),
                    ),
                  ),
                  pw.Table(
                    border: pw.TableBorder.all(
                        color: PdfColors.blueGrey100, width: 0.5),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(3),
                      1: const pw.FlexColumnWidth(2),
                      2: const pw.FlexColumnWidth(3),
                      3: const pw.FlexColumnWidth(2),
                    },
                    children: [
                      // Header row
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(
                            color: PdfColors.blueGrey100),
                        children: [
                          _pdfCell('Student', bold: true),
                          _pdfCell('Type', bold: true),
                          _pdfCell('Reason', bold: true),
                          _pdfCell('Recorded by', bold: true),
                        ],
                      ),
                      // Data rows
                      ...dayAbsences.map((a) => pw.TableRow(children: [
                            _pdfCell(a.studentName),
                            _pdfColorCell(a.type.label, typeColor(a.type)),
                            _pdfCell(a.reason ?? '—'),
                            _pdfCell(a.recordedByName),
                          ])),
                    ],
                  ),
                ],
              );
            }),

          pw.SizedBox(height: 20),
          pw.Divider(color: PdfColors.blueGrey200),
          pw.Text(
            'Hope Academy Egypt — Confidential document',
            style: const pw.TextStyle(
                fontSize: 8, color: PdfColors.blueGrey400),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // ── PDF widget helpers ────────────────────────────────────────────────────
  static pw.Widget _pdfStat(String label, String value, PdfColor color) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: color)),
        pw.Text(label,
            style: pw.TextStyle(
                fontSize: 8, color: PdfColors.blueGrey500)),
      ],
    );
  }

  static pw.Widget _pdfCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 9,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }

  static pw.Widget _pdfColorCell(String text, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: pw.BoxDecoration(
          color: PdfColor(color.red / 255, color.green / 255,
              color.blue / 255, 0.15),
          borderRadius: pw.BorderRadius.circular(3),
        ),
        child: pw.Text(text,
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: color)),
      ),
    );
  }
}

// ─── Report body (stats + list) ───────────────────────────────────────────────

class _AbsenceReportBody extends StatelessWidget {
  final List<AbsenceModel> absences;
  final DateTime start;
  final DateTime end;
  final String periodLabel;
  final String? className;
  final VoidCallback onExportPdf;

  const _AbsenceReportBody({
    required this.absences,
    required this.start,
    required this.end,
    required this.periodLabel,
    required this.className,
    required this.onExportPdf,
  });

  @override
  Widget build(BuildContext context) {
    // stats
    final statsByType = <AbsenceType, int>{};
    for (final a in absences) {
      statsByType[a.type] = (statsByType[a.type] ?? 0) + 1;
    }

    // group by date
    final byDate = <DateTime, List<AbsenceModel>>{};
    for (final a in absences) {
      final d = a.normalizedDate;
      byDate.putIfAbsent(d, () => []).add(a);
    }
    final sortedDates = byDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        // ── Stats cards ────────────────────────────────────────────────────
        Row(children: [
          Expanded(
            child: _StatsCard(
              icon: Icons.event_busy_outlined,
              label: 'Total',
              value: absences.length.toString(),
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatsCard(
              icon: Icons.check_circle_outline,
              label: 'Justified',
              value: (statsByType[AbsenceType.excused] ?? 0).toString(),
              color: AppColors.absenceExcused,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatsCard(
              icon: Icons.cancel_outlined,
              label: 'Unjustified',
              value: (statsByType[AbsenceType.unexcused] ?? 0).toString(),
              color: AppColors.absenceUnexcused,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatsCard(
              icon: Icons.healing_outlined,
              label: 'Sick',
              value: (statsByType[AbsenceType.sick] ?? 0).toString(),
              color: AppColors.absenceSick,
            ),
          ),
        ]),

        const SizedBox(height: 16),

        // ── Export button ──────────────────────────────────────────────────
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onExportPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('Export PDF'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ]),

        const SizedBox(height: 18),

        // ── Per-day sections ───────────────────────────────────────────────
        if (absences.isEmpty)
          _EmptyState(periodLabel: periodLabel)
        else
          ...sortedDates.map((date) {
            final dayAbsences = byDate[date]!;
            return _DaySection(
                date: date, absences: dayAbsences);
          }),
      ],
    );
  }
}

// ─── Stats card ───────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatsCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(50)),
        boxShadow: context.softShadow,
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color)),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 10, color: context.textSecondary)),
      ]),
    );
  }
}

// ─── Day section ──────────────────────────────────────────────────────────────

class _DaySection extends StatelessWidget {
  final DateTime date;
  final List<AbsenceModel> absences;

  const _DaySection({required this.date, required this.absences});

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Day header
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withAlpha(30)),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_outlined,
              size: 14, color: context.brand),
          const SizedBox(width: 8),
          Text(_fmt(date),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary)),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('${absences.length}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
        ]),
      ),

      // Absence rows
      ...absences.map((a) => _AbsenceRow(absence: a)),

      const SizedBox(height: 14),
    ]);
  }
}

// ─── Absence row ─────────────────────────────────────────────────────────────

class _AbsenceRow extends StatelessWidget {
  final AbsenceModel absence;

  const _AbsenceRow({required this.absence});

  Color _typeColor(AbsenceType t) {
    switch (t) {
      case AbsenceType.excused:    return AppColors.absenceExcused;
      case AbsenceType.unexcused:  return AppColors.absenceUnexcused;
      case AbsenceType.sick:       return AppColors.absenceSick;
      case AbsenceType.authorized: return AppColors.absenceAuthorized;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(absence.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.divider),
        boxShadow: context.softShadow,
      ),
      child: Row(children: [
        // Type indicator
        Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),

        // Info
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(absence.studentName,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary)),
            if (absence.reason != null && absence.reason!.isNotEmpty)
              Text(absence.reason!,
                  style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary)),
            Text('by ${absence.recordedByName}',
                style: TextStyle(
                    fontSize: 11,
                    color: context.textSecondary)),
          ]),
        ),

        // Type badge
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withAlpha(22),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withAlpha(70)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(absence.type.emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(absence.type.label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ]),
        ),
      ]),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String periodLabel;
  const _EmptyState({required this.periodLabel});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.event_available_outlined,
              size: 60,
              color: context.textSecondary.withAlpha(80)),
          const SizedBox(height: 14),
          Text('No absences for this period',
              style: TextStyle(
                  fontSize: 15, color: context.textSecondary)),
          const SizedBox(height: 4),
          Text(periodLabel,
              style: TextStyle(
                  fontSize: 12,
                  color: context.textSecondary.withAlpha(150))),
        ]),
      ),
    );
  }
}

// ─── Nav button ───────────────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: context.softFill,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.divider),
        ),
        child: Icon(icon, size: 20, color: context.textSecondary),
      ),
    );
  }
}

// ─── Class chip ───────────────────────────────────────────────────────────────

class _ClassChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ClassChip(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : context.softFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected
                  ? AppColors.primary
                  : context.divider),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: selected
                  ? Colors.white
                  : context.textSecondary),
        ),
      ),
    );
  }
}
