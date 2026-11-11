import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/absence_model.dart';
import '../../models/class_model.dart';
import '../../models/student_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/absence_service.dart';
import '../../services/user_service.dart';
import '../../widgets/user_avatar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Scénario 2 — ClassAttendanceScreen (écran partagé)
//
// - Les étudiants déjà enregistrés ce jour sont affichés avec leur statut
//   réel (présent/absent) et sont MODIFIABLES.
// - Les étudiants non encore enregistrés peuvent être marqués présent/absent.
// - Une seule barre "Enregistrer" pour les nouvelles absences.
// - Les modifications d'absences existantes sont sauvegardées immédiatement.
// ─────────────────────────────────────────────────────────────────────────────

enum _AttStatus { present, absent }

class ClassAttendanceScreen extends StatefulWidget {
  final ClassModel cls;
  final DateTime? initialDate;

  const ClassAttendanceScreen({
    super.key,
    required this.cls,
    this.initialDate,
  });

  @override
  State<ClassAttendanceScreen> createState() =>
      _ClassAttendanceScreenState();
}

class _ClassAttendanceScreenState extends State<ClassAttendanceScreen> {
  final _absenceService = AbsenceService();
  final _userService = UserService();

  late DateTime _date;

  // ── État de chaque étudiant ─────────────────────────────────────────────
  // Pour TOUS les étudiants (nouveaux + déjà enregistrés)
  final Map<String, _AttStatus> _statusMap = {};
  final Map<String, AbsenceType> _typeMap = {};
  final Map<String, String> _reasonMap = {};

  // Absences déjà enregistrées ce jour : uid → AbsenceModel
  final Map<String, AbsenceModel> _existingAbsences = {};

