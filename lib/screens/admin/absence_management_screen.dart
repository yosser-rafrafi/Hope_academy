import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../l10n/app_strings.dart';
import '../../models/absence_model.dart';
import '../../models/class_model.dart';
import '../../services/absence_service.dart';
import '../../services/class_service.dart';
import '../../widgets/attendance_list_export_sheet.dart';
import '../shared/class_attendance_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AbsenceManagementScreen — Vue unifiée admin / sub-admin
//
//  • Statistiques globales du jour en haut (toutes classes)
//  • Filtres : période (Jour / Semaine / Mois / Custom) + classe
//  • Liste des absences regroupées par jour OU par classe
//  • Export PDF / CSV / impression des listes (académie entière ou classe)
//  • Bouton "Faire l'appel" par classe
// ─────────────────────────────────────────────────────────────────────────────

enum _PeriodMode { day, week, month, custom }

extension _PeriodModeExt on _PeriodMode {
  String get label {
    switch (this) {
      case _PeriodMode.day:    return 'abs.period.day';
      case _PeriodMode.week:   return 'abs.period.week';
      case _PeriodMode.month:  return 'abs.period.month';
      case _PeriodMode.custom: return 'abs.period.custom';
    }
  }

  IconData get icon {
    switch (this) {
      case _PeriodMode.day:    return Icons.today_outlined;
      case _PeriodMode.week:   return Icons.date_range_outlined;
      case _PeriodMode.month:  return Icons.calendar_month_outlined;
      case _PeriodMode.custom: return Icons.tune_outlined;
    }
  }
}

enum _GroupMode { byDay, byClass }

extension _GroupModeExt on _GroupMode {
  /// Translation key (resolve with context.tr).
  String get label =>
      this == _GroupMode.byDay ? 'abs.group.byDay' : 'abs.group.byClass';
  IconData get icon => this == _GroupMode.byDay
      ? Icons.calendar_today_outlined
      : Icons.groups_2_outlined;
}

// ─── Main screen ─────────────────────────────────────────────────────────────

class AbsenceManagementScreen extends StatefulWidget {
  const AbsenceManagementScreen({super.key});

  @override
  State<AbsenceManagementScreen> createState() =>
      _AbsenceManagementScreenState();
}

class _AbsenceManagementScreenState extends State<AbsenceManagementScreen> {
  final _absenceService = AbsenceService();
  final _classService   = ClassService();

  // ── Period filter ──────────────────────────────────────────────────────────
  _PeriodMode _mode   = _PeriodMode.day;
  DateTime    _anchor = DateTime.now();
  DateTime?   _customStart;
  DateTime?   _customEnd;

  // ── Display grouping ───────────────────────────────────────────────────────
  _GroupMode _groupMode = _GroupMode.byDay;

  /// Absences currently displayed (after period + class filters) — used by
  /// the export button so the PDF always matches what the admin sees.
  List<AbsenceModel> _visibleAbsences = [];

  // ── Class filter ───────────────────────────────────────────────────────────
  ClassModel? _selectedClass;
  List<ClassModel> _classes = [];

  // ── Derived range ──────────────────────────────────────────────────────────
  DateTime get _rangeStart {
    switch (_mode) {
      case _PeriodMode.day:
        return DateTime(_anchor.year, _anchor.month, _anchor.day);
      case _PeriodMode.week:
        final offset = _anchor.weekday - 1; // Mon = 1
        final mon = _anchor.subtract(Duration(days: offset));
        return DateTime(mon.year, mon.month, mon.day);
      case _PeriodMode.month:
        return DateTime(_anchor.year, _anchor.month, 1);
      case _PeriodMode.custom:
        final s = _customStart ?? _anchor;
        return DateTime(s.year, s.month, s.day);
    }
  }

