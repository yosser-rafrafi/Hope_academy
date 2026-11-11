import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/absence_model.dart';
import '../../models/student_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/absence_service.dart';
import '../../widgets/user_avatar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Scénario 3 — StudentDetailAbsenceScreen
//
// Accessible depuis :
//   • UserDetailsScreen   (Admin / SubAdmin / Teacher → bouton "Enregistrer")
//   • MyStudentsScreen    (Teacher → icône absence sur la carte étudiant)
//
// Affiche :
//   • En-tête étudiant
//   • Historique des absences (stream temps réel, filtres année/mois)
//   • Bouton flottant "Enregistrer une absence" → _RecordSheet (bottom sheet)
// ─────────────────────────────────────────────────────────────────────────────

class StudentDetailAbsenceScreen extends StatefulWidget {
  /// Passer soit un [StudentModel] (complet) soit un [UserModel] avec
  /// role == student (les infos manquantes seront ignorées gracieusement).
  final UserModel student;

  const StudentDetailAbsenceScreen({super.key, required this.student});

  @override
  State<StudentDetailAbsenceScreen> createState() =>
      _StudentDetailAbsenceScreenState();
}

class _StudentDetailAbsenceScreenState
    extends State<StudentDetailAbsenceScreen> {
  final _absenceService = AbsenceService();

  int _selectedYear = DateTime.now().year;
  int? _selectedMonth;

  static const _months = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];

  // ── Permissions ────────────────────────────────────────────────────────────

  bool get _canRecord {
    final role =
        context.read<AuthProvider>().currentUser?.role;
    return role == UserRole.admin ||
        role == UserRole.subAdmin ||
        role == UserRole.teacher;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String get _className =>
      widget.student is StudentModel
          ? (widget.student as StudentModel).className
          : widget.student.group ?? '';

  DateTime get _startDate => _selectedMonth != null
      ? DateTime(_selectedYear, _selectedMonth!, 1)
      : DateTime(_selectedYear, 1, 1);

  DateTime get _endDate => _selectedMonth != null
      ? DateTime(_selectedYear, _selectedMonth! + 1, 0)
      : DateTime(_selectedYear, 12, 31);

  String _fmtPeriod() => _selectedMonth != null
      ? '${_months[_selectedMonth! - 1]} $_selectedYear'
      : 'Année $_selectedYear';

  String _fmtDate(DateTime d) {
    const short = [
      'Jan', 'Fév', 'Mars', 'Avr', 'Mai', 'Juin',
      'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc',
    ];
    return '${d.day} ${short[d.month - 1]} ${d.year}';
  }

  Color _typeColor(AbsenceType t) {
    switch (t) {
      case AbsenceType.excused:
        return AppColors.absenceExcused;
      case AbsenceType.unexcused:
        return AppColors.absenceUnexcused;
      case AbsenceType.sick:
        return AppColors.absenceSick;
      case AbsenceType.authorized:
        return AppColors.absenceAuthorized;
    }
  }

  // ── Open record sheet ──────────────────────────────────────────────────────

  void _openRecordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _RecordAbsenceSheet(student: widget.student),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        title: Text('Absences — ${widget.student.firstName}'),
      ),
      floatingActionButton: _canRecord
          ? FloatingActionButton.extended(
              onPressed: _openRecordSheet,
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_task_rounded),
              label: const Text('Enregistrer',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
      body: Column(
        children: [
          _buildStudentHeader(),
          _buildFilters(),
          _buildStatsSummary(),
          Expanded(child: _buildAbsencesList()),
        ],
      ),
    );
  }

  // ── En-tête étudiant ───────────────────────────────────────────────────────

  Widget _buildStudentHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: context.cardBg,
      child: Row(
        children: [
          UserAvatar(user: widget.student, radius: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.student.fullName,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                if (_className.isNotEmpty)
                  Text(
                    'Classe : $_className',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade600),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Filtres ────────────────────────────────────────────────────────────────

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: context.cardBg,
      child: Row(
        children: [
          // Filtre année
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: _selectedYear,
              decoration: InputDecoration(
                labelText: 'Année',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
              ),
              items: List.generate(5, (i) => DateTime.now().year - i)
                  .map((y) => DropdownMenuItem(
                      value: y, child: Text(y.toString())))
                  .toList(),
              onChanged: (val) =>
                  setState(() => _selectedYear = val!),
            ),
          ),
          const SizedBox(width: 12),
          // Filtre mois
          Expanded(
            child: DropdownButtonFormField<int?>(
              initialValue: _selectedMonth,
              decoration: InputDecoration(
                labelText: 'Mois',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
              ),
              items: [
                const DropdownMenuItem<int?>(
                    value: null, child: Text('Tous')),
                ...List.generate(12, (i) => i + 1).map(
                  (m) => DropdownMenuItem(
                      value: m, child: Text(_months[m - 1])),
                ),
              ],
              onChanged: (val) =>
                  setState(() => _selectedMonth = val),
            ),
          ),
        ],
      ),
    );
  }

  // ── Résumé statistiques ────────────────────────────────────────────────────

  Widget _buildStatsSummary() {
    return FutureBuilder<Map<AbsenceType, int>>(
      future: _absenceService.getAbsenceStatsByType(
        studentId: widget.student.uid,
        startDate: _startDate,
        endDate: _endDate,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
              height: 60,
              child: Center(
                  child:
                      CircularProgressIndicator(strokeWidth: 2)));
        }

        final stats = snapshot.data!;
        final total = stats.values.fold(0, (a, b) => a + b);

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Absences — ${_fmtPeriod()}',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          AppColors.error.withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Total : $total',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.error),
                    ),
                  ),
                ],
              ),
              if (stats.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: stats.entries
                      .where((e) => e.value > 0)
                      .map((entry) {
                    final color = _typeColor(entry.key);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withAlpha(18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: color.withAlpha(60)),
                      ),
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(entry.key.emoji,
                                style: const TextStyle(
                                    fontSize: 14)),
                            const SizedBox(width: 4),
                            Text(
                              '${entry.key.label} : ${entry.value}',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: color),
                            ),
                          ]),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ── Liste des absences ─────────────────────────────────────────────────────

  Widget _buildAbsencesList() {
    return StreamBuilder<List<AbsenceModel>>(
      stream: _absenceService.streamAbsencesByDateRange(
        startDate: _startDate,
        endDate: _endDate,
        studentId: widget.student.uid,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 64,
                      color: AppColors.success.withAlpha(80)),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune absence enregistrée\npour ${_fmtPeriod()}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 14,
                        color: context.textSecondary,
                        height: 1.5),
                  ),
                ],
              ),
            ),
          );
        }

        final absences = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: absences.length,
          itemBuilder: (context, index) =>
              _buildAbsenceItem(absences[index]),
        );
      },
    );
  }

  Widget _buildAbsenceItem(AbsenceModel absence) {
    final color = _typeColor(absence.type);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          // Barre colorée
          Container(
            width: 4,
            height: 52,
            decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(absence.type.emoji,
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    absence.type.label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: color),
                  ),
                  const Spacer(),
                  Text(
                    _fmtDate(absence.date),
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600),
                  ),
                ]),
                if (absence.reason != null &&
                    absence.reason!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    absence.reason!,
                    style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade700),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'Enregistré par ${absence.recordedByName}',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RecordAbsenceSheet — Bottom sheet d'enregistrement d'absence individuelle
