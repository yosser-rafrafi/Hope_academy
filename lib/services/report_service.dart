import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/absence_model.dart';
import '../l10n/app_strings.dart';
import '../models/class_model.dart';

/// Branded PDF / CSV exports for attendance and text reports.
class ReportService {
  static const _blue = PdfColor.fromInt(0xFF4F8CFF);
  static const _sky = PdfColor.fromInt(0xFF4FC3F7);
  static const _ink = PdfColor.fromInt(0xFF2C3E50);
  static const _muted = PdfColor.fromInt(0xFF6C757D);
  static const _soft = PdfColor.fromInt(0xFFF1F5FB);

  static String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static Future<pw.ThemeData> _theme() async => pw.ThemeData.withFont(
        base: await PdfGoogleFonts.nunitoRegular(),
        bold: await PdfGoogleFonts.nunitoBold(),
        fontFallback: [await PdfGoogleFonts.notoSansArabicRegular()],
      );

  static pw.Widget _banner(String title, String subtitle) => pw.Container(
        padding: const pw.EdgeInsets.all(18),
        decoration: pw.BoxDecoration(
          borderRadius: pw.BorderRadius.circular(18),
          gradient: pw.LinearGradient(
            colors: [_blue, _sky],
            begin: pw.Alignment.topLeft,
            end: pw.Alignment.bottomRight,
          ),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('HOPE ACADEMY EGYPT',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.white, letterSpacing: 2)),
          pw.SizedBox(height: 4),
          pw.Text(title,
              style: pw.TextStyle(
                  fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          pw.SizedBox(height: 2),
          pw.Text(subtitle, style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
        ]),
      );

  static pw.Widget _footer(pw.Context c) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Generated ${_d(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 8, color: _muted)),
          pw.Text('${c.pageNumber}/${c.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: _muted)),
        ],
      );

  // ─── Shared building blocks (reused by PEI, finance… PDFs) ───────────────

  static const PdfColor brandBlue = _blue;
  static const PdfColor brandSky = _sky;
  static const PdfColor brandInk = _ink;
  static const PdfColor brandMuted = _muted;
  static const PdfColor brandSoft = _soft;

  static Future<pw.ThemeData> pdfTheme() => _theme();
  static pw.Widget pdfBanner(String title, String subtitle) =>
      _banner(title, subtitle);
  static pw.Widget pdfFooter(pw.Context c) => _footer(c);
  static pw.Widget pdfPill(String label, String value, PdfColor c) =>
      _pill(label, value, c);
  static String pdfDate(DateTime d) => _d(d);

  // ─── Attendance ───────────────────────────────────────────────────────────