  DateTime get _rangeEnd {
    switch (_mode) {
      case _PeriodMode.day:
        return DateTime(_anchor.year, _anchor.month, _anchor.day, 23, 59, 59);
      case _PeriodMode.week:
        final offset = _anchor.weekday - 1;
        final mon = _anchor.subtract(Duration(days: offset));
        final sun = mon.add(const Duration(days: 6));
        return DateTime(sun.year, sun.month, sun.day, 23, 59, 59);
      case _PeriodMode.month:
        final last = DateTime(_anchor.year, _anchor.month + 1, 0);
        return DateTime(last.year, last.month, last.day, 23, 59, 59);
      case _PeriodMode.custom:
        final e = _customEnd ?? _rangeStart;
        return DateTime(e.year, e.month, e.day, 23, 59, 59);
    }
  }

  String get _periodLabel {
    final f = _fmtShort(_rangeStart);
    if (_mode == _PeriodMode.day) return f;
    return '$f – ${_fmtShort(_rangeEnd)}';
  }

  String _fmtShort(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _fmtFull(DateTime d) {
    const months = [
      'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
      'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  bool get _isToday {
    final now = DateTime.now();
    return _mode == _PeriodMode.day &&
        _anchor.year == now.year &&
        _anchor.month == now.month &&
        _anchor.day == now.day;
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  void _prev() => setState(() {
        switch (_mode) {
          case _PeriodMode.day:
            _anchor = _anchor.subtract(const Duration(days: 1));
          case _PeriodMode.week:
            _anchor = _anchor.subtract(const Duration(days: 7));
          case _PeriodMode.month:
            _anchor = DateTime(_anchor.year, _anchor.month - 1, 1);
          case _PeriodMode.custom:
            break;
        }
      });

  void _next() => setState(() {
        switch (_mode) {
          case _PeriodMode.day:
            _anchor = _anchor.add(const Duration(days: 1));
          case _PeriodMode.week:
            _anchor = _anchor.add(const Duration(days: 7));
          case _PeriodMode.month:
            _anchor = DateTime(_anchor.year, _anchor.month + 1, 1);
          case _PeriodMode.custom:
            break;
        }
      });

  Future<void> _pickCustomRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDateRange: _customStart != null && _customEnd != null
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
        _mode = _PeriodMode.custom;
        _customStart = range.start;
        _customEnd = range.end;
      });
    }
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchor,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _anchor = picked);
  }

  // ── Filter absences by selected class ─────────────────────────────────────
  List<AbsenceModel> _filterByClass(List<AbsenceModel> all) {
    if (_selectedClass == null) return all;
    return all
        .where((a) => _selectedClass!.studentIds.contains(a.studentId))
        .toList();
  }

  // ── Export (PDF / CSV / print) ─────────────────────────────────────────────
  void _openExport() {
    showAttendanceListExportSheet(
      context,
      absences: _visibleAbsences,
      classes: _selectedClass != null ? [_selectedClass!] : _classes,
      from: _rangeStart,
      to: _rangeEnd,
      scopeLabel: _selectedClass == null
          ? context.tr('abs.scope.academy')
          : context.tr('abs.scope.class', args: {'name': _selectedClass!.name}),
      initialGroupByClass: _groupMode == _GroupMode.byClass,
    );
  }

  /// Class that contains [studentId] (null = not enrolled anywhere).
  ClassModel? _classOf(String studentId) {
    for (final c in _classes) {
      if (c.studentIds.contains(studentId)) return c;
    }
    return null;
  }

  // ── Navigate to attendance sheet ───────────────────────────────────────────
  void _openAttendance(ClassModel cls) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClassAttendanceScreen(
          cls: cls,
          initialDate: _mode == _PeriodMode.day ? _anchor : DateTime.now(),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ClassModel>>(
      stream: _classService.streamAll(),
      builder: (context, classSnap) {
        final classes = classSnap.data ?? [];
        // Keep local class list in sync without setState loop
        if (classes.length != _classes.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _classes = classes);
          });
        }

        return Column(
          children: [
            _buildHeader(classes),
            Expanded(child: _buildBody()),
          ],
        );
      },
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(List<ClassModel> classes) {
    return Container(
      color: context.surfaceBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title row ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.event_available_outlined,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(context.tr('abs.title'),
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary)),
                  Text(context.tr('abs.subtitle'),
                      style: TextStyle(
                          fontSize: 12, color: context.textSecondary)),
                ]),
              ),
              IconButton.filledTonal(
                tooltip: context.tr('abs.export.tooltip'),
                onPressed: _openExport,
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
              ),
            ]),
          ),

          const SizedBox(height: 14),

          // ── Today's global stats ─────────────────────────────────────────
          _TodayStatsBar(
            absenceService: _absenceService,
            classes: _classes,
          ),

          const SizedBox(height: 12),

          // ── Period mode chips ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _PeriodMode.values.map((m) {
                  final sel = _mode == m;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: sel,
                      avatar: Icon(m.icon,
                          size: 15,
                          color: sel
                              ? Colors.white
                              : context.textSecondary),
                      label: Text(context.tr(m.label),
                          style: TextStyle(
                              fontSize: 12,
                              color: sel
                                  ? Colors.white
                                  : context.textPrimary)),
                      selectedColor: AppColors.primary,
                      backgroundColor: context.softFill,
                      side: BorderSide(
                          color: sel
                              ? AppColors.primary
                              : context.divider),
                      showCheckmark: false,
                      onSelected: (_) async {
                        if (m == _PeriodMode.custom) {
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
          ),

          const SizedBox(height: 10),

          // ── Period navigator ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              if (_mode != _PeriodMode.custom) ...[
                _NavBtn(icon: Icons.chevron_left, onTap: _prev),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: GestureDetector(
                  onTap:
                      _mode == _PeriodMode.day ? _pickDay : null,
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
                      Expanded(
                        child: Text(
                          _isToday
                              ? "${context.tr('common.today')} — ${_fmtFull(_anchor)}"
                              : _periodLabel,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_mode == _PeriodMode.day)
                        Icon(Icons.edit_calendar_outlined,
                            size: 15, color: context.brand),
                    ]),
                  ),
                ),
              ),
              if (_mode != _PeriodMode.custom) ...[
                const SizedBox(width: 8),
                _NavBtn(icon: Icons.chevron_right, onTap: _next),
              ],
            ]),
          ),

          const SizedBox(height: 10),

          // ── Class filter chips ────────────────────────────────────────────
          if (classes.isNotEmpty)
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _ClassFilterChip(
                    label: context.tr('abs.allClasses'),
                    selected: _selectedClass == null,
                    onTap: () =>
                        setState(() => _selectedClass = null),
                  ),
                  ...classes.map((c) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _ClassFilterChip(
                          label: c.name,
                          selected: _selectedClass?.id == c.id,
                          onTap: () =>
                              setState(() => _selectedClass = c),
                        ),
                      )),
                ],
              ),
            ),

          const SizedBox(height: 10),

          // ── Grouping toggle ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Text(context.tr('abs.show'),
                  style: TextStyle(
                      fontSize: 12, color: context.textSecondary)),
              const SizedBox(width: 10),
              ..._GroupMode.values.map((g) {
                final sel = _groupMode == g;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: sel,
                    showCheckmark: false,
                    avatar: Icon(g.icon,
                        size: 15,
                        color: sel ? Colors.white : context.textSecondary),
                    label: Text(context.tr(g.label),
                        style: TextStyle(
                            fontSize: 12,
                            color: sel ? Colors.white : context.textPrimary)),
                    selectedColor: AppColors.primary,
                    backgroundColor: context.softFill,
                    side: BorderSide(
                        color: sel ? AppColors.primary : context.divider),
                    onSelected: (_) => setState(() => _groupMode = g),
                  ),
                );
              }),
            ]),
          ),

          const SizedBox(height: 12),
          Divider(height: 1, color: context.divider),
        ],
      ),
    );
  }

  // ─── Body ─────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    return StreamBuilder<List<AbsenceModel>>(
      stream: _absenceService.streamAbsencesByDateRange(
        startDate: _rangeStart,
        endDate: _rangeEnd,
      ),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (snap.hasError) {
          return Center(
            child: Text('Erreur: ${snap.error}',
                style: const TextStyle(color: AppColors.error)),
          );
        }

        final all = snap.data ?? [];
        final absences = _filterByClass(all);
        _visibleAbsences = absences; // read by the export button

        // ── Period stats ───────────────────────────────────────────────────
        final total = absences.length;
        final byType = <AbsenceType, int>{};
        for (final a in absences) {
          byType[a.type] = (byType[a.type] ?? 0) + 1;
        }

        // Group by day
        final byDate = <DateTime, List<AbsenceModel>>{};
        for (final a in absences) {
          byDate.putIfAbsent(a.normalizedDate, () => []).add(a);
        }
        final sortedDates = byDate.keys.toList()
          ..sort((a, b) => b.compareTo(a));

        // Group by class (used when _groupMode == byClass)
        final byClass = <String, List<AbsenceModel>>{};
        final classById = <String, ClassModel?>{};
        for (final a in absences) {
          final c = _classOf(a.studentId);
          final key = c?.id ?? '_none';
          classById[key] = c;
          byClass.putIfAbsent(key, () => []).add(a);
        }
        final classKeys = byClass.keys.toList()
          ..sort((a, b) {
            if (a == '_none') return 1;
            if (b == '_none') return -1;
            return classById[a]!.name.compareTo(classById[b]!.name);
          });

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            // ── Period summary stats ─────────────────────────────────────
            _PeriodStatsRow(
              total: total,
              byType: byType,
              periodLabel: _isToday ? context.tr('common.today') : _periodLabel,
              className: _selectedClass?.name,
            ),

            const SizedBox(height: 14),

            // ── Quick "Faire l'appel" buttons ────────────────────────────
            if (_mode == _PeriodMode.day && _classes.isNotEmpty) ...[
              _SectionLabel(
                icon: Icons.add_task_rounded,
                label: context.tr('abs.takeAttendance'),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: (_selectedClass != null
                          ? [_selectedClass!]
                          : _classes)
                      .map((c) => Padding(
                            padding:
                                const EdgeInsets.only(right: 8),
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _openAttendance(c),
                              icon: const Icon(
                                  Icons.class_outlined,
                                  size: 14),
                              label: Text(c.name,
                                  style: const TextStyle(
                                      fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(
                                    color: AppColors.primary),
                                minimumSize:
                                    const Size(0, 34),
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(
                                            8)),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Absence list grouped by day ──────────────────────────────
            if (absences.isEmpty)
              _EmptyAbsences(
                periodLabel: _isToday
                    ? "${context.tr('common.today')} (${_fmtFull(_anchor)})"
                    : _periodLabel,
              )
            else ...[
              _SectionLabel(
                icon: Icons.event_busy_outlined,
                label:
                    context.tr('abs.recorded', args: {'n': total}),
              ),
              const SizedBox(height: 10),
              if (_groupMode == _GroupMode.byDay)
                ...sortedDates.map((date) => _DayGroup(
                      date: date,
                      absences: byDate[date]!,
                      fmtDate: _fmtFull,
                    ))
              else
                ...classKeys.map((k) => _ClassGroup(
                      cls: classById[k],
                      absences: byClass[k]!,
                      showRatio: _mode == _PeriodMode.day,
                      fmtDate: _fmtShort,
                    )),
            ],
          ],
        );
      },
    );
  }
}

