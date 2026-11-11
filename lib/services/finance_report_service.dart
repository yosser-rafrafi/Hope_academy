import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/finance_utils.dart';
import '../l10n/app_strings.dart';
import '../models/finance_model.dart';
import 'report_service.dart';

/// One row of the "outstanding fees" list.
class OutstandingRow {
  final String studentName;
  final String className;
  final double billed;
  final double paid;
  final double overdue;
  const OutstandingRow({
    required this.studentName,
    required this.className,
    required this.billed,
    required this.paid,
    required this.overdue,
  });
  double get balance => (billed - paid).clamp(0, double.infinity).toDouble();
}

/// Branded finance PDFs (receipt, statement, outstanding list, payroll,
/// payslip) in the language of [AppStrings] (Arabic → RTL).
class FinanceReportService {
  static const _ink = ReportService.brandInk;
  static const _muted = ReportService.brandMuted;
  static const _blue = ReportService.brandBlue;
  static const _soft = ReportService.brandSoft;
  static const _sky = ReportService.brandSky;

  static String _d(DateTime d) => ReportService.pdfDate(d);
  static String _m(num v) => formatMoney(v);

  static pw.PageTheme _page(AppStrings s) => pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 36),
        textDirection: s.isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      );

  static pw.Widget _table(List<String> headers, List<List<String>> rows,
      {bool boldLast = false}) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(
          fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: _blue),
      cellStyle: const pw.TextStyle(fontSize: 9, color: _ink),
      oddRowDecoration: const pw.BoxDecoration(color: _soft),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    );
  }

  static pw.Widget _h(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 5),
        child: pw.Text(t,
            style: pw.TextStyle(
                fontSize: 12.5, fontWeight: pw.FontWeight.bold, color: _blue)),
      );

  static pw.Widget _kv(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.SizedBox(
              width: 150,
              child: pw.Text(k,
                  style: const pw.TextStyle(fontSize: 10.5, color: _muted))),
          pw.Expanded(
              child: pw.Text(v,
                  style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: _ink))),
        ]),
      );

  // ─── Receipt ──────────────────────────────────────────────────────────────

  static Future<Uint8List> receiptPdf({
    required FeePayment payment,
    required double remainingOnCharge,
    String? className,
    required AppStrings s,
  }) async {
    final doc = pw.Document(
        theme: await ReportService.pdfTheme(), title: payment.receiptNo);
    doc.addPage(pw.Page(
      pageTheme: _page(s),
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        ReportService.pdfBanner(s.t('fin.pdf.receipt'),
            '${s.t('fin.pdf.receiptNo')} ${payment.receiptNo}'),
        pw.SizedBox(height: 18),
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _sky, width: 1.2),
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Column(children: [
            _kv(s.t('fin.pdf.student'), payment.studentName),
            if (className != null && className.isNotEmpty)
              _kv(s.t('fin.pdf.class'), className),
            _kv(s.t('fin.pdf.item'), payment.chargeTitle),
            _kv(s.t('fin.pdf.date'), _d(payment.date)),
            _kv(s.t('fin.pdf.method'), s.t('fin.method.${payment.method.name}')),
            if ((payment.reference ?? '').isNotEmpty)
              _kv(s.t('fin.pdf.reference'), payment.reference!),
            pw.Divider(color: _sky),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text(s.t('fin.pdf.amountPaid'),
                  style: pw.TextStyle(
                      fontSize: 13, fontWeight: pw.FontWeight.bold, color: _ink)),
              pw.Text(_m(payment.amount),
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold, color: _blue)),
            ]),
            pw.SizedBox(height: 6),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text(s.t('fin.pdf.remaining'),
                  style: const pw.TextStyle(fontSize: 10.5, color: _muted)),
              pw.Text(_m(remainingOnCharge),
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold, color: _ink)),
            ]),
          ]),
        ),
        pw.SizedBox(height: 10),
        pw.Text(s.t('fin.pdf.recordedBy', args: {'name': payment.recordedByName}),
            style: const pw.TextStyle(fontSize: 9, color: _muted)),
        pw.SizedBox(height: 50),
        pw.Align(
          alignment: s.isRtl ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
          child: pw.Column(children: [
            pw.Container(width: 160, height: 1, color: _muted),
            pw.SizedBox(height: 4),
            pw.Text(s.t('fin.pdf.signature'),
                style: const pw.TextStyle(fontSize: 9, color: _muted)),
          ]),
        ),
      ]),
    ));
    return doc.save();
  }

  // ─── Student statement ────────────────────────────────────────────────────

  static Future<Uint8List> statementPdf({
    required String studentName,
    String? className,
    required List<FeeCharge> charges,
    required List<FeePayment> payments,
    required AppStrings s,
  }) async {
    final billed = charges.fold<double>(0, (a, c) => a + c.due);
    final paid = charges.fold<double>(0, (a, c) => a + c.paidAmount);
    final sorted = [...charges]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final pays = [...payments]..sort((a, b) => a.date.compareTo(b.date));
    final hasClass = className != null && className.isNotEmpty;
    final subtitle = hasClass ? '$studentName  ·  $className' : studentName;

    final doc = pw.Document(
        theme: await ReportService.pdfTheme(), title: s.t('fin.pdf.statement'));
    doc.addPage(pw.MultiPage(
      pageTheme: _page(s),
      footer: ReportService.pdfFooter,
      build: (_) => [
        ReportService.pdfBanner(
          s.t('fin.pdf.statement'),
          subtitle,
        ),
        pw.SizedBox(height: 14),
        pw.Wrap(spacing: 8, runSpacing: 8, children: [
          ReportService.pdfPill(s.t('fin.pdf.billed'), _m(billed), _blue),
          ReportService.pdfPill(s.t('fin.pdf.paid'), _m(paid), _sky),
          ReportService.pdfPill(
              s.t('fin.pdf.balance'), _m((billed - paid).clamp(0, double.infinity)), _blue),
        ]),
        _h(s.t('fin.student.charges')),
        _table(
          [
            s.t('fin.pdf.item'),
            s.t('fin.charge.dueDate'),
            s.t('fin.pdf.billed'),
            s.t('fin.pdf.paid'),
            s.t('fin.pdf.balance'),
            '',
          ],
          [
            for (final c in sorted)
              [
                c.title,
                _d(c.dueDate),
                _m(c.due),
                _m(c.paidAmount),
                _m(c.balance),
                s.t('fin.status.${c.status.name}'),
              ],
          ],
        ),
        _h(s.t('fin.student.payments')),
        if (pays.isEmpty)
          pw.Text(s.t('fin.noPayments'),
              style: const pw.TextStyle(fontSize: 10, color: _muted))
        else
          _table(
            [
              s.t('fin.pdf.date'),
              s.t('fin.pdf.receiptNo'),
              s.t('fin.pdf.item'),
              s.t('fin.pdf.method'),
              s.t('fin.pdf.paid'),
            ],
            [
              for (final p in pays)
                [
                  _d(p.date),
                  p.receiptNo,
                  p.chargeTitle,
                  s.t('fin.method.${p.method.name}'),
                  _m(p.amount),
                ],
            ],
          ),
      ],
    ));
    return doc.save();
  }

  // ─── Outstanding list ─────────────────────────────────────────────────────

  static List<OutstandingRow> _sortedOutstanding(List<OutstandingRow> rows) =>
      rows.where((r) => r.balance > 0.004).toList()
        ..sort((a, b) => b.balance.compareTo(a.balance));

  static Future<Uint8List> outstandingPdf({
    required List<OutstandingRow> rows,
    required String academicYear,
    required String scopeLabel,
    required AppStrings s,
  }) async {
    final list = _sortedOutstanding(rows);
    final total = list.fold<double>(0, (a, r) => a + r.balance);
    final overdue = list.fold<double>(0, (a, r) => a + r.overdue);

    final doc = pw.Document(
        theme: await ReportService.pdfTheme(), title: s.t('fin.pdf.outstanding'));
    doc.addPage(pw.MultiPage(
      pageTheme: _page(s),
      footer: ReportService.pdfFooter,
      build: (_) => [
        ReportService.pdfBanner(
            s.t('fin.pdf.outstanding'), '$scopeLabel  ·  $academicYear'),
        pw.SizedBox(height: 14),
        pw.Wrap(spacing: 8, runSpacing: 8, children: [
          ReportService.pdfPill(s.t('fin.kpi.outstanding'), _m(total), _blue),
          ReportService.pdfPill(s.t('fin.kpi.overdue'), _m(overdue), _sky),
          ReportService.pdfPill(
              s.t('fin.pdf.student'), '${list.length}', _sky),
        ]),
        pw.SizedBox(height: 10),
        if (list.isEmpty)
          pw.Text(s.t('fin.noStudents'),
              style: const pw.TextStyle(fontSize: 11, color: _ink))
        else
          _table(
            [
              s.t('fin.pdf.student'),
              s.t('fin.pdf.class'),
              s.t('fin.pdf.billed'),
              s.t('fin.pdf.paid'),
              s.t('fin.pdf.balance'),
              s.t('fin.kpi.overdue'),
            ],
            [
              for (final r in list)
                [
                  r.studentName,
                  r.className,
                  _m(r.billed),
                  _m(r.paid),
                  _m(r.balance),
                  r.overdue > 0.004 ? _m(r.overdue) : '—',
                ],
              [s.t('fin.pdf.totals'), '', '', '', _m(total), _m(overdue)],
            ],
          ),
      ],
    ));
    return doc.save();
  }

  static String outstandingCsv(List<OutstandingRow> rows) {
    String q(String v) => '"${v.replaceAll('"', '""')}"';
    final out = ['Student,Class,Billed,Paid,Balance,Overdue'];
    for (final r in _sortedOutstanding(rows)) {
      out.add([
        q(r.studentName),
        q(r.className),
        r.billed.toStringAsFixed(2),
        r.paid.toStringAsFixed(2),
        r.balance.toStringAsFixed(2),
        r.overdue.toStringAsFixed(2),
      ].join(','));
    }
    return out.join('\n');
  }

  // ─── Payroll ──────────────────────────────────────────────────────────────

  static Future<Uint8List> payrollPdf({
    required String month,
    required List<SalaryRecord> records,
    required AppStrings s,
  }) async {
    final list = [...records]..sort((a, b) => a.staffName.compareTo(b.staffName));
    final total = list.fold<double>(0, (a, r) => a + r.net);
    final paid = list.where((r) => r.paid).fold<double>(0, (a, r) => a + r.net);

    final doc = pw.Document(
        theme: await ReportService.pdfTheme(), title: s.t('sal.payroll'));
    doc.addPage(pw.MultiPage(
      pageTheme: _page(s),
      footer: ReportService.pdfFooter,
      build: (_) => [
        ReportService.pdfBanner(s.t('sal.payroll'), month),
        pw.SizedBox(height: 14),
        pw.Wrap(spacing: 8, runSpacing: 8, children: [
          ReportService.pdfPill(s.t('sal.total'), _m(total), _blue),
          ReportService.pdfPill(s.t('sal.status.paid'), _m(paid), _sky),
          ReportService.pdfPill(
              s.t('sal.status.pending'), _m(total - paid), _sky),
        ]),
        pw.SizedBox(height: 10),
        _table(
          [
            s.t('sal.staff'),
            s.t('sal.role'),
            s.t('sal.base'),
            s.t('sal.bonus'),
            s.t('sal.deduction'),
            s.t('sal.net'),
            '',
          ],
          [
            for (final r in list)
              [
                r.staffName,
                r.roleLabel,
                _m(r.baseSalary),
                _m(r.bonus),
                _m(r.deduction),
                _m(r.net),
                s.t(r.paid ? 'sal.status.paid' : 'sal.status.pending'),
              ],
            [s.t('fin.pdf.totals'), '', '', '', '', _m(total), ''],
          ],
        ),
      ],
    ));
    return doc.save();
  }

  static Future<Uint8List> payslipPdf({
    required SalaryRecord record,
    required AppStrings s,
  }) async {
    final doc = pw.Document(
        theme: await ReportService.pdfTheme(), title: s.t('sal.payslip'));
    doc.addPage(pw.Page(
      pageTheme: _page(s),
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        ReportService.pdfBanner(
            s.t('sal.payslip'), '${record.staffName}  ·  ${record.month}'),
        pw.SizedBox(height: 18),
        pw.Container(
          padding: const pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _sky, width: 1.2),
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Column(children: [
            _kv(s.t('sal.role'), record.roleLabel),
            _kv(s.t('sal.base'), _m(record.baseSalary)),
            _kv(s.t('sal.bonus'), '+ ${_m(record.bonus)}'),
            _kv(s.t('sal.deduction'), '- ${_m(record.deduction)}'),
            if ((record.note ?? '').isNotEmpty) _kv(s.t('sal.note'), record.note!),
            pw.Divider(color: _sky),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text(s.t('sal.net'),
                  style: pw.TextStyle(
                      fontSize: 13, fontWeight: pw.FontWeight.bold, color: _ink)),
              pw.Text(_m(record.net),
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold, color: _blue)),
            ]),
            if (record.paid && record.paidAt != null) ...[
              pw.SizedBox(height: 6),
              pw.Align(
                alignment:
                    s.isRtl ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
                child: pw.Text(
                    s.t('sal.paidOn', args: {'date': _d(record.paidAt!)}),
                    style: const pw.TextStyle(fontSize: 10, color: _muted)),
              ),
            ],
          ]),
        ),
        pw.SizedBox(height: 50),
        pw.Align(
          alignment: s.isRtl ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
          child: pw.Column(children: [
            pw.Container(width: 160, height: 1, color: _muted),
            pw.SizedBox(height: 4),
            pw.Text(s.t('fin.pdf.signature'),
                style: const pw.TextStyle(fontSize: 9, color: _muted)),
          ]),
        ),
      ]),
    ));
    return doc.save();
  }
}
