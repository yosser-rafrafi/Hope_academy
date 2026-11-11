import 'dart:math' as math;
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/absence_model.dart';
import '../models/activity_model.dart';
import '../models/user_model.dart';
import 'absence_service.dart';
import 'activity_service.dart';
import 'storage_service.dart';

/// Sections a student portfolio / CV can contain.
enum PortfolioSection {
  skills,
  objectives,
  activities,
  gallery,
  attendance,
  mood,
  teacherNotes,
  family,
  medical,
}

extension PortfolioSectionX on PortfolioSection {
  String get label => const {
        PortfolioSection.skills: 'Skills & strengths',
        PortfolioSection.objectives: 'Objectives achieved',
        PortfolioSection.activities: 'Activity history',
        PortfolioSection.gallery: 'Photo gallery',
        PortfolioSection.attendance: 'Attendance',
        PortfolioSection.mood: 'Mood & wellbeing',
        PortfolioSection.teacherNotes: "Teachers' notes",
        PortfolioSection.family: 'Family contacts',
        PortfolioSection.medical: 'Medical information',
      }[this]!;

  String get emoji => const {
        PortfolioSection.skills: '⭐',
        PortfolioSection.objectives: '🎯',
        PortfolioSection.activities: '🎨',
        PortfolioSection.gallery: '📸',
        PortfolioSection.attendance: '📅',
        PortfolioSection.mood: '😊',
        PortfolioSection.teacherNotes: '📝',
        PortfolioSection.family: '👨‍👩‍👧',
        PortfolioSection.medical: '🩺',
      }[this]!;

  /// Sensitive sections are OFF by default and clearly marked.
  bool get sensitive =>
      this == PortfolioSection.family ||
      this == PortfolioSection.medical ||
      this == PortfolioSection.teacherNotes;

  static Set<PortfolioSection> get defaults =>
      PortfolioSection.values.where((s) => !s.sensitive).toSet();
}

class SkillStat {
  final ActivityCategory category;
  final int sessions;
  final int minutes;
  final double? avgFocus; // 0..100, null if never logged
  const SkillStat(this.category, this.sessions, this.minutes, this.avgFocus);

  /// 1..5 stars from focus (preferred) or number of sessions.
  int get stars {
    if (avgFocus != null && avgFocus! > 0) {
      return (avgFocus! / 20).ceil().clamp(1, 5);
    }
    return (sessions / 3).ceil().clamp(1, 5);
  }

  double get ratio => stars / 5;
}

class PortfolioData {
  final UserModel student;
  final List<ActivityModel> activities; // completed, newest first
  final List<AbsenceModel> absences;
  final List<SkillStat> skills;
  final List<String> objectives;
  final Map<MoodLevel, int> moods;

  PortfolioData({
    required this.student,
    required this.activities,
    required this.absences,
    required this.skills,
    required this.objectives,
    required this.moods,
  });

  int get totalMinutes => activities.fold(0, (a, b) => a + (b.duration ?? 0));

  List<String> get photoUrls => activities
      .expand((a) => a.mediaUrls)
      .where((u) => !StorageService.isVideoUrl(u))
      .toSet()
      .toList();

  int get age {
    final b = student.birthday;
    if (b == null) return 0;
    final n = DateTime.now();
    var a = n.year - b.year;
    if (n.month < b.month || (n.month == b.month && n.day < b.day)) a--;
    return a;
  }
}

class PortfolioService {
  final _activities = ActivityService();
  final _absences = AbsenceService();