// ─── Today global stats bar ───────────────────────────────────────────────────

class _TodayStatsBar extends StatelessWidget {
  final AbsenceService absenceService;
  final List<ClassModel> classes;

  const _TodayStatsBar(
      {required this.absenceService, required this.classes});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today =
        DateTime(now.year, now.month, now.day);

    return StreamBuilder<List<AbsenceModel>>(
      stream: absenceService.streamAbsencesByDateRange(
          startDate: today, endDate: today),
      builder: (context, snap) {
        final absences = snap.data ?? [];
        final total = absences.length;
        final excused =
            absences.where((a) => a.type == AbsenceType.excused).length;
        final unexcused =
            absences.where((a) => a.type == AbsenceType.unexcused).length;
        final sick =
            absences.where((a) => a.type == AbsenceType.sick).length;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, Color(0xFF4A6FA5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.today_outlined,
                    color: Colors.white70, size: 14),
                const SizedBox(width: 6),
                Text(context.tr('common.today'),
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
                const Spacer(),
                if (snap.connectionState == ConnectionState.waiting)
                  const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: Colors.white54)),
              ]),
              const SizedBox(height: 8),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                _TodayStat(
                  value: total.toString(),
                  label: 'Total',
                  color: Colors.white,
                ),
                _TodayStat(
                  value: unexcused.toString(),
                  label: 'Non just.',
                  color: const Color(0xFFFFADAD),
                ),
                _TodayStat(
                  value: excused.toString(),
                  label: 'Justifiée',
                  color: const Color(0xFF90F0B0),
                ),
                _TodayStat(
                  value: sick.toString(),
                  label: 'Maladie',
                  color: const Color(0xFFFFDC82),
                ),
              ]),
            ],
          ),
        );
      },
    );
  }
}