  List<StudentModel> _students = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate ?? DateTime.now();
    _loadStudents();
  }

  // ── Chargement ─────────────────────────────────────────────────────────────

  Future<void> _loadStudents() async {
    if (widget.cls.studentIds.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    final results = await Future.wait(
      widget.cls.studentIds.map((id) => _userService.getUserById(id)),
    );

    final students = results
        .whereType<UserModel>()
        .where((u) => u.role == UserRole.student)
        .map((u) => StudentModel(
              uid: u.uid,
              firstName: u.firstName,
              lastName: u.lastName,
              classId: widget.cls.id,
              className: widget.cls.name,
              createdAt: u.createdAt,
              enrolledAt: u.enrollmentDate ?? u.createdAt,
              email: u.email,
              profileImageUrl: u.profileImageUrl,
              gender: u.gender,
            ))
        .toList()
      ..sort((a, b) => a.lastName.compareTo(b.lastName));

    // Initialiser tous les étudiants à "présent" par défaut
    for (final s in students) {
      _statusMap[s.uid] = _AttStatus.present;
      _typeMap[s.uid] = AbsenceType.unexcused;
    }

    setState(() {
      _students = students;
      _loading = false;
    });

    await _loadExistingAbsences();
  }

  /// Charge les absences déjà enregistrées ce jour et met à jour les maps
  Future<void> _loadExistingAbsences() async {
    _existingAbsences.clear();
    for (final s in _students) {
      final existing = await _absenceService.getAbsenceByStudentAndDate(
        studentId: s.uid,
        date: _date,
      );
      if (existing != null) {
        _existingAbsences[s.uid] = existing;
        // Pré-remplir avec les données existantes
        _statusMap[s.uid] = _AttStatus.absent;
        _typeMap[s.uid] = existing.type;
        if (existing.reason != null) {
          _reasonMap[s.uid] = existing.reason!;
        }
      } else {
        // Pas d'absence enregistrée → présent par défaut
        _statusMap[s.uid] = _AttStatus.present;
        _typeMap[s.uid] = AbsenceType.unexcused;
        _reasonMap.remove(s.uid);
      }
    }
    if (mounted) setState(() {});
  }

  // ── Compteurs ──────────────────────────────────────────────────────────────

  int get _absentCount =>
      _statusMap.values.where((v) => v == _AttStatus.absent).length;

  int get _presentCount =>
      _statusMap.values.where((v) => v == _AttStatus.present).length;

  /// Nouveaux absents (pas encore enregistrés)
  List<StudentModel> get _newAbsentStudents => _students
      .where((s) =>
          _statusMap[s.uid] == _AttStatus.absent &&
          !_existingAbsences.containsKey(s.uid))
      .toList();

  /// Absences modifiées (type ou raison changés)
  List<StudentModel> get _modifiedStudents => _students.where((s) {
        final existing = _existingAbsences[s.uid];
        if (existing == null) return false;
        final currentStatus = _statusMap[s.uid];
        // Passage de absent → présent (suppression)
        if (currentStatus == _AttStatus.present) return true;
        // Changement de type ou raison
        return existing.type != _typeMap[s.uid] ||
            existing.reason != (_reasonMap[s.uid]);
      }).toList();

  bool get _hasChanges =>
      _newAbsentStudents.isNotEmpty || _modifiedStudents.isNotEmpty;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _students.isEmpty
              ? const _EmptyState(
                  icon: Icons.people_outline,
                  message: 'Aucun étudiant dans cette classe',
                )
              : Column(
                  children: [
                    _buildDateBar(),
                    _buildMarkAllBar(),
                    if (_existingAbsences.isNotEmpty)
                      _buildExistingBanner(),
                    Expanded(child: _buildStudentList()),
                    if (_hasChanges) _buildSaveBar(),
                  ],
                ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    final colorScheme = Theme.of(context).colorScheme;
    return AppBar(
      title: Text('Appel — ${widget.cls.name}'),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(40),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              _CountPill(
                label: 'Présents',
                count: _presentCount,
                color: AppColors.success,
              ),
              const SizedBox(width: 12),
              _CountPill(
                label: 'Absents',
                count: _absentCount,
                color: AppColors.error,
              ),
              const SizedBox(width: 12),
              _CountPill(
                label: 'Total',
                count: _students.length,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Date bar ───────────────────────────────────────────────────────────────

  Widget _buildDateBar() {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        color: colorScheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withAlpha(15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.calendar_today,
                color: colorScheme.primary, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _formatDate(_date),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface),
            ),
          ),
          Icon(Icons.edit_calendar_outlined,
              size: 18, color: colorScheme.primary),
          const SizedBox(width: 4),
          Text('Changer',
              style:
                  TextStyle(fontSize: 13, color: colorScheme.primary)),
        ]),
      ),
    );
  }

  // ── Mark-all bar ───────────────────────────────────────────────────────────

  Widget _buildMarkAllBar() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Text('Marquer tous :',
              style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant)),
          const SizedBox(width: 12),
          _ToggleChip(
            label: 'Tous présents',
            icon: Icons.check_circle,
            color: AppColors.success,
            onTap: _markAllPresent,
          ),
          const SizedBox(width: 8),
          _ToggleChip(
            label: 'Tous absents',
            icon: Icons.cancel,
            color: AppColors.error,
            onTap: _markAllAbsent,
          ),
        ],
      ),
    );
  }

  // ── Banner absences existantes ─────────────────────────────────────────────

  Widget _buildExistingBanner() {
    final n = _existingAbsences.length;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.info.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.info.withAlpha(60)),
      ),
      child: Row(children: [
        const Icon(Icons.edit_note_rounded,
            color: AppColors.info, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$n absence${n > 1 ? 's' : ''} déjà enregistrée${n > 1 ? 's' : ''} ce jour — modifiables',
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
      ]),
    );
  }

  // ── Liste des étudiants ────────────────────────────────────────────────────

  Widget _buildStudentList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: _students.length,
      itemBuilder: (_, i) => _buildStudentCard(_students[i]),
    );
  }

  Widget _buildStudentCard(StudentModel student) {
    final isAbsent =
        _statusMap[student.uid] == _AttStatus.absent;
    final isExisting = _existingAbsences.containsKey(student.uid);

    return _StudentAttCard(
      key: ValueKey('${student.uid}_${_date.millisecondsSinceEpoch}'),
      student: student,
      isAbsent: isAbsent,
      isExisting: isExisting,
      absenceType: _typeMap[student.uid] ?? AbsenceType.unexcused,
      onTap: () {
        setState(() {
          _statusMap[student.uid] =
              isAbsent ? _AttStatus.present : _AttStatus.absent;
        });
        // Si on vient de marquer absent → ouvrir le sheet de type
        if (!isAbsent) {
          Future.delayed(const Duration(milliseconds: 150), () {
            if (mounted) _openTypeSheet(student);
          });
        }
      },
      onTypeTap: () => _openTypeSheet(student),
    );
  }

  // ── Barre de sauvegarde ────────────────────────────────────────────────────

  Widget _buildSaveBar() {
    final colorScheme = Theme.of(context).colorScheme;
    final newCount = _newAbsentStudents.length;
    final modCount = _modifiedStudents.length;

    String label = '';
    if (newCount > 0 && modCount > 0) {
      label =
          '$newCount nouvelle${newCount > 1 ? 's' : ''}, $modCount modif.';
    } else if (newCount > 0) {
      label =
          '$newCount nouvelle${newCount > 1 ? 's' : ''} absence${newCount > 1 ? 's' : ''}';
    } else {
      label =
          '$modCount modification${modCount > 1 ? 's' : ''}';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(15),
              blurRadius: 16,
              offset: const Offset(0, -4)),
        ],
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface)),
              Text('le ${_formatDate(_date)}',
                  style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: _saving ? null : _saveAll,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_rounded, size: 18),
          label: Text(_saving ? 'Enregistrement…' : 'Confirmer'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            minimumSize: const Size(140, 46),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ]),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _markAllPresent() => setState(() {
        for (final s in _students) {
          _statusMap[s.uid] = _AttStatus.present;
        }
      });

  void _markAllAbsent() => setState(() {
        for (final s in _students) {
          _statusMap[s.uid] = _AttStatus.absent;
        }
      });

  void _openTypeSheet(StudentModel student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AbsenceTypeSheet(
        studentName: student.fullName,
        currentType: _typeMap[student.uid] ?? AbsenceType.unexcused,
        currentReason: _reasonMap[student.uid],
        onSave: (type, reason) {
          setState(() {
            _typeMap[student.uid] = type;
            if (reason != null && reason.trim().isNotEmpty) {
              _reasonMap[student.uid] = reason.trim();
            } else {
              _reasonMap.remove(student.uid);
            }
          });
        },
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _date) {
      setState(() {
        _date = picked;
        _existingAbsences.clear();
        for (final s in _students) {
          _statusMap[s.uid] = _AttStatus.present;
          _typeMap[s.uid] = AbsenceType.unexcused;
        }
        _reasonMap.clear();
        _loading = true;
      });
      await _loadExistingAbsences();
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveAll() async {
    setState(() => _saving = true);
    final me = context.read<AuthProvider>().currentUser!;
    int saved = 0;
    int modified = 0;
    int deleted = 0;
    final errors = <String>[];

    // 1. Enregistrer les nouvelles absences
    for (final student in _newAbsentStudents) {
      try {
        await _absenceService.recordAbsence(
          studentId: student.uid,
          studentName: student.fullName,
          date: _date,
          type: _typeMap[student.uid] ?? AbsenceType.unexcused,
          reason: _reasonMap[student.uid],
          recordedById: me.uid,
          recordedByName: me.fullName,
          recordedByRole: me.role,
        );
        saved++;
      } catch (_) {
        errors.add(student.fullName);
      }
    }

    // 2. Mettre à jour / supprimer les absences existantes modifiées
    for (final student in _modifiedStudents) {
      final existing = _existingAbsences[student.uid]!;
      try {
        if (_statusMap[student.uid] == _AttStatus.present) {
          // Passage à présent → supprimer l'absence (correction d'appel)
          await _absenceService.forceDeleteAbsence(existing.id);
          deleted++;
        } else {
          // Modification du type/raison
          await _absenceService.updateAbsence(
            absenceId: existing.id,
            type: _typeMap[student.uid],
            reason: _reasonMap[student.uid],
            updatedByRole: me.role,
          );
          modified++;
        }
      } catch (_) {
        errors.add(student.fullName);
      }
    }

    if (!mounted) return;
    setState(() => _saving = false);

    // Recharger les absences existantes après sauvegarde
    await _loadExistingAbsences();

    if (!mounted) return;

    final parts = <String>[];
    if (saved > 0) parts.add('$saved enregistrée${saved > 1 ? 's' : ''}');
    if (modified > 0) parts.add('$modified modifiée${modified > 1 ? 's' : ''}');
    if (deleted > 0) parts.add('$deleted supprimée${deleted > 1 ? 's' : ''}');
    if (errors.isNotEmpty) parts.add('erreur : ${errors.join(', ')}');

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(parts.join(' • ')),
      backgroundColor: errors.isEmpty ? AppColors.success : AppColors.warning,
    ));

    // Retour à la page précédente (liste des classes / étudiants)
    // seulement si l'enregistrement a réussi sans erreurs
    if (errors.isEmpty && (saved > 0 || modified > 0 || deleted > 0)) {
      Navigator.of(context).pop();
    }
  }

  String _formatDate(DateTime d) {
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StudentAttCard extends StatelessWidget {
  final StudentModel student;
  final bool isAbsent;
  final bool isExisting; // absence déjà enregistrée ce jour
  final AbsenceType absenceType;
  final VoidCallback onTap;
  final VoidCallback onTypeTap;

  const _StudentAttCard({
    super.key,
    required this.student,
    required this.isAbsent,
    required this.isExisting,
    required this.absenceType,
    required this.onTap,
    required this.onTypeTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isAbsent
            ? AppColors.error.withAlpha(18)
            : AppColors.success.withAlpha(14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAbsent
              ? AppColors.error.withAlpha(120)
              : AppColors.success.withAlpha(100),
          width: isAbsent ? 1.5 : 1,
        ),
      ),
      child: Row(children: [
        // Avatar
        UserAvatar(user: student, radius: 20),
        const SizedBox(width: 10),
        // Nom + indicateur existant + type si absent
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(
                  child: Text(
                    student.fullName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Badge "modifiable" si déjà enregistré
                if (isExisting) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.info.withAlpha(20),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('modif.',
                        style: TextStyle(
                            fontSize: 9,
                            color: AppColors.info,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ]),
              if (isAbsent)
                GestureDetector(
                  onTap: onTypeTap,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(absenceType.emoji,
                          style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          absenceType.label,
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.error.withAlpha(200)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.edit_outlined,
                          size: 11,
                          color: AppColors.error.withAlpha(160)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        // ── Boutons Présent / Absent ──────────────────────────────────
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bouton PRÉSENT
            Tooltip(
              message: 'Présent',
              child: GestureDetector(
                onTap: isAbsent ? onTap : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: !isAbsent
                        ? AppColors.success
                        : AppColors.success.withAlpha(20),
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(10)),
                    border: Border.all(
                        color: AppColors.success.withAlpha(80)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded,
                          size: 13,
                          color: !isAbsent
                              ? Colors.white
                              : AppColors.success),
                      const SizedBox(width: 3),
                      Text('Présent',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: !isAbsent
                                ? Colors.white
                                : AppColors.success,
                          )),
                    ],
                  ),
                ),
              ),
            ),
            // Bouton ABSENT
            Tooltip(
              message: 'Absent',
              child: GestureDetector(
                onTap: !isAbsent ? onTap : onTypeTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isAbsent
                        ? AppColors.error
                        : AppColors.error.withAlpha(20),
                    borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(10)),
                    border: Border.all(
                        color: AppColors.error.withAlpha(80)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close_rounded,
                          size: 13,
                          color: isAbsent
                              ? Colors.white
                              : AppColors.error),
                      const SizedBox(width: 3),
                      Text('Absent',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isAbsent
                                ? Colors.white
                                : AppColors.error,
                          )),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ]),
    );
  }
}