  /// [viewerIsParent] hides activities flagged "staff only".
  Future<PortfolioData> load(UserModel student, {required bool viewerIsParent}) async {
    final all = await _activities.streamByStudent(student.uid).first;
    final acts = all
        .where((a) => !viewerIsParent || a.isVisibleToParent)
        .where((a) => a.status == ActivityStatus.completed)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    List<AbsenceModel> abs = [];
    try {
      abs = await _absences.getAbsencesByStudent(student.uid);
    } catch (_) {}

    final byCat = <ActivityCategory, List<ActivityModel>>{};
    for (final a in acts) {
      byCat.putIfAbsent(a.category, () => []).add(a);
    }
    final skills = byCat.entries.map((e) {
      final focus = e.value.where((a) => a.concentrationRate > 0).toList();
      final avg = focus.isEmpty
          ? null
          : focus.fold<double>(0, (s, a) => s + a.concentrationRate) / focus.length;
      return SkillStat(e.key, e.value.length,
          e.value.fold(0, (s, a) => s + (a.duration ?? 0)), avg);
    }).toList()
      ..sort((a, b) => b.stars != a.stars ? b.stars.compareTo(a.stars) : b.sessions.compareTo(a.sessions));

    final objectives = <String>{for (final a in acts) ...a.objectives}.toList();
    final moods = <MoodLevel, int>{};
    for (final a in acts) {
      if (a.mood != null) moods[a.mood!] = (moods[a.mood!] ?? 0) + 1;
    }
    return PortfolioData(
      student: student,
      activities: acts,
      absences: abs,
      skills: skills,
      objectives: objectives,
      moods: moods,
    );
  }

  // ─── PDF ──────────────────────────────────────────────────────────────────

  static const _blue = PdfColor.fromInt(0xFF4F8CFF);
  static const _sky = PdfColor.fromInt(0xFF4FC3F7);
  static const _mint = PdfColor.fromInt(0xFF3BB6A0);
  static const _sun = PdfColor.fromInt(0xFFFFB22E);
  static const _grape = PdfColor.fromInt(0xFF8C6BFF);
  static const _coral = PdfColor.fromInt(0xFFFF6B6B);
  static const _ink = PdfColor.fromInt(0xFF2C3E50);
  static const _muted = PdfColor.fromInt(0xFF6C757D);
  static const _soft = PdfColor.fromInt(0xFFF1F5FB);