class _TodayStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _TodayStat(
      {required this.value,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value,
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color)),
      Text(label,
          style:
              TextStyle(fontSize: 10, color: color.withAlpha(200))),
    ]);
  }
}

// ─── Period stats row ─────────────────────────────────────────────────────────

class _PeriodStatsRow extends StatelessWidget {
  final int total;
  final Map<AbsenceType, int> byType;
  final String periodLabel;
  final String? className;

  const _PeriodStatsRow({
    required this.total,
    required this.byType,
    required this.periodLabel,
    this.className,
  });

  @override
  Widget build(BuildContext context) {
    Color typeColor(AbsenceType t) {
      switch (t) {
        case AbsenceType.excused:    return AppColors.absenceExcused;
        case AbsenceType.unexcused:  return AppColors.absenceUnexcused;
        case AbsenceType.sick:       return AppColors.absenceSick;
        case AbsenceType.authorized: return AppColors.absenceAuthorized;
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.divider),
        boxShadow: context.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(
              periodLabel,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.brand),
            ),
            if (className != null) ...[
              Text(' · ', style: TextStyle(color: context.textSecondary)),
              Text(className!,
                  style: TextStyle(
                      fontSize: 12, color: context.textSecondary)),
            ],
          ]),
          const SizedBox(height: 10),
          Row(children: [
            // Total
            Expanded(
              child: _MiniStat(
                icon: Icons.event_busy_outlined,
                label: 'Total',
                value: total.toString(),
                color: AppColors.primary,
              ),
            ),
            ...AbsenceType.values.map((t) => Expanded(
                  child: _MiniStat(
                    icon: _typeIcon(t),
                    label: context.tr('abs.type.${t.name}'),
                    value: (byType[t] ?? 0).toString(),
                    color: typeColor(t),
                  ),
                )),
          ]),
        ],
      ),
    );
  }

  IconData _typeIcon(AbsenceType t) {
    switch (t) {
      case AbsenceType.excused:    return Icons.check_circle_outline;
      case AbsenceType.unexcused:  return Icons.cancel_outlined;
      case AbsenceType.sick:       return Icons.healing_outlined;
      case AbsenceType.authorized: return Icons.description_outlined;
    }
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(height: 4),
      Text(value,
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color)),
      Text(label,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 9,
              color: context.textSecondary)),
    ]);
  }
}

