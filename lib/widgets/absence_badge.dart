import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/absence_model.dart';
import '../services/absence_service.dart';

/// Widget affichant le nombre d'absences d'un étudiant pour une période donnée
class AbsenceBadge extends StatelessWidget {
  final String studentId;
  final int year;
  final int? month;

  const AbsenceBadge({
    super.key,
    required this.studentId,
    required this.year,
    this.month,
  });

  @override
  Widget build(BuildContext context) {
    final absenceService = AbsenceService();

    return FutureBuilder<int>(
      future: month != null
          ? absenceService.countAbsencesByMonth(
              studentId: studentId,
              year: year,
              month: month!,
            )
          : absenceService.countAbsencesByYear(
              studentId: studentId,
              year: year,
            ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        final count = snapshot.data!;

        if (count == 0) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle,
                  size: 14,
                  color: AppColors.success,
                ),
                const SizedBox(width: 4),
                Text(
                  'Aucune absence',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,),
                ),
              ],
            ),
          );
        }

        final color = _getColorForCount(count);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.event_busy,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                '$count absence${count > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getColorForCount(int count) {
    if (count <= 2) return AppColors.warning;
    if (count <= 5) return const Color(0xFFFF8C00); // Dark orange
    return AppColors.error;
  }
}

/// Widget affichant un résumé des absences par type
class AbsenceTypeSummary extends StatelessWidget {
  final String studentId;
  final DateTime? startDate;
  final DateTime? endDate;

  const AbsenceTypeSummary({
    super.key,
    required this.studentId,
    this.startDate,
    this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    final absenceService = AbsenceService();

    return FutureBuilder<Map<AbsenceType, int>>(
      future: absenceService.getAbsenceStatsByType(
        studentId: studentId,
        startDate: startDate,
        endDate: endDate,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final stats = snapshot.data!;
        final total = stats.values.fold(0, (a, b) => a + b);

        if (total == 0) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Aucune absence enregistrée',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,),
                  ),
                ),
              ],
            ),
          );
        }

        final theme = Theme.of(context);
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            // Was hardcoded to Colors.white / Colors.grey.shade200, which
            // stayed white-on-white when the app is in dark mode. Using the
            // theme's own card color + divider keeps this widget correct in
            // both themes, matching every other card in the app.
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Résumé des absences',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Total: $total',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: stats.entries
                    .where((e) => e.value > 0)
                    .map((entry) => _buildTypeChip(entry.key, entry.value))
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTypeChip(AbsenceType type, int count) {
    final color = _getTypeColor(type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(type.emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            '${type.label}: $count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,),
          ),
        ],
      ),
    );
  }

  // Now shared via AppColors.absence* so this mapping is defined exactly
  // once — student_absences_screen / absence_management_screen should read
  // from the same constants rather than re-picking colors per screen.
  Color _getTypeColor(AbsenceType type) {
    switch (type) {
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
}