// ─── Bottom sheet : type d'absence + raison ───────────────────────────────────

class _AbsenceTypeSheet extends StatefulWidget {
  final String studentName;
  final AbsenceType currentType;
  final String? currentReason;
  final void Function(AbsenceType, String?) onSave;

  const _AbsenceTypeSheet({
    required this.studentName,
    required this.currentType,
    required this.onSave,
    this.currentReason,
  });

  @override
  State<_AbsenceTypeSheet> createState() => _AbsenceTypeSheetState();
}

class _AbsenceTypeSheetState extends State<_AbsenceTypeSheet> {
  late AbsenceType _type;
  late TextEditingController _reasonCtrl;

  @override
  void initState() {
    super.initState();
    _type = widget.currentType;
    _reasonCtrl = TextEditingController(text: widget.currentReason ?? '');
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: colorScheme.outline,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 18),
            Row(children: [
              const Icon(Icons.event_busy, color: AppColors.error, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.studentName,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface)),
              ),
            ]),
            const SizedBox(height: 4),
            Text('Type d\'absence',
                style: TextStyle(
                    fontSize: 13, color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AbsenceType.values.map((t) {
                final selected = _type == t;
                final color = _typeColor(t);
                return GestureDetector(
                  onTap: () => setState(() => _type = t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? color
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: selected ? color : colorScheme.outline,
                        width: 1.5,
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(t.emoji,
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(t.label,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white
                                  : colorScheme.onSurface)),
                    ]),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _reasonCtrl,
              maxLines: 2,
              style: TextStyle(
                  fontSize: 14, color: colorScheme.onSurface),
              decoration: const InputDecoration(
                labelText: 'Raison (optionnel)',
                hintText: 'Ex : rendez-vous médical…',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  widget.onSave(
                    _type,
                    _reasonCtrl.text.trim().isEmpty
                        ? null
                        : _reasonCtrl.text.trim(),
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Confirmer',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Pill compteur ────────────────────────────────────────────────────────────

class _CountPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _CountPill(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$count',
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: color)),
    ]);
  }
}

// ─── Toggle chip ─────────────────────────────────────────────────────────────

class _ToggleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ToggleChip(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withAlpha(18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ]),
      ),
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                    height: 1.5)),
          ],
        ),
      ),
    );
  }
}
