import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../core/app_colors.dart';
import '../models/absence_model.dart';
import '../services/report_service.dart';
import '../services/share_service.dart';
import 'kid_ui.dart';

/// App-bar button that exports attendance for a period as PDF or CSV and
/// shares it (WhatsApp, Facebook, Mail, Drive, print…).
class AttendanceExportButton extends StatelessWidget {
  final String title;
  final DateTime initialDay;
  final Future<List<AbsenceModel>> Function(DateTime from, DateTime to) loader;
  const AttendanceExportButton({
    super.key,
    required this.title,
    required this.loader,
    required this.initialDay,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Export & share',
      icon: const Icon(Icons.ios_share_rounded),
      onPressed: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ExportSheet(title: title, loader: loader, initialDay: initialDay),
      ),
    );
  }
}

class _ExportSheet extends StatefulWidget {
  final String title;
  final DateTime initialDay;
  final Future<List<AbsenceModel>> Function(DateTime, DateTime) loader;
  const _ExportSheet({required this.title, required this.loader, required this.initialDay});

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  late DateTime _from = DateTime(widget.initialDay.year, widget.initialDay.month, widget.initialDay.day);
  late DateTime _to = _from;
  String _preset = 'day';
  bool _busy = false;

  void _setPreset(String p) {
    final d = widget.initialDay;
    setState(() {
      _preset = p;
      if (p == 'day') {
        _from = _to = DateTime(d.year, d.month, d.day);
      } else if (p == 'week') {
        _from = DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));
        _to = _from.add(const Duration(days: 6));
      } else if (p == 'month') {
        _from = DateTime(d.year, d.month, 1);
        _to = DateTime(d.year, d.month + 1, 0);
      }
    });
  }

  Future<void> _pickRange() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (r != null) {
      setState(() {
        _preset = 'custom';
        _from = r.start;
        _to = r.end;
      });
    }
  }

  Future<void> _run(String format) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final data = await widget.loader(_from, _to);
      final base = 'attendance_${_from.year}${_from.month.toString().padLeft(2, '0')}${_from.day.toString().padLeft(2, '0')}';
      if (format == 'pdf') {
        final bytes = await ReportService.attendancePdf(
            title: widget.title, from: _from, to: _to, absences: data);
        await Printing.sharePdf(bytes: bytes, filename: '$base.pdf');
      } else if (format == 'print') {
        final bytes = await ReportService.attendancePdf(
            title: widget.title, from: _from, to: _to, absences: data);
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: base);
      } else {
        await ShareService.shareCsv(ReportService.attendanceCsv(data), name: base);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('Export failed: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    Widget preset(String id, String label) => ChoiceChip(
          label: Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _preset == id ? Colors.white : context.textPrimary)),
          selected: _preset == id,
          showCheckmark: false,
          selectedColor: AppColors.sky,
          onSelected: (_) => id == 'custom' ? _pickRange() : _setPreset(id),
        );

    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                  color: context.divider, borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(height: 14),
          const SectionTitle(
              title: 'Export attendance report',
              icon: Icons.ios_share_rounded,
              color: AppColors.sky),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            preset('day', 'Day'),
            preset('week', 'Week'),
            preset('month', 'Month'),
            preset('custom', 'Custom…'),
          ]),
          const SizedBox(height: 8),
          Text('${_fmt(_from)}  →  ${_fmt(_to)}',
              style: TextStyle(color: context.textSecondary, fontSize: 12.5)),
          const SizedBox(height: 16),
          if (_busy)
            const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
          else
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _run('pdf'),
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: const Text('PDF'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _run('csv'),
                  icon: const Icon(Icons.table_chart_rounded, size: 18),
                  label: const Text('Excel/CSV'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'Print',
                onPressed: () => _run('print'),
                icon: const Icon(Icons.print_rounded),
              ),
            ]),
        ]),
      ),
    );
  }
}