  static Future<Uint8List> attendancePdf({
    required String title,
    required DateTime from,
    required DateTime to,
    required List<AbsenceModel> absences,
  }) async {
    final sorted = [...absences]..sort((a, b) => a.date.compareTo(b.date));
    final byType = <AbsenceType, int>{};
    for (final a in sorted) {
      byType[a.type] = (byType[a.type] ?? 0) + 1;
    }
    final doc = pw.Document(theme: await _theme(), title: title);
    doc.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 36),
      ),
      footer: _footer,
      build: (_) => [
        _banner(title, '${_d(from)}  →  ${_d(to)}'),
        pw.SizedBox(height: 14),
        pw.Wrap(spacing: 8, runSpacing: 8, children: [
          _pill('Total absences', '${sorted.length}', _blue),
          for (final e in byType.entries) _pill(e.key.label, '${e.value}', _sky),
        ]),
        pw.SizedBox(height: 14),
        if (sorted.isEmpty)
          pw.Text('No absences recorded for this period 🎉',
              style: const pw.TextStyle(fontSize: 11, color: _ink))
        else
          pw.TableHelper.fromTextArray(
            headers: const ['Date', 'Student', 'Type', 'Reason', 'Recorded by'],
            data: [
              for (final a in sorted)
                [_d(a.date), a.studentName, a.type.label, a.reason ?? '', a.recordedByName],
            ],
            headerStyle: pw.TextStyle(
                fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: _blue),
            cellStyle: const pw.TextStyle(fontSize: 9, color: _ink),
            oddRowDecoration: const pw.BoxDecoration(color: _soft),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          ),
      ],
    ));
    return doc.save();
  }

  // ─── Attendance lists (academy-wide / per class / per day) ───────────────

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// studentId → first class that lists the student.
  static Map<String, ClassModel> _classByStudent(List<ClassModel> classes) {
    final m = <String, ClassModel>{};
    for (final c in classes) {
      for (final id in c.studentIds) {
        m.putIfAbsent(id, () => c);
      }
    }
    return m;
  }

  /// Printable absence lists.
  ///
  /// * [groupByClass] = true  → one section per class (the "list per group").
  /// * [groupByClass] = false → one section per day (the "list of the day").
  ///
  /// [scopeLabel] is printed in the banner ("Toute l'académie", "Classe X"…).
  static Future<Uint8List> attendanceListPdf({
    required String title,
    required String scopeLabel,
    required DateTime from,
    required DateTime to,
    required List<AbsenceModel> absences,
    required List<ClassModel> classes,
    required bool groupByClass,
    AppStrings strings = const AppStrings(AppStrings.fallbackLocale),
  }) async {
    final s = strings;
    final noClass = s.t('common.noClass');
    String typeLabel(AbsenceType t) => s.t('abs.type.${t.name}');
    final classOf = _classByStudent(classes);
    final singleDay = _sameDay(from, to);
    final period = singleDay ? _d(from) : '${_d(from)}  →  ${_d(to)}';

    final byType = <AbsenceType, int>{};
    for (final a in absences) {
      byType[a.type] = (byType[a.type] ?? 0) + 1;
    }

    final headerStyle = pw.TextStyle(
        fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white);
    const cellStyle = pw.TextStyle(fontSize: 9, color: _ink);

    pw.Widget table(List<String> headers, List<List<String>> rows) =>
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows,
          headerStyle: headerStyle,
          headerDecoration: const pw.BoxDecoration(color: _blue),
          cellStyle: cellStyle,
          oddRowDecoration: const pw.BoxDecoration(color: _soft),
          cellPadding:
              const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        );

    pw.Widget sectionTitle(String left, String right) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 14, bottom: 6),
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: pw.BoxDecoration(
            color: _soft,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: _sky),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(left,
                  style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: _ink)),
              pw.Text(right,
                  style: const pw.TextStyle(fontSize: 9, color: _muted)),
            ],
          ),
        );

    final body = <pw.Widget>[];

    if (absences.isEmpty) {
      body.add(pw.Text(s.t('abs.noneInPeriod'),
          style: const pw.TextStyle(fontSize: 11, color: _ink)));
    } else if (groupByClass) {
      // ── One section per class ────────────────────────────────────────────
      final groups = <String, List<AbsenceModel>>{};
      final names = <String, String>{};
      final sizes = <String, int>{};
      for (final a in absences) {
        final c = classOf[a.studentId];
        final key = c?.id ?? '_none';
        names[key] = c?.name ?? noClass;
        if (c != null) sizes[key] = c.studentCount;
        groups.putIfAbsent(key, () => []).add(a);
      }
      final keys = groups.keys.toList()
        ..sort((a, b) {
          if (a == '_none') return 1;
          if (b == '_none') return -1;
          return names[a]!.compareTo(names[b]!);
        });

      for (final k in keys) {
        final list = groups[k]!
          ..sort((a, b) {
            final d = a.date.compareTo(b.date);
            return d != 0 ? d : a.studentName.compareTo(b.studentName);
          });
        final size = sizes[k];
        final right = (singleDay && size != null)
            ? s.t('abs.ratio', args: {'n': list.length, 'total': size})
            : s.t('abs.count', args: {'n': list.length});
        body.add(sectionTitle(names[k]!, right));
        body.add(singleDay
            ? table(
                [
                  s.t('abs.pdf.student'),
                  s.t('abs.pdf.type'),
                  s.t('abs.pdf.reason'),
                  s.t('abs.pdf.recordedBy'),
                ],
                [
                  for (final a in list)
                    [a.studentName, typeLabel(a.type), a.reason ?? '', a.recordedByName],
                ],
              )
            : table(
                [
                  s.t('abs.pdf.date'),
                  s.t('abs.pdf.student'),
                  s.t('abs.pdf.type'),
                  s.t('abs.pdf.reason'),
                  s.t('abs.pdf.recordedBy'),
                ],
                [
                  for (final a in list)
                    [
                      _d(a.date),
                      a.studentName,
                      typeLabel(a.type),
                      a.reason ?? '',
                      a.recordedByName,
                    ],
                ],
              ));
      }

      // Classes with nobody absent (useful for an academy-wide daily list)
      final withAbsences = keys.toSet();
      final clean = classes
          .where((c) => !withAbsences.contains(c.id))
          .map((c) => c.name)
          .toList()
        ..sort();
      if (clean.isNotEmpty) {
        body.add(pw.SizedBox(height: 12));
        body.add(pw.Text(s.t('abs.noneClasses', args: {'names': clean.join(', ')}),
            style: const pw.TextStyle(fontSize: 9, color: _muted)));
      }
    } else {
      // ── One section per day ──────────────────────────────────────────────
      final days = <DateTime, List<AbsenceModel>>{};
      for (final a in absences) {
        days.putIfAbsent(a.normalizedDate, () => []).add(a);
      }
      final keys = days.keys.toList()..sort();
      for (final day in keys) {
        final list = days[day]!
          ..sort((a, b) {
            final ca = classOf[a.studentId]?.name ?? noClass;
            final cb = classOf[b.studentId]?.name ?? noClass;
            final c = ca.compareTo(cb);
            return c != 0 ? c : a.studentName.compareTo(b.studentName);
          });
        body.add(sectionTitle(
            '${s.t('abs.weekday.${day.weekday}')} ${_d(day)}',
            s.t('abs.count', args: {'n': list.length})));
        body.add(table(
          [
            s.t('abs.pdf.student'),
            s.t('abs.pdf.class'),
            s.t('abs.pdf.type'),
            s.t('abs.pdf.reason'),
            s.t('abs.pdf.recordedBy'),
          ],
          [
            for (final a in list)
              [
                a.studentName,
                classOf[a.studentId]?.name ?? noClass,
                typeLabel(a.type),
                a.reason ?? '',
                a.recordedByName,
              ],
          ],
        ));
      }
    }

    final doc = pw.Document(theme: await _theme(), title: title);
    doc.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 36),
        textDirection: s.isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      ),
      footer: _footer,
      build: (_) => [
        _banner(title, '$scopeLabel  ·  $period'),
        pw.SizedBox(height: 14),
        pw.Wrap(spacing: 8, runSpacing: 8, children: [
          _pill(s.t('abs.pdf.total'), '${absences.length}', _blue),
          for (final e in byType.entries) _pill(typeLabel(e.key), '${e.value}', _sky),
        ]),
        ...body,
      ],
    ));
    return doc.save();
  }

  /// CSV twin of [attendanceListPdf] (adds a Class column, sorted by date).
  static String attendanceListCsv(
      List<AbsenceModel> absences, List<ClassModel> classes) {
    final classOf = _classByStudent(classes);
    String q(String? v) => '"${(v ?? '').replaceAll('"', '""')}"';
    final rows = <String>[
      'Date,Class,Student,Type,Reason,Recorded by,Parents notified'
    ];
    final sorted = [...absences]..sort((a, b) {
        final d = a.date.compareTo(b.date);
        return d != 0 ? d : a.studentName.compareTo(b.studentName);
      });
    for (final a in sorted) {
      rows.add([
        _d(a.date),
        q(classOf[a.studentId]?.name ?? 'No class'),
        q(a.studentName),
        q(a.type.label),
        q(a.reason),
        q(a.recordedByName),
        a.parentNotified ? 'yes' : 'no',
      ].join(','));
    }
    return rows.join('\n');
  }

  static pw.Widget _pill(String label, String value, PdfColor c) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: pw.BoxDecoration(
          color: _soft,
          borderRadius: pw.BorderRadius.circular(12),
          border: pw.Border.all(color: c),
        ),
        child: pw.Column(children: [
          pw.Text(value,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: c)),
          pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: _muted)),
        ]),
      );

  static String attendanceCsv(List<AbsenceModel> absences) {
    String q(String? v) => '"${(v ?? '').replaceAll('"', '""')}"';
    final rows = <String>['Date,Student,Type,Reason,Recorded by,Parents notified'];
    final sorted = [...absences]..sort((a, b) => a.date.compareTo(b.date));
    for (final a in sorted) {
      rows.add([
        _d(a.date),
        q(a.studentName),
        q(a.type.label),
        q(a.reason),
        q(a.recordedByName),
        a.parentNotified ? 'yes' : 'no',
      ].join(','));
    }
    return rows.join('\n');
  }

  // ─── Generic text report (AI summaries, announcements…) ──────────────────

  static Future<Uint8List> textReportPdf({
    required String title,
    required String subtitle,
    required String body,
  }) async {
    final doc = pw.Document(theme: await _theme(), title: title);
    final paragraphs = body.split('\n');
    doc.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 40),
      ),
      footer: _footer,
      build: (_) => [
        _banner(title, subtitle),
        pw.SizedBox(height: 16),
        for (final p in paragraphs)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text(p.isEmpty ? ' ' : p,
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 3, color: _ink)),
          ),
      ],
    ));
    return doc.save();
  }
}
