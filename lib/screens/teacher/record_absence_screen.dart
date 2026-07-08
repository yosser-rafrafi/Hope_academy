import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/absence_model.dart';
import '../../models/class_model.dart';
import '../../models/student_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/absence_service.dart';
import '../../services/class_service.dart';
import '../../services/user_service.dart';
import '../../widgets/user_avatar.dart';

// ─── Entry screen: choose a class ────────────────────────────────────────────

class RecordAbsenceScreen extends StatelessWidget {
  const RecordAbsenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentUser = auth.currentUser;

    // Teacher → only their classes; Admin/SubAdmin → all active classes
    final classStream = (currentUser?.role == UserRole.teacher)
        ? ClassService().streamByTeacher(currentUser!.uid)
        : ClassService().streamAll();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('Enregistrer les absences')),
      body: StreamBuilder<List<ClassModel>>(
        stream: classStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final classes = snap.data ?? [];

          if (classes.isEmpty) {
            return _EmptyState(
              icon: Icons.class_outlined,
              message: currentUser?.role == UserRole.teacher
                  ? 'Aucune classe ne vous est assignée'
                  : 'Aucune classe active',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: classes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) =>
                _ClassTile(cls: classes[i]),
          );
        },
      ),
    );
  }
}

// ─── Class tile (step 1) ──────────────────────────────────────────────────────