// ─── Day group ────────────────────────────────────────────────────────────────

class _DayGroup extends StatelessWidget {
  final DateTime date;
  final List<AbsenceModel> absences;
  final String Function(DateTime) fmtDate;

  const _DayGroup({
    required this.date,
    required this.absences,
    required this.fmtDate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day header
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: AppColors.primary.withAlpha(30)),
          ),
          child: Row(children: [
            Icon(Icons.calendar_today_outlined,
                size: 13, color: context.brand),
            const SizedBox(width: 8),
            Text(fmtDate(date),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
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

        // Absence cards
        ...absences.map((a) => _AbsenceCard(absence: a)),

        const SizedBox(height: 14),
      ],
    );
  }
}

// ─── Class group (absences of one class) ──────────────────────────────────────

class _ClassGroup extends StatelessWidget {
  final ClassModel? cls; // null = students without class
  final List<AbsenceModel> absences;
  final bool showRatio; // "3 / 12" — only meaningful for a single day
  final String Function(DateTime) fmtDate;

  const _ClassGroup({
    required this.cls,
    required this.absences,
    required this.showRatio,
    required this.fmtDate,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...absences]..sort((a, b) {
        final d = b.date.compareTo(a.date);
        return d != 0 ? d : a.studentName.compareTo(b.studentName);
      });
    final countLabel = (showRatio && cls != null)
        ? '${absences.length} / ${cls!.studentCount}'
        : '${absences.length}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withAlpha(30)),
          ),
          child: Row(children: [
            Icon(Icons.groups_2_outlined, size: 14, color: context.brand),
            const SizedBox(width: 8),
            Expanded(
              child: Text(cls?.name ?? context.tr('common.noClass'),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary)),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(countLabel,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
        // The date is shown on each card: a class view can span several days.
        ...sorted.map((a) =>
            _AbsenceCard(absence: a, dateLabel: fmtDate(a.date))),
        const SizedBox(height: 14),
      ],
    );
  }
}

