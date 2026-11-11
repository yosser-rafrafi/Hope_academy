import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../core/app_colors.dart';
import '../l10n/app_strings.dart';
import '../models/absence_model.dart';
import '../models/class_model.dart';
import '../services/report_service.dart';
import '../services/share_service.dart';
import 'kid_ui.dart';

/// Bottom sheet that exports the absence lists currently displayed on screen.
///
/// The caller passes the already-loaded (and already-filtered) [absences], so
/// no extra Firestore read is needed. The user chooses how to group the list:
///   • per day   – "who is absent each day" (academy-wide or one class)
///   • per class – "list per group"
///
/// Output: PDF (share), print, or CSV (Excel).
Future<void> showAttendanceListExportSheet(
  BuildContext context, {
  required List<AbsenceModel> absences,
  required List<ClassModel> classes,
  required DateTime from,
  required DateTime to,
  required String scopeLabel,
  bool initialGroupByClass = false,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AttendanceListExportSheet(
      absences: absences,
      classes: classes,
      from: from,
      to: to,
      scopeLabel: scopeLabel,
      initialGroupByClass: initialGroupByClass,
    ),
  );
}

class _AttendanceListExportSheet extends StatefulWidget {
  final List<AbsenceModel> absences;
  final List<ClassModel> classes;
  final DateTime from;
  final DateTime to;
  final String scopeLabel;
  final bool initialGroupByClass;

  const _AttendanceListExportSheet({
    required this.absences,
    required this.classes,
    required this.from,
    required this.to,
    required this.scopeLabel,
    required this.initialGroupByClass,
  });

  @override
  State<_AttendanceListExportSheet> createState() =>
      _AttendanceListExportSheetState();
}

class _AttendanceListExportSheetState
    extends State<_AttendanceListExportSheet> {
  late bool _byClass = widget.initialGroupByClass;
  bool _busy = false;

  String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String get _fileBase {
    String c(DateTime d) =>
        '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    final kind = _byClass ? 'par_classe' : 'par_jour';
    return 'absences_${kind}_${c(widget.from)}_${c(widget.to)}';
  }

  Future<void> _run(String format) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (format == 'csv') {
        await ShareService.shareCsv(
          ReportService.attendanceListCsv(widget.absences, widget.classes),
          name: _fileBase,
        );
      } else {
        final bytes = await ReportService.attendanceListPdf(
          title: context
              .tr(_byClass ? 'abs.pdf.byClass' : 'abs.pdf.byDay'),
          strings: context.strings,
          scopeLabel: widget.scopeLabel,
          from: widget.from,
          to: widget.to,
          absences: widget.absences,
          classes: widget.classes,
          groupByClass: _byClass,
        );
        if (format == 'print') {
          await Printing.layoutPdf(onLayout: (_) async => bytes, name: _fileBase);
        } else {
          await Printing.sharePdf(bytes: bytes, filename: '$_fileBase.pdf');
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(context.tr('abs.export.failed', args: {'error': e})),
        backgroundColor: AppColors.error,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sameDay = widget.from.year == widget.to.year &&
        widget.from.month == widget.to.month &&
        widget.from.day == widget.to.day;
    final period =
        sameDay ? _d(widget.from) : '${_d(widget.from)}  →  ${_d(widget.to)}';

    return Container(
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: SafeArea(
        top: false,
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
            SectionTitle(
              title: context.tr('abs.export.title'),
              icon: Icons.picture_as_pdf_rounded,
              color: AppColors.sky,
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.scopeLabel}  ·  $period  ·  ${context.tr('abs.count', args: {'n': widget.absences.length})}',
              style: TextStyle(color: context.textSecondary, fontSize: 12.5),
            ),
            const SizedBox(height: 16),
            Text(context.tr('abs.export.group'),
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: context.textPrimary)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: false,
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text(context.tr('abs.group.byDay')),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: const Icon(Icons.groups_2_outlined, size: 16),
                    label: Text(context.tr('abs.group.byClass')),
                  ),
                ],
                selected: {_byClass},
                onSelectionChanged: (v) => setState(() => _byClass = v.first),
              ),
            ),
            const SizedBox(height: 18),
            if (_busy)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(),
                ),
              )
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
                  tooltip: context.tr('common.print'),
                  onPressed: () => _run('print'),
                  icon: const Icon(Icons.print_rounded),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}
