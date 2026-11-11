import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/class_model.dart';
import '../../models/student_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/class_service.dart';
import '../../services/user_service.dart';
import '../../l10n/app_strings.dart';
import '../pei/pei_screen.dart';
import '../../widgets/user_avatar.dart';
import '../admin/user_details_screen.dart';
import '../shared/class_attendance_screen.dart';
import '../shared/student_detail_absence_screen.dart';

/// Affiche tous les étudiants des classes assignées au professeur connecté,
/// regroupés par classe.
/// Scénario 2 : bouton "Appel" → ClassAttendanceScreen
/// Scénario 3 : tap étudiant / bouton absence → StudentDetailAbsenceScreen
class MyStudentsScreen extends StatefulWidget {
  const MyStudentsScreen({super.key});

  @override
  State<MyStudentsScreen> createState() => _MyStudentsScreenState();
}

class _MyStudentsScreenState extends State<MyStudentsScreen> {
  final _classService = ClassService();
  final _userService = UserService();

  String _search = '';

  @override
  Widget build(BuildContext context) {
    final teacherId =
        context.watch<AuthProvider>().currentUser?.uid ?? '';

    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: StreamBuilder<List<ClassModel>>(
            stream: _classService.streamByTeacher(teacherId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator.adaptive());
              }

              final classes = snap.data ?? [];

              if (classes.isEmpty) {
                return const _EmptyState(
                  icon: Icons.people_outline,
                  message:
                      'Aucune classe ne vous est assignée.\nDemandez à l\'administrateur de vous assigner une classe.',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: classes.length,
                itemBuilder: (_, i) => _ClassGroup(
                  cls: classes[i],
                  userService: _userService,
                  search: _search,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Barre de recherche ─────────────────────────────────────────────────────

  Widget _buildHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: TextField(
        onChanged: (v) => setState(() => _search = v.toLowerCase()),
        decoration: InputDecoration(
          hintText: 'Rechercher un étudiant…',
          prefixIcon: Icon(Icons.search,
              size: 20, color: colorScheme.onSurfaceVariant),
          suffixIcon: _search.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear,
                      size: 18, color: colorScheme.onSurfaceVariant),
                  onPressed: () => setState(() => _search = ''),
                )
              : null,
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: colorScheme.primary, width: 1.5),
          ),
        ),
        style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
      ),
    );
  }
}

// ─── Groupe par classe ────────────────────────────────────────────────────────

class _ClassGroup extends StatefulWidget {
  final ClassModel cls;
  final UserService userService;
  final String search;

  const _ClassGroup({
    required this.cls,
    required this.userService,
    required this.search,
  });

  @override
  State<_ClassGroup> createState() => _ClassGroupState();
}

class _ClassGroupState extends State<_ClassGroup> {
  bool _expanded = true;

  // ── Naviguer vers la feuille d'appel (Scénario 2) ─────────────────────────

  void _openAttendance() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClassAttendanceScreen(cls: widget.cls),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── En-tête de classe (collapse + bouton Appel) ───────────────────
        Container(
          margin: const EdgeInsets.only(top: 16, bottom: 8),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary.withAlpha(40)),
          ),
          child: Row(
            children: [
              // Icône classe
              GestureDetector(
                onTap: () =>
                    setState(() => _expanded = !_expanded),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(Icons.class_outlined,
                      color: context.brand, size: 16),
                ),
              ),
              const SizedBox(width: 10),
              // Nom de la classe (tap = collapse)
              Expanded(
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _expanded = !_expanded),
                  child: Text(
                    widget.cls.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: context.brand,
                    ),
                  ),
                ),
              ),
              // Badge nombre d'élèves
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${widget.cls.studentCount} élève${widget.cls.studentCount > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.brand,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Bouton "Appel" → ClassAttendanceScreen (Scénario 2)
              GestureDetector(
                onTap: _openAttendance,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.success.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.success.withAlpha(80)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.checklist_rounded,
                          size: 13, color: AppColors.success),
                      SizedBox(width: 4),
                      Text(
                        'Appel',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Flèche collapse
              GestureDetector(
                onTap: () =>
                    setState(() => _expanded = !_expanded),
                child: Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: context.brand,
                  size: 20,
                ),
              ),
            ],
          ),
        ),

        // ── Liste des étudiants ───────────────────────────────────────────
        if (_expanded)
          widget.cls.studentIds.isEmpty
              ? const _EmptyClassCard()
              : FutureBuilder<List<UserModel?>>(
                  future: Future.wait(
                    widget.cls.studentIds.map(
                        (id) => widget.userService.getUserById(id)),
                  ),
                  builder: (context, snap) {
                    if (snap.connectionState ==
                        ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                            child: CircularProgressIndicator(
                                strokeWidth: 2)),
                      );
                    }

                    final students = (snap.data ?? [])
                        .whereType<UserModel>()
                        .where((u) => u.role == UserRole.student)
                        .map((u) => StudentModel(
                              uid: u.uid,
                              firstName: u.firstName,
                              lastName: u.lastName,
                              classId: widget.cls.id,
                              className: widget.cls.name,
                              createdAt: u.createdAt,
                              enrolledAt:
                                  u.enrollmentDate ?? u.createdAt,
                              email: u.email,
                              profileImageUrl: u.profileImageUrl,
                              gender: u.gender,
                            ))
                        .where((s) =>
                            widget.search.isEmpty ||
                            s.fullName
                                .toLowerCase()
                                .contains(widget.search))
                        .toList()
                      ..sort((a, b) =>
                          a.lastName.compareTo(b.lastName));

                    if (students.isEmpty &&
                        widget.search.isNotEmpty) {
                      return const SizedBox.shrink();
                    }

                    return Column(
                      children: students
                          .map((s) => _StudentCard(student: s))
                          .toList(),
                    );
                  },
                ),
      ],
    );
  }
}

// ─── Carte étudiant ───────────────────────────────────────────────────────────

class _StudentCard extends StatelessWidget {
  final StudentModel student;
  const _StudentCard({required this.student});

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<AuthProvider>().currentUser!;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: UserAvatar(user: student, radius: 22),
        title: Text(
          student.fullName,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        subtitle: student.birthday != null
            ? Text(
                'Âge : ${student.age} ans',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bouton raccourci "PEI" → PeiScreen (objectifs + suivi des progrès)
            IconButton(
              icon: const Icon(Icons.flag_rounded,
                  size: 20, color: AppColors.grape),
              tooltip: context.tr('pei.button'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      PeiScreen(student: student, viewer: currentUser),
                ),
              ),
            ),
            // Bouton raccourci "Absences" → StudentDetailAbsenceScreen
            IconButton(
              icon: const Icon(Icons.event_busy_outlined,
                  size: 20, color: AppColors.error),
              tooltip: 'Absences',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      StudentDetailAbsenceScreen(student: student),
                ),
              ),
            ),
            Icon(Icons.chevron_right,
                size: 18, color: colorScheme.onSurfaceVariant),
          ],
        ),
        // Tap principal → profil complet (UserDetailsScreen)
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserDetailsScreen(
              user: student,
              currentUser: currentUser,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Classe vide ──────────────────────────────────────────────────────────────

class _EmptyClassCard extends StatelessWidget {
  const _EmptyClassCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline,
              size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            'Aucun étudiant dans cette classe',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── État vide générique ──────────────────────────────────────────────────────

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
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