// ─────────────────────────────────────────────────────────────────────────────

class _RecordAbsenceSheet extends StatefulWidget {
  final UserModel student;
  const _RecordAbsenceSheet({required this.student});

  @override
  State<_RecordAbsenceSheet> createState() =>
      _RecordAbsenceSheetState();
}

class _RecordAbsenceSheetState extends State<_RecordAbsenceSheet> {
  final _absenceService = AbsenceService();

  DateTime _date = DateTime.now();
  AbsenceType _type = AbsenceType.unexcused;
  final _reasonCtrl = TextEditingController();

  bool _saving = false;
  bool _alreadyAbsent = false;
  bool _checkingDate = false;

  @override
  void initState() {
    super.initState();
    _checkDate();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  // ── Vérifier doublon ───────────────────────────────────────────────────────

  Future<void> _checkDate() async {
    setState(() => _checkingDate = true);
    final existing = await _absenceService.getAbsenceByStudentAndDate(
      studentId: widget.student.uid,
      date: _date,
    );
    if (mounted) {
      setState(() {
        _alreadyAbsent = existing != null;
        _checkingDate = false;
      });
    }
  }

  // ── Sélecteur de date ──────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _date) {
      setState(() => _date = picked);
      await _checkDate();
    }
  }

  // ── Enregistrer (avec confirmation de remplacement si doublon) ─────────────

  Future<void> _save() async {
    if (_saving || _checkingDate) return;

    // Si absence déjà enregistrée → demander confirmation de remplacement
    if (_alreadyAbsent) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.swap_horiz_rounded,
                color: AppColors.warning, size: 22),
            SizedBox(width: 8),
            Text('Remplacer l\'absence ?'),
          ]),
          content: Text(
            'Une absence est déjà enregistrée pour ${widget.student.firstName} '
            'le ${_formatDate(_date)}.\n\n'
            'Voulez-vous la remplacer par cette nouvelle absence ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remplacer'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;

      // Supprimer l'ancienne absence puis créer la nouvelle
      setState(() => _saving = true);
      try {
        final existing =
            await _absenceService.getAbsenceByStudentAndDate(
          studentId: widget.student.uid,
          date: _date,
        );
        if (existing != null) {
          // Suppression directe Firestore (correction d'appel)
          await _absenceService.forceDeleteAbsence(existing.id);
        }
      } catch (_) {
        // Si suppression échoue, on continue quand même
      }
    } else {
      setState(() => _saving = true);
    }

    final me = context.read<AuthProvider>().currentUser!;

    try {
      await _absenceService.recordAbsence(
        studentId: widget.student.uid,
        studentName: widget.student.fullName,
        date: _date,
        type: _type,
        reason: _reasonCtrl.text.trim().isEmpty
            ? null
            : _reasonCtrl.text.trim(),
        recordedById: me.uid,
        recordedByName: me.fullName,
        recordedByRole: me.role,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_alreadyAbsent
              ? 'Absence remplacée ✓'
              : 'Absence enregistrée ✓'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur : ${e.toString()}'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _formatDate(DateTime d) {
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Color _typeColor(AbsenceType t) {
    switch (t) {
      case AbsenceType.excused:
        return AppColors.absenceExcused;
      case AbsenceType.unexcused:
        return AppColors.absenceUnexcused;
      case AbsenceType.sick:
        return AppColors.absenceSick;
      case AbsenceType.authorized:
        return AppColors.absenceAuthorized;
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 32,
            ),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: colorScheme.outline,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),

              // Titre
              Row(children: [
                const Icon(Icons.add_task_rounded,
                    color: AppColors.error, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Enregistrer une absence',
                  style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold),
                ),
              ]),
              const SizedBox(height: 20),

              // Carte étudiant
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colorScheme.outline),
                ),
                child: Row(children: [
                  UserAvatar(user: widget.student, radius: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.student.fullName,
                          style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold),
                        ),
                        if (widget.student.group != null &&
                            widget.student.group!.isNotEmpty)
                          Text(
                            widget.student.group!,
                            style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 24),

              // Sélecteur date
              Text(
                'Date de l\'absence',
                style: textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _alreadyAbsent
                          ? AppColors.error
                          : colorScheme.outline,
                      width: _alreadyAbsent ? 1.5 : 1,
                    ),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            colorScheme.primary.withAlpha(15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.calendar_today,
                          color: colorScheme.primary, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _formatDate(_date),
                        style: textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (_checkingDate)
                      const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2))
                    else
                      Icon(Icons.edit_calendar_outlined,
                          size: 18, color: colorScheme.primary),
                  ]),
                ),
              ),

              // Avertissement doublon — remplaçable
              if (_alreadyAbsent) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.warning.withAlpha(80)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Une absence existe déjà pour cette date. '
                        'Vous pouvez la remplacer.',
                        style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface),
                      ),
                    ),
                  ]),
                ),
              ],

              const SizedBox(height: 24),

              // Type d'absence
              Text(
                'Type d\'absence',
                style: textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: AbsenceType.values.map((t) {
                  final selected = _type == t;
                  final color = _typeColor(t);
                  return GestureDetector(
                    onTap: () => setState(() => _type = t),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: selected
                            ? color
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: selected
                              ? color
                              : colorScheme.outline,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(t.emoji,
                                style: const TextStyle(
                                    fontSize: 18)),
                            const SizedBox(width: 8),
                            Text(
                              t.label,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? Colors.white
                                      : colorScheme.onSurface),
                            ),
                          ]),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Raison
              Text(
                'Raison (optionnel)',
                style: textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _reasonCtrl,
                maxLines: 3,
                style: TextStyle(
                    fontSize: 14, color: colorScheme.onSurface),
                decoration: const InputDecoration(
                  hintText:
                      'Ex : rendez-vous médical, événement familial…',
                ),
              ),

              const SizedBox(height: 32),

              // Bouton enregistrer
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (_saving || _checkingDate)
                      ? null
                      : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white))
                      : const Text(
                          'Enregistrer l\'absence',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