// ─── Absence card ─────────────────────────────────────────────────────────────

class _AbsenceCard extends StatelessWidget {
  final AbsenceModel absence;
  final String? dateLabel; // shown only in the per-class view
  const _AbsenceCard({required this.absence, this.dateLabel});

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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.divider),
        boxShadow: context.softShadow,
      ),
      child: Row(children: [
        Container(
          width: 4,
          height: 42,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(absence.type.emoji,
            style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(absence.studentName,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary)),
            if (absence.reason != null &&
                absence.reason!.isNotEmpty)
              Text(absence.reason!,
                  style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: context.textSecondary)),
            Text(
                dateLabel == null
                    ? context.tr('abs.by', args: {'name': absence.recordedByName})
                    : '$dateLabel · ${context.tr('abs.by', args: {'name': absence.recordedByName})}',
                style: TextStyle(
                    fontSize: 11,
                    color: context.textSecondary)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withAlpha(22),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withAlpha(60)),
          ),
          child: Text(context.tr('abs.type.${absence.type.name}'),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ),
      ]),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 15, color: context.brand),
      const SizedBox(width: 6),
      Text(label,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: context.textPrimary)),
    ]);
  }
}

// ─── Class filter chip ────────────────────────────────────────────────────────

class _ClassFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ClassFilterChip(
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
          color: selected ? AppColors.primary : context.softFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.primary : context.divider),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color:
                    selected ? Colors.white : context.textSecondary)),
      ),
    );
  }
}

// ─── Nav button ───────────────────────────────────────────────────────────────

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
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

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyAbsences extends StatelessWidget {
  final String periodLabel;
  const _EmptyAbsences({required this.periodLabel});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 48),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.event_available_outlined,
              size: 64,
              color: context.textSecondary.withAlpha(80)),
          const SizedBox(height: 14),
          Text(context.tr('abs.none'),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary)),
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
