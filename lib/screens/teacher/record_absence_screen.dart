// Scénario 2 — Teacher / Admin / SubAdmin — Section "Absences"
// Point d'entrée : liste des classes du teacher (ou toutes si admin/subAdmin).
// Navigue vers [ClassAttendanceScreen] (feuille d'appel partagée).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/class_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/class_service.dart';
import '../shared/class_attendance_screen.dart';

/// Liste des classes → feuille d'appel.
class RecordAbsenceScreen extends StatelessWidget {
  const RecordAbsenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentUser = auth.currentUser;

    final classStream = (currentUser?.role == UserRole.teacher)
        ? ClassService().streamByTeacher(currentUser!.uid)
        : ClassService().streamAll();

    return Scaffold(
      appBar: AppBar(title: const Text('Absences — Choisir une classe')),
      body: StreamBuilder<List<ClassModel>>(
        stream: classStream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator.adaptive());
          }
          final classes = snap.data ?? [];
          if (classes.isEmpty) {
            return _EmptyState(
              icon: Icons.class_outlined,
              message: currentUser?.role == UserRole.teacher
                  ? 'Aucune classe ne vous est assignée.'
                  : 'Aucune classe active.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: classes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _ClassTile(
              cls: classes[i],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ClassAttendanceScreen(cls: classes[i]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Class tile ───────────────────────────────────────────────────────────────

class _ClassTile extends StatelessWidget {
  final ClassModel cls;
  final VoidCallback onTap;
  const _ClassTile({required this.cls, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outline),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(6),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.class_outlined,
                  color: colorScheme.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cls.name,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface),
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.people_outline,
                        size: 13, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      '${cls.studentCount} étudiant${cls.studentCount > 1 ? 's' : ''}',
                      style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant),
                    ),
                    if (cls.schedule.day.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.schedule_outlined,
                          size: 13, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          cls.schedule.display,
                          style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
            // Badge "Faire l'appel"
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppColors.success.withAlpha(60)),
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
                        color: AppColors.success),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: colorScheme.onSurfaceVariant),
          ],
        ),
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
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                  height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
