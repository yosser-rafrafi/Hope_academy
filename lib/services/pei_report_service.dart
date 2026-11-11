import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../l10n/app_strings.dart';
import '../models/pei_model.dart';
import 'report_service.dart';

/// Branded PDF of a PEI: profile, goals table and progress history.
/// Generated in the language of [s] (fr / en / ar — Arabic is laid out RTL).
class PeiReportService {
  static const _ink = ReportService.brandInk;
  static const _muted = ReportService.brandMuted;
  static const _blue = ReportService.brandBlue;
  static const _soft = ReportService.brandSoft;

  static Future<Uint8List> buildPdf({
    required PeiModel plan,
    required List<PeiProgressEntry> entries,
    required AppStrings s,
  }) async {
    final d = ReportService.pdfDate;
    final goals = plan.goals;
    final byGoal = <String, List<PeiProgressEntry>>{};
    for (final e in entries) {
      byGoal.putIfAbsent(e.goalId, () => []).add(e);
    }

    pw.Widget h(String text) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 14, bottom: 5),
          child: pw.Text(text,
              style: pw.TextStyle(
                  fontSize: 12.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _blue)),
        );

    pw.Widget para(String? text) => (text == null || text.trim().isEmpty)
        ? pw.SizedBox()
        : pw.Text(text.trim(),
            style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 3, color: _ink));

    pw.Widget table(List<String> headers, List<List<String>> rows) =>
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows,
          headerStyle: pw.TextStyle(
              fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: _blue),
          cellStyle: const pw.TextStyle(fontSize: 9, color: _ink),
          oddRowDecoration: const pw.BoxDecoration(color: _soft),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        );

    String levelText(int l) => '$l – ${s.t('pei.level.$l')}';

    final periodText = plan.endDate == null
        ? d(plan.startDate)
        : '${d(plan.startDate)}  →  ${d(plan.endDate!)}';

    final doc = pw.Document(theme: await ReportService.pdfTheme(), title: s.t('pei.fullTitle'));
    doc.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 36),
        textDirection: s.isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      ),
      footer: ReportService.pdfFooter,
      build: (_) => [
        ReportService.pdfBanner(
          s.t('pei.fullTitle'),
          '${plan.studentName}  ·  ${plan.academicYear}',
        ),
        pw.SizedBox(height: 14),
        pw.Wrap(spacing: 8, runSpacing: 8, children: [
          ReportService.pdfPill(s.t('pei.progress.overall'),
              '${(plan.overallProgress * 100).round()}%', _blue),
          ReportService.pdfPill(s.t('pei.goals'),
              s.t('pei.progress.achieved', args: {
                'done': plan.achievedCount,
                'total': goals.length,
              }),
              ReportService.brandSky),
          ReportService.pdfPill(s.t('pei.status'),
              s.t('pei.status.${plan.status.name}'), ReportService.brandSky),
        ]),
        h(s.t('pei.section.info')),
        table(
          [s.t('pei.pdf.period'), s.t('pei.reviewDate'), s.t('pei.academicYear')],
          [
            [
              periodText,
              plan.reviewDate == null ? '—' : d(plan.reviewDate!),
              plan.academicYear,
            ]
          ],
        ),
        if ((plan.strengths ?? '').trim().isNotEmpty ||
            (plan.needs ?? '').trim().isNotEmpty ||
            plan.accommodations.isNotEmpty ||
            (plan.familyInput ?? '').trim().isNotEmpty) ...[
          h(s.t('pei.pdf.profile')),
          if ((plan.strengths ?? '').trim().isNotEmpty) ...[
            pw.Text(s.t('pei.strengths'),
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _ink)),
            para(plan.strengths),
            pw.SizedBox(height: 6),
          ],
          if ((plan.needs ?? '').trim().isNotEmpty) ...[
            pw.Text(s.t('pei.needs'),
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _ink)),
            para(plan.needs),
            pw.SizedBox(height: 6),
          ],
          if (plan.accommodations.isNotEmpty) ...[
            pw.Text(s.t('pei.accommodations'),
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _ink)),
            for (final a in plan.accommodations)
              pw.Text('•  $a',
                  style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 2, color: _ink)),
            pw.SizedBox(height: 6),
          ],
          if ((plan.familyInput ?? '').trim().isNotEmpty) ...[
            pw.Text(s.t('pei.family'),
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _ink)),
            para(plan.familyInput),
          ],
        ],
        h(s.t('pei.pdf.goalsTable')),
        if (goals.isEmpty)
          pw.Text(s.t('pei.goals.empty'),
              style: const pw.TextStyle(fontSize: 10.5, color: _muted))
        else
          table(
            [
              s.t('pei.goal.domain'),
              s.t('pei.goal.title'),
              s.t('pei.pdf.level'),
              s.t('pei.status'),
              s.t('pei.goal.targetDate'),
            ],
            [
              for (final g in goals)
                [
                  s.t('pei.domain.${g.domain.name}'),
                  g.title,
                  '${g.baselineLevel} → ${g.currentLevel} → ${g.targetLevel}',
                  s.t('pei.goal.status.${g.status.name}'),
                  g.targetDate == null ? '—' : d(g.targetDate!),
                ],
            ],
          ),
        h(s.t('pei.pdf.history')),
        for (final g in goals) ...[
          pw.SizedBox(height: 6),
          pw.Text(
            '${s.t('pei.domain.${g.domain.name}')} — ${g.title}',
            style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: _ink),
          ),
          if ((g.criteria ?? '').trim().isNotEmpty)
            pw.Text('${s.t('pei.goal.criteria')} : ${g.criteria}',
                style: const pw.TextStyle(fontSize: 9, color: _muted)),
          pw.SizedBox(height: 3),
          if ((byGoal[g.id] ?? const []).isEmpty)
            pw.Text(s.t('pei.progress.empty'),
                style: const pw.TextStyle(fontSize: 9.5, color: _muted))
          else
            table(
              [
                s.t('pei.progress.date'),
                s.t('pei.progress.level'),
                s.t('pei.progress.note'),
                s.t('abs.pdf.recordedBy'),
              ],
              [
                for (final e in ([...byGoal[g.id]!]..sort((a, b) => a.date.compareTo(b.date))))
                  [d(e.date), levelText(e.level), e.note ?? '', e.recordedByName],
              ],
            ),
        ],
      ],
    ));
    return doc.save();
  }
}
