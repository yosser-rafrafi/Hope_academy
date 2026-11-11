import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/absence_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/absence_service.dart';
import '../../widgets/user_avatar.dart';

/// Scénario 3 — Enregistrer une absence pour un étudiant précis.
/// Accessible depuis :
///   • UserDetailsScreen   (Admin / SubAdmin / Teacher → section Students)
///   • StudentAbsencesScreen
///
/// Paramètres :
///   [student]  — l'étudiant ciblé
class RecordStudentAbsenceScreen extends StatefulWidget {
  final UserModel student;

  const RecordStudentAbsenceScreen({super.key, required this.student});

  @override
  State<RecordStudentAbsenceScreen> createState() =>
      _RecordStudentAbsenceScreenState();
}

class _RecordStudentAbsenceScreenState
    extends State<RecordStudentAbsenceScreen> {
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

  // ── Check duplicate ────────────────────────────────────────────────────────

  Future<void> _checkDate() async {
    setState(() => _checkingDate = true);
    final absent = await _absenceService.isStudentAbsent(
      studentId: widget.student.uid,
      date: _date,
    );
    if (mounted) setState(() {
      _alreadyAbsent = absent;
      _checkingDate = false;
    });
  }

  // ── Date picker ────────────────────────────────────────────────────────────

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

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_alreadyAbsent) return;

    setState(() => _saving = true);
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Absence enregistrée ✓'),
        backgroundColor: AppColors.success,
      ));
      Navigator.of(context).pop();
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enregistrer une absence'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Student info card ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.outline),
              ),
              child: Row(children: [
                UserAvatar(user: widget.student, radius: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.student.fullName,
                          style: textTheme.titleMedium),
                      if (widget.student.group != null &&
                          widget.student.group!.isNotEmpty)
                        Text(widget.student.group!,
                            style: textTheme.bodyMedium),
                    ],
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 24),

            // ── Date selector ─────────────────────────────────────────────
            Text('Date de l\'absence',
                style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold)),
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
                      color: colorScheme.primary.withAlpha(15),
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
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(Icons.edit_calendar_outlined,
                        size: 18, color: colorScheme.primary),
                ]),
              ),
            ),

            // Already absent warning
            if (_alreadyAbsent) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.error.withAlpha(60)),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_rounded,
                      size: 16, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Une absence est déjà enregistrée pour cette date.',
                      style: TextStyle(
                          fontSize: 12, color: colorScheme.onSurface),
                    ),
                  ),
                ]),
              ),
            ],

            const SizedBox(height: 24),

            // ── Type ──────────────────────────────────────────────────────
            Text('Type d\'absence',
                style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold)),
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
                        color: selected ? color : colorScheme.outline,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(t.emoji,
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(
                        t.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? Colors.white
                              : colorScheme.onSurface,
                        ),
                      ),
                    ]),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // ── Reason ────────────────────────────────────────────────────
            Text('Raison (optionnel)',
                style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold)),
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

            // ── Save button ───────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed:
                    (_saving || _alreadyAbsent || _checkingDate)
                        ? null
                        : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Enregistrer l\'absence',
                        style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
