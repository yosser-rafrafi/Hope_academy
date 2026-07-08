import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/absence_model.dart';
import '../../models/student_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/absence_service.dart';
import '../../widgets/user_avatar.dart';

/// Écran affichant les absences d'un étudiant spécifique
/// Accessible pour Admin, SubAdmin et Teacher
class StudentAbsencesScreen extends StatefulWidget {
  final StudentModel student;

  const StudentAbsencesScreen({
    super.key,
    required this.student,
  });

  @override
  State<StudentAbsencesScreen> createState() => _StudentAbsencesScreenState();
}

class _StudentAbsencesScreenState extends State<StudentAbsencesScreen> {
  final _absenceService = AbsenceService();

  int _selectedYear = DateTime.now().year;
  int? _selectedMonth;

  final _months = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentUser = auth.currentUser;
    final isAdminOrSubAdmin = currentUser?.role == UserRole.admin ||
        currentUser?.role == UserRole.subAdmin;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('Absences de ${widget.student.firstName}'),
      ),
      body: Column(
        children: [
          // Header — info étudiant
          _buildStudentHeader(),
          // Filtres
          _buildFilters(),
          // Stats summary
          _buildStatsSummary(isAdminOrSubAdmin),
          // Liste des absences
          Expanded(child: _buildAbsencesList()),
        ],
      ),
    );
  }

  Widget _buildStudentHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: Colors.white,
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
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Georgia',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Classe: ${widget.student.className}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontFamily: 'Georgia',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          // Filtre année
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: _selectedYear,
              decoration: InputDecoration(
                labelText: 'Année',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: List.generate(5, (i) => DateTime.now().year - i).map((y) {
                return DropdownMenuItem(value: y, child: Text(y.toString()));
              }).toList(),
              onChanged: (val) => setState(() => _selectedYear = val!),
            ),
          ),
          const SizedBox(width: 12),
          // Filtre mois (optionnel)
          Expanded(
            child: DropdownButtonFormField<int?>(
              initialValue: _selectedMonth,
              decoration: InputDecoration(
                labelText: 'Mois',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Tous')),
                ...List.generate(12, (i) => i + 1).map((m) {
                  return DropdownMenuItem(value: m, child: Text(_months[m - 1]));
                }),
              ],
              onChanged: (val) => setState(() => _selectedMonth = val),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSummary(bool isAdminOrSubAdmin) {
    final startDate = _selectedMonth != null
        ? DateTime(_selectedYear, _selectedMonth!, 1)
        : DateTime(_selectedYear, 1, 1);
    final endDate = _selectedMonth != null
        ? DateTime(_selectedYear, _selectedMonth! + 1, 0)
        : DateTime(_selectedYear, 12, 31);

    return FutureBuilder<Map<AbsenceType, int>>(
      future: _absenceService.getAbsenceStatsByType(
        studentId: widget.student.uid,
        startDate: startDate,
        endDate: endDate,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }

        final stats = snapshot.data!;
        final total = stats.values.fold(0, (a, b) => a + b);

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedMonth != null
                        ? 'Absences - ${_months[_selectedMonth! - 1]} $_selectedYear'
                        : 'Absences - Année $_selectedYear',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Georgia',
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Total: $total',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                        fontFamily: 'Georgia',
                      ),
                    ),
                  ),
                ],
              ),
              if (isAdminOrSubAdmin && stats.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: stats.entries
                      .where((e) => e.value > 0)
                      .map((entry) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getTypeColor(entry.key).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getTypeColor(entry.key).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(entry.key.emoji, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text(
                            '${entry.key.label}: ${entry.value}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _getTypeColor(entry.key),
                              fontFamily: 'Georgia',
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildAbsencesList() {
    final startDate = _selectedMonth != null
        ? DateTime(_selectedYear, _selectedMonth!, 1)
        : DateTime(_selectedYear, 1, 1);
    final endDate = _selectedMonth != null
        ? DateTime(_selectedYear, _selectedMonth! + 1, 0)
        : DateTime(_selectedYear, 12, 31);

    return StreamBuilder<List<AbsenceModel>>(
      stream: _absenceService.streamAbsencesByDateRange(
        startDate: startDate,
        endDate: endDate,
        studentId: widget.student.uid,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: AppColors.success.withOpacity(0.5)),
                const SizedBox(height: 16),
                const Text(
                  'Aucune absence enregistrée',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    fontFamily: 'Georgia',
                  ),
                ),
              ],
            ),
          );
        }

        final absences = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: absences.length,
          itemBuilder: (context, index) {
            return _buildAbsenceItem(absences[index]);
          },
        );
      },
    );
  }

  Widget _buildAbsenceItem(AbsenceModel absence) {
    final typeColor = _getTypeColor(absence.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 50,
              decoration: BoxDecoration(
                color: typeColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(absence.type.emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        absence.type.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: typeColor,
                          fontFamily: 'Georgia',
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatDate(absence.date),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  if (absence.reason != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      absence.reason!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Enregistré par ${absence.recordedByName}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(AbsenceType type) {
    switch (type) {
      case AbsenceType.excused:
        return AppColors.success;
      case AbsenceType.unexcused:
        return AppColors.error;
      case AbsenceType.sick:
        return AppColors.warning;
      case AbsenceType.authorized:
        return AppColors.info;
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Fév', 'Mars', 'Avr', 'Mai', 'Juin',
      'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