class _ClassTile extends StatelessWidget {
  final ClassModel cls;
  const _ClassTile({required this.cls});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _ClassAbsenceSheet(cls: cls),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.class_outlined,
                  color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cls.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      fontFamily: 'Georgia',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.people_outline,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${cls.studentCount} étudiant${cls.studentCount > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontFamily: 'Georgia',
                        ),
                      ),
                      if (cls.schedule.day.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.schedule_outlined,
                            size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          cls.schedule.display,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontFamily: 'Georgia',
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ─── Step 2: mark absences for a class ───────────────────────────────────────

class _ClassAbsenceSheet extends StatefulWidget {
  final ClassModel cls;
  const _ClassAbsenceSheet({required this.cls});

  @override
  State<_ClassAbsenceSheet> createState() => _ClassAbsenceSheetState();
}

class _ClassAbsenceSheetState extends State<_ClassAbsenceSheet> {
  final _absenceService = AbsenceService();
  final _userService = UserService();

  DateTime _selectedDate = DateTime.now();

  /// studentId → AbsenceType | null (null = présent)
  final Map<String, AbsenceType?> _absenceMap = {};

  /// Raison par étudiant (optionnel)
  final Map<String, String> _reasonMap = {};

  List<StudentModel> _students = [];
  bool _loadingStudents = true;

  /// Quels étudiants sont déjà absents ce jour (chargé depuis Firestore)
  Set<String> _alreadyAbsent = {};

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    if (widget.cls.studentIds.isEmpty) {
      setState(() => _loadingStudents = false);
      return;
    }

    final futures = widget.cls.studentIds
        .map((id) => _userService.getUserById(id))
        .toList();
    final results = await Future.wait(futures);

    final students = results
        .whereType<UserModel>()
        .where((u) => u.role == UserRole.student)
        .map((u) {
          // Reconstituer en StudentModel si possible, sinon wrapper minimal
          return StudentModel(
            uid: u.uid,
            firstName: u.firstName,
            lastName: u.lastName,
            classId: '',
            className: widget.cls.name,
            createdAt: u.createdAt,
            enrolledAt: u.enrollmentDate ?? u.createdAt,
            email: u.email,
            profileImageUrl: u.profileImageUrl,
            gender: u.gender,
          );
        })
        .toList()
      ..sort((a, b) => a.lastName.compareTo(b.lastName));

    setState(() {
      _students = students;
      _loadingStudents = false;
    });

    await _checkExistingAbsences();
  }

  Future<void> _checkExistingAbsences() async {
    final already = <String>{};
    for (final s in _students) {
      final absent = await _absenceService.isStudentAbsent(
        studentId: s.uid,
        date: _selectedDate,
      );
      if (absent) already.add(s.uid);
    }
    if (mounted) setState(() => _alreadyAbsent = already);
  }

  int get _absentCount =>
      _absenceMap.values.where((v) => v != null).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(widget.cls.name),
        actions: [
          if (_absentCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _saving ? null : _saveAll,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save, color: Colors.white),
                label: Text(
                  'Enregistrer ($_absentCount)',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: _loadingStudents
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildDateHeader(),
                if (_alreadyAbsent.isNotEmpty) _buildAlreadyAbsentBanner(),
                _buildLegend(),
                Expanded(child: _buildStudentList()),
                if (_absentCount > 0) _buildBottomBar(),
              ],
            ),
    );
  }

  Widget _buildDateHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: Colors.white,
      child: Row(
        children: [
          const Icon(Icons.calendar_today,
              color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Date',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontFamily: 'Georgia',
                  ),
                ),
                Text(
                  _formatDate(_selectedDate),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontFamily: 'Georgia',
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.edit_calendar_outlined, size: 16),
            label: const Text('Changer'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlreadyAbsentBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              color: AppColors.warning, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${_alreadyAbsent.length} étudiant(s) déjà marqué(s) absent(s) ce jour — indiqués en orange.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
                fontFamily: 'Georgia',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          const Text(
            'Cochez les absents puis choisissez le type :',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontFamily: 'Georgia',
            ),
          ),
          const Spacer(),
          Text(
            '${_students.length} élève${_students.length > 1 ? 's' : ''}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
              fontFamily: 'Georgia',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentList() {
    if (_students.isEmpty) {
      return const _EmptyState(
        icon: Icons.people_outline,
        message: 'Aucun étudiant dans cette classe',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: _students.length,
      itemBuilder: (context, i) =>
          _buildStudentRow(_students[i]),
    );
  }

  Widget _buildStudentRow(StudentModel student) {
    final isAbsent = _absenceMap[student.uid] != null;
    final alreadyMarked = _alreadyAbsent.contains(student.uid);
    final selectedType = _absenceMap[student.uid];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: alreadyMarked
            ? AppColors.warning.withAlpha(15)
            : isAbsent
                ? AppColors.error.withAlpha(12)
                : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alreadyMarked
              ? AppColors.warning.withAlpha(80)
              : isAbsent
                  ? AppColors.error.withAlpha(80)
                  : AppColors.divider,
          width: isAbsent ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // ── Main row ──────────────────────────────────────────────────
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: alreadyMarked
                ? null
                : () {
                    setState(() {
                      if (isAbsent) {
                        _absenceMap.remove(student.uid);
                        _reasonMap.remove(student.uid);
                      } else {
                        _absenceMap[student.uid] = AbsenceType.unexcused;
                      }
                    });
                  },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Checkbox
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: alreadyMarked
                          ? AppColors.warning
                          : isAbsent
                              ? AppColors.error
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: alreadyMarked
                            ? AppColors.warning
                            : isAbsent
                                ? AppColors.error
                                : Colors.grey.shade400,
                        width: 2,
                      ),
                    ),
                    child: alreadyMarked
                        ? const Icon(Icons.remove,
                            size: 14, color: Colors.white)
                        : isAbsent
                            ? const Icon(Icons.close,
                                size: 14, color: Colors.white)
                            : null,
                  ),
                  const SizedBox(width: 12),

                  // Avatar
                  UserAvatar(user: student, radius: 18),
                  const SizedBox(width: 12),

                  // Name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.fullName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: alreadyMarked
                                ? AppColors.warning
                                : AppColors.textPrimary,
                            fontFamily: 'Georgia',
                          ),
                        ),
                        if (alreadyMarked)
                          const Text(
                            'Déjà marqué absent',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.warning,
                              fontFamily: 'Georgia',
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Type chips (only when selected and not already marked)
                  if (isAbsent && !alreadyMarked)
                    _TypeDropdown(
                      value: selectedType!,
                      onChanged: (t) =>
                          setState(() => _absenceMap[student.uid] = t),
                    ),
                ],
              ),
            ),
          ),

          // ── Reason row (expandable) ────────────────────────────────────
          if (isAbsent && !alreadyMarked)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: TextField(
                onChanged: (v) => _reasonMap[student.uid] = v,
                style: const TextStyle(fontSize: 13, fontFamily: 'Georgia'),
                decoration: InputDecoration(
                  hintText: 'Raison (optionnel)…',
                  hintStyle: TextStyle(
                      fontSize: 12, color: Colors.grey.shade400),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                        color: AppColors.error.withAlpha(60)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                        color: AppColors.error.withAlpha(60)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.error, width: 1.5),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_absentCount absence${_absentCount > 1 ? 's' : ''} à enregistrer',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Georgia',
                  ),
                ),
                Text(
                  'le ${_formatDate(_selectedDate)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontFamily: 'Georgia',
                  ),
                ),
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
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check, size: 18),
            label: const Text('Confirmer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              minimumSize: const Size(130, 44),
              textStyle: const TextStyle(
                fontFamily: 'Georgia',
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Actions ──────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _absenceMap.clear();
        _reasonMap.clear();
        _alreadyAbsent = {};
      });
      await _checkExistingAbsences();
    }
  }

  Future<void> _saveAll() async {
    final toSave = _absenceMap.entries
        .where((e) => e.value != null)
        .toList();

    if (toSave.isEmpty) return;

    setState(() => _saving = true);

    final auth = context.read<AuthProvider>();
    final currentUser = auth.currentUser!;

    int saved = 0;
    int skipped = 0;
    final errors = <String>[];

    for (final entry in toSave) {
      final student =
          _students.firstWhere((s) => s.uid == entry.key);
      try {
        await _absenceService.recordAbsence(
          studentId: student.uid,
          studentName: student.fullName,
          date: _selectedDate,
          type: entry.value!,
          reason: _reasonMap[student.uid]?.trim().isEmpty == true
              ? null
              : _reasonMap[student.uid],
          recordedById: currentUser.uid,
          recordedByName: currentUser.fullName,
          recordedByRole: currentUser.role,
        );
        saved++;
      } catch (e) {
        if (e.toString().contains('déjà')) {
          skipped++;
        } else {
          errors.add(student.fullName);
        }
      }
    }

    if (!mounted) return;
    setState(() => _saving = false);

    String message;
    Color bgColor;

    if (errors.isNotEmpty) {
      message =
          '$saved enregistrées, ${errors.length} erreur(s) : ${errors.join(', ')}';
      bgColor = AppColors.warning;
    } else if (skipped > 0) {
      message = '$saved enregistrées, $skipped déjà existantes';
      bgColor = AppColors.warning;
    } else {
      message =
          '$saved absence${saved > 1 ? 's' : ''} enregistrée${saved > 1 ? 's' : ''} ✓';
      bgColor = AppColors.success;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: bgColor),
    );

    if (errors.isEmpty) Navigator.of(context).pop();
  }

  String _formatDate(DateTime date) {
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

// ─── Inline type dropdown ─────────────────────────────────────────────────────

class _TypeDropdown extends StatelessWidget {
  final AbsenceType value;
  final ValueChanged<AbsenceType> onChanged;

  const _TypeDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AbsenceType>(
          value: value,
          isDense: true,
          style: const TextStyle(
            fontSize: 12,
            fontFamily: 'Georgia',
            color: AppColors.textPrimary,
          ),
          items: AbsenceType.values.map((t) {
            return DropdownMenuItem(
              value: t,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t.emoji, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(t.label,
                      style: const TextStyle(
                          fontSize: 12, fontFamily: 'Georgia')),
                ],
              ),
            );
          }).toList(),
          onChanged: (t) {
            if (t != null) onChanged(t);
          },
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade500,
              fontFamily: 'Georgia',
            ),
          ),
        ],
      ),
    );
  }
}