  String _d(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  Future<Uint8List> buildPdf(PortfolioData d, Set<PortfolioSection> sections) async {
    final regular = await PdfGoogleFonts.nunitoRegular();
    final bold = await PdfGoogleFonts.nunitoBold();
    final arabic = await PdfGoogleFonts.notoSansArabicRegular();
    final doc = pw.Document(
      title: '${d.student.fullName} – Portfolio',
      author: 'Hope Academy Egypt',
      theme: pw.ThemeData.withFont(base: regular, bold: bold, fontFallback: [arabic]),
    );

    pw.ImageProvider? photo;
    final url = d.student.profileImageUrl;
    if (url != null && url.isNotEmpty) {
      try {
        photo = await networkImage(url);
      } catch (_) {}
    }
    final gallery = <pw.ImageProvider>[];
    if (sections.contains(PortfolioSection.gallery)) {
      for (final u in d.photoUrls.take(6)) {
        try {
          gallery.add(await networkImage(u));
        } catch (_) {}
      }
    }

    doc.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.fromLTRB(28, 28, 28, 36),
      ),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Hope Academy Egypt • ${_d(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 8, color: _muted)),
          pw.Text('${ctx.pageNumber}/${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: _muted)),
        ],
      ),
      build: (ctx) => [
        _header(d, photo),
        pw.SizedBox(height: 14),
        _statsRow(d, sections),
        if (sections.contains(PortfolioSection.skills) && d.skills.isNotEmpty)
          ..._section('Skills & strengths', _sky, [
            for (final s in d.skills.take(8)) _skillBar(s),
          ]),
        if (sections.contains(PortfolioSection.objectives) && d.objectives.isNotEmpty)
          ..._section('Objectives achieved', _mint, [
            pw.Wrap(spacing: 6, runSpacing: 6, children: [
              for (final o in d.objectives.take(24)) _chip(o, _mint),
            ]),
          ]),
        if (sections.contains(PortfolioSection.activities) && d.activities.isNotEmpty)
          ..._section('Activity history', _grape, [
            for (final a in d.activities.take(14)) _activityRow(a),
          ]),
        if (gallery.isNotEmpty)
          ..._section('Photo gallery', _sun, [
            pw.Wrap(spacing: 8, runSpacing: 8, children: [
              for (final g in gallery)
                pw.ClipRRect(
                  horizontalRadius: 10,
                  verticalRadius: 10,
                  child: pw.Image(g, width: 160, height: 120, fit: pw.BoxFit.cover),
                ),
            ]),
          ]),
        if (sections.contains(PortfolioSection.attendance))
          ..._section('Attendance', _blue, [_attendance(d)]),
        if (sections.contains(PortfolioSection.mood) && d.moods.isNotEmpty)
          ..._section('Mood & wellbeing', _coral, [_moods(d)]),
        if (sections.contains(PortfolioSection.teacherNotes))
          ..._notes(d),
        if (sections.contains(PortfolioSection.family))
          ..._section('Family contacts', _muted, [_family(d.student)]),
        if (sections.contains(PortfolioSection.medical))
          ..._section('Medical information', _coral, [_medical(d.student)]),
      ],
    ));
    return doc.save();
  }

  pw.Widget _header(PortfolioData d, pw.ImageProvider? photo) {
    final s = d.student;
    final sub = [
      if (d.age > 0) '${d.age} years old',
      if (s.group != null && s.group!.isNotEmpty) s.group!,
      if (s.enrollmentDate != null) 'Enrolled ${_d(s.enrollmentDate!)}',
    ].join('  •  ');
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(20),
        gradient: pw.LinearGradient(
          colors: [_blue, _sky],
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
        ),
      ),
      child: pw.Row(children: [
        pw.Container(
          width: 84,
          height: 84,
          decoration: const pw.BoxDecoration(
              color: PdfColors.white, shape: pw.BoxShape.circle),
          padding: const pw.EdgeInsets.all(3),
          child: photo != null
              ? pw.ClipOval(child: pw.Image(photo, fit: pw.BoxFit.cover))
              : pw.Center(
                  child: pw.Text(s.initials,
                      style: pw.TextStyle(
                          fontSize: 28, fontWeight: pw.FontWeight.bold, color: _blue))),
        ),
        pw.SizedBox(width: 16),
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('STUDENT PORTFOLIO',
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.white, letterSpacing: 2)),
            pw.SizedBox(height: 4),
            pw.Text(s.fullName,
                style: pw.TextStyle(
                    fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            if (sub.isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Text(sub, style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
            ],
            pw.SizedBox(height: 6),
            pw.Text('Hope Academy Egypt',
                style: pw.TextStyle(
                    fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          ]),
        ),
      ]),
    );
  }

  pw.Widget _statsRow(PortfolioData d, Set<PortfolioSection> sec) {
    pw.Widget box(String v, String l, PdfColor c) => pw.Expanded(
          child: pw.Container(
            margin: const pw.EdgeInsets.symmetric(horizontal: 3),
            padding: const pw.EdgeInsets.symmetric(vertical: 10),
            decoration: pw.BoxDecoration(
              color: _soft,
              borderRadius: pw.BorderRadius.circular(14),
              border: pw.Border.all(color: c, width: 1),
            ),
            child: pw.Column(children: [
              pw.Text(v,
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: c)),
              pw.Text(l, style: const pw.TextStyle(fontSize: 8, color: _muted)),
            ]),
          ),
        );
    final hours = (d.totalMinutes / 60).toStringAsFixed(d.totalMinutes % 60 == 0 ? 0 : 1);
    return pw.Row(children: [
      box('${d.activities.length}', 'Activities', _grape),
      box(hours, 'Hours learning', _sky),
      box('${d.skills.length}', 'Skill areas', _mint),
      box('${d.objectives.length}', 'Objectives', _sun),
    ]);
  }

  List<pw.Widget> _section(String title, PdfColor color, List<pw.Widget> body) => [
        pw.SizedBox(height: 16),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: pw.BoxDecoration(
              color: color, borderRadius: pw.BorderRadius.circular(10)),
          child: pw.Text(title,
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
        ),
        pw.SizedBox(height: 8),
        ...body,
      ];

  pw.Widget _chip(String t, PdfColor c) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: pw.BoxDecoration(
          color: _soft,
          borderRadius: pw.BorderRadius.circular(12),
          border: pw.Border.all(color: c, width: 0.8),
        ),
        child: pw.Text(t, style: const pw.TextStyle(fontSize: 9, color: _ink)),
      );

  pw.Widget _skillBar(SkillStat s) {
    final pct = (s.ratio * 100).round().clamp(5, 100);
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 7),
      child: pw.Row(children: [
        pw.SizedBox(
          width: 130,
          child: pw.Text(s.category.label,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _ink)),
        ),
        pw.Expanded(
          child: pw.Container(
            height: 9,
            decoration: pw.BoxDecoration(
                color: _soft, borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Row(children: [
              pw.Expanded(
                flex: pct,
                child: pw.Container(
                  decoration: pw.BoxDecoration(
                      color: _sky, borderRadius: pw.BorderRadius.circular(6)),
                ),
              ),
              if (pct < 100) pw.Expanded(flex: 100 - pct, child: pw.SizedBox()),
            ]),
          ),
        ),
        pw.SizedBox(width: 8),
        pw.SizedBox(
          width: 70,
          child: pw.Text('${s.stars}/5 • ${s.sessions} sessions',
              style: const pw.TextStyle(fontSize: 8, color: _muted)),
        ),
      ]),
    );
  }

  pw.Widget _activityRow(ActivityModel a) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 6),
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: _soft,
          borderRadius: pw.BorderRadius.circular(10),
        ),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Container(
            width: 4,
            height: 28,
            decoration: pw.BoxDecoration(
                color: _grape, borderRadius: pw.BorderRadius.circular(2)),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(a.title,
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold, color: _ink)),
              pw.Text(
                  '${a.category.label}${a.duration != null ? ' • ${a.duration} min' : ''}'
                  '${a.mood != null ? ' • ${a.mood!.label}' : ''}',
                  style: const pw.TextStyle(fontSize: 8, color: _muted)),
            ]),
          ),
          pw.Text(_d(a.date), style: const pw.TextStyle(fontSize: 8, color: _muted)),
        ]),
      );

  pw.Widget _attendance(PortfolioData d) {
    final byType = <AbsenceType, int>{};
    for (final a in d.absences) {
      byType[a.type] = (byType[a.type] ?? 0) + 1;
    }
    if (d.absences.isEmpty) {
      return pw.Text('No absences recorded — perfect attendance!',
          style: const pw.TextStyle(fontSize: 10, color: _ink));
    }
    return pw.Wrap(spacing: 6, runSpacing: 6, children: [
      _chip('Total: ${d.absences.length}', _blue),
      for (final e in byType.entries) _chip('${e.key.label}: ${e.value}', _blue),
    ]);
  }

  pw.Widget _moods(PortfolioData d) {
    final total = d.moods.values.fold(0, (a, b) => a + b);
    return pw.Wrap(spacing: 6, runSpacing: 6, children: [
      for (final e in d.moods.entries)
        _chip('${e.key.label}: ${(e.value * 100 / math.max(1, total)).round()}%', _coral),
    ]);
  }

  List<pw.Widget> _notes(PortfolioData d) {
    final notes = d.activities
        .where((a) => (a.teacherNotes ?? '').trim().isNotEmpty)
        .take(5)
        .toList();
    if (notes.isEmpty) return [];
    return _section("Teachers' notes", _muted, [
      for (final a in notes)
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 6),
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
              color: _soft, borderRadius: pw.BorderRadius.circular(10)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('${a.title} • ${_d(a.date)}',
                style: pw.TextStyle(
                    fontSize: 8, fontWeight: pw.FontWeight.bold, color: _muted)),
            pw.SizedBox(height: 2),
            pw.Text(a.teacherNotes!, style: const pw.TextStyle(fontSize: 9, color: _ink)),
          ]),
        ),
    ]);
  }

  pw.Widget _line(String k, String? v) => (v == null || v.isEmpty)
      ? pw.SizedBox()
      : pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Row(children: [
            pw.SizedBox(
                width: 90,
                child: pw.Text(k, style: const pw.TextStyle(fontSize: 9, color: _muted))),
            pw.Expanded(
                child: pw.Text(v, style: const pw.TextStyle(fontSize: 10, color: _ink))),
          ]),
        );

  pw.Widget _family(UserModel s) => pw.Column(children: [
        _line('Mother', [s.motherName, s.motherPhone].whereType<String>().join(' • ')),
        _line('Father', [s.fatherName, s.fatherPhone].whereType<String>().join(' • ')),
        _line('Phone', s.phoneNumber),
        _line('Address', s.address),
      ]);

  pw.Widget _medical(UserModel s) => pw.Column(children: [
        _line('Diagnoses', s.diagnoses.join(', ')),
        _line('Allergies', s.allergies.join(', ')),
        _line('Medications',
            s.medications.map((m) => '${m.name} (${m.dosage})').join(', ')),
      ]);
}
