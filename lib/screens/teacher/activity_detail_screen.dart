import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/activity_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/activity_service.dart';
import '../../services/user_service.dart';
import '../../widgets/kid_ui.dart';
import '../../widgets/media_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ActivityDetailScreen
//
// Affiche les détails complets d'une activité (groupe de records par étudiant).
// Permet :
//   • Voir tous les détails (titre, catégorie, description, objectifs, statuts)
//   • Modifier : titre, description, catégorie, date, durée, visibilité,
//                notes enseignant, humeur et taux de concentration par étudiant
//   • Supprimer le groupe
//
// Le statut est calculé automatiquement depuis date/durée — pas de champ éditable.
// ─────────────────────────────────────────────────────────────────────────────

class ActivityDetailScreen extends StatefulWidget {
  /// Groupe d'activités partageant le même titre/date (une par étudiant)
  final List<ActivityModel> group;

  const ActivityDetailScreen({super.key, required this.group});

  @override
  State<ActivityDetailScreen> createState() =>
      _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  final _activityService = ActivityService();
  final _userService = UserService();

  bool _editing = false;
  bool _saving = false;

  // ── Edit controllers ───────────────────────────────────────────────────────
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _notesCtrl;
  late ActivityCategory _category;
  late DateTime _date;
  late int? _duration;
  late bool _isVisibleToParent;

  // per-student state maps
  late Map<String, MoodLevel?> _moodMap;
  late Map<String, double> _concentrationMap;

  // student cache
  final Map<String, UserModel> _studentCache = {};

  @override
  void initState() {
    super.initState();
    final rep = widget.group.first;
    _titleCtrl = TextEditingController(text: rep.title);
    _descCtrl = TextEditingController(text: rep.description);
    _notesCtrl = TextEditingController(text: rep.teacherNotes ?? '');
    _category = rep.category;
    _date = rep.date;
    _duration = rep.duration;
    _isVisibleToParent = rep.isVisibleToParent;

    _moodMap = {for (final a in widget.group) a.id: a.mood};
    _concentrationMap = {
      for (final a in widget.group) a.id: a.concentrationRate
    };

    _loadStudents();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    for (final a in widget.group) {
      if (!_studentCache.containsKey(a.studentId)) {
        final u = await _userService.getUserById(a.studentId);
        if (u != null && mounted) {
          setState(() => _studentCache[a.studentId] = u);
        }
      }
    }
  }

  // ── Date picker ────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (time != null && mounted) {
      setState(() {
        _date = DateTime(
          picked.year, picked.month, picked.day,
          time.hour, time.minute,
        );
      });
    }
  }

  // ── Save tracking only (mood, concentration) ──────────────────────────────

  Future<void> _saveTracking() async {
    setState(() => _saving = true);
    try {
      for (final a in widget.group) {
        await _activityService.update(a.copyWith(
          mood:              _moodMap[a.id],
          concentrationRate: _concentrationMap[a.id] ?? a.concentrationRate,
        ));
      }
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Suivi enregistré ✓'),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur : $e'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  // ── Save all (title, category, description, date, etc.) ──────────────────

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      for (final a in widget.group) {
        await _activityService.update(a.copyWith(
          title:             _titleCtrl.text.trim(),
          description:       _descCtrl.text.trim(),
          category:          _category,
          date:              _date,
          duration:          _duration,
          isVisibleToParent: _isVisibleToParent,
          teacherNotes:      _notesCtrl.text.trim().isEmpty
              ? null
              : _notesCtrl.text.trim(),
          mood:              _moodMap[a.id],
          concentrationRate: _concentrationMap[a.id] ?? a.concentrationRate,
        ));
      }
      if (!mounted) return;
      setState(() {
        _editing = false;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Activité mise à jour ✓'),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Erreur : $e'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'activité'),
        content: Text(
          'Supprimer "${widget.group.first.title}" pour '
          '${widget.group.length} étudiant(s) ?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    for (final a in widget.group) {
      await _activityService.delete(a.id);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Activité supprimée'),
      backgroundColor: AppColors.error,
    ));
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Color _statusColor(ActivityStatus s) {
    switch (s) {
      case ActivityStatus.completed:
        return AppColors.success;
      case ActivityStatus.inProgress:
        return AppColors.warning;
      case ActivityStatus.pending:
        return context.textSecondary;
    }
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}  '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rep = widget.group.first;
    final canEdit = context.read<AuthProvider>().currentUser?.role !=
        UserRole.student;

    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        title: Text(_editing ? 'Modifier l\'activité' : 'Détail activité'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (!_editing && canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Modifier',
              onPressed: () => setState(() => _editing = true),
            ),
          if (!_editing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Supprimer',
              onPressed: _delete,
              color: Colors.redAccent.shade100,
            ),
          if (_editing)
            _saving
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2)),
                  )
                : TextButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text('Enregistrer',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
          if (_editing)
            TextButton(
              onPressed: () => setState(() => _editing = false),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.white70)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Informations générales ────────────────────────────────────
          _buildCard(
            title: 'Informations générales',
            icon: Icons.info_outline,
            child: _editing
                ? _buildEditForm()
                : _buildViewInfo(rep, colorScheme),
          ),

          const SizedBox(height: 16),

          // ── Photos & vidéos ───────────────────────────────────────────
          if (rep.mediaUrls.isNotEmpty) ...[
            _buildCard(
              title: 'Photos & vidéos',
              icon: Icons.perm_media_rounded,
              child: MediaGallery(urls: rep.mediaUrls),
            ),
            const SizedBox(height: 16),
          ],

          // ── Objectifs pédagogiques ────────────────────────────────────
          if (rep.objectives.isNotEmpty)
            _buildCard(
              title: 'Objectifs pédagogiques',
              icon: Icons.flag_outlined,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: rep.objectives
                    .map((o) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.success.withAlpha(18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.success.withAlpha(60)),
                          ),
                          child: Text(o,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.success)),
                        ))
                    .toList(),
              ),
            ),

          if (rep.objectives.isNotEmpty) const SizedBox(height: 16),

          // ── Notes enseignant ──────────────────────────────────────────
          _buildCard(
            title: 'Notes enseignant',
            icon: Icons.sticky_note_2_outlined,
            child: _editing
                ? TextField(
                    controller: _notesCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Observations, remarques…',
                    ),
                  )
                : rep.teacherNotes != null && rep.teacherNotes!.isNotEmpty
                    ? Text(rep.teacherNotes!,
                        style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface,
                            height: 1.5))
                    : Text('Aucune note',
                        style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic)),
          ),

          const SizedBox(height: 16),

          // ── Suivi par étudiant ────────────────────────────────────────
          _buildCard(
            title: 'Suivi par étudiant (${widget.group.length})',
            icon: Icons.people_outline,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...widget.group
                    .map((a) => _buildStudentRow(a, colorScheme))
                    .toList(),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _saveTracking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Enregistrer le suivi'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Vue lecture seule ──────────────────────────────────────────────────────

  Widget _buildViewInfo(ActivityModel rep, ColorScheme cs) {
    final status = rep.status;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Catégorie + titre
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.primary.withAlpha(15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(rep.category.emoji,
                style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rep.title,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface)),
                Text(rep.category.label,
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          // Statut affiché en lecture seule (calculé auto)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor(status).withAlpha(20),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _statusColor(status).withAlpha(60)),
            ),
            child: Text(
              status.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _statusColor(status),
              ),
            ),
          ),
        ]),

        const SizedBox(height: 16),
        Divider(height: 1, color: cs.outline),
        const SizedBox(height: 14),

        // Date + durée
        _infoRow(Icons.calendar_today, 'Date', _formatDate(rep.date), cs),
        if (rep.duration != null)
          _infoRow(Icons.timer_outlined, 'Durée', '${rep.duration} min', cs),

        // Description
        if (rep.description.isNotEmpty) ...[
          const SizedBox(height: 10),
          _infoRow(Icons.notes, 'Description', rep.description, cs),
        ],

        const SizedBox(height: 10),

        // Classe (si fullClass)
        if (rep.targetMode == ActivityTargetMode.fullClass &&
            rep.className != null) ...[
          Row(children: [
            Icon(Icons.group_outlined, size: 14, color: cs.primary),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: cs.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cs.primary.withAlpha(60)),
              ),
              child: Text(
                rep.className!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),
        ],

        // Visibilité
        Row(children: [
          Icon(
            rep.isVisibleToParent
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 15,
            color: rep.isVisibleToParent
                ? AppColors.success
                : cs.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            rep.isVisibleToParent
                ? 'Visible aux parents'
                : 'Non visible aux parents',
            style: TextStyle(
              fontSize: 12,
              color: rep.isVisibleToParent
                  ? AppColors.success
                  : cs.onSurfaceVariant,
            ),
          ),
        ]),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Text('$label : ',
              style: TextStyle(
                  fontSize: 12, color: cs.onSurfaceVariant)),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  // ── Formulaire d'édition ───────────────────────────────────────────────────

  Widget _buildEditForm() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titre
        TextField(
          controller: _titleCtrl,
          decoration: InputDecoration(
            labelText: 'Titre',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 14),

        // Catégorie
        DropdownButtonFormField<ActivityCategory>(
          value: _category,
          decoration: InputDecoration(
            labelText: 'Catégorie',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          items: ActivityCategory.values
              .map((c) => DropdownMenuItem(
                    value: c,
                    child: Row(children: [
                      Text(c.emoji),
                      const SizedBox(width: 8),
                      Text(c.label),
                    ]),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _category = v);
          },
        ),
        const SizedBox(height: 14),

        // Description
        TextField(
          controller: _descCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Description',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 14),

        // Date + durée
        Row(children: [
          Expanded(
            flex: 3,
            child: OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today, size: 15),
              label: Text(_formatDate(_date),
                  style: const TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: _duration?.toString() ?? '',
              decoration: InputDecoration(
                labelText: 'Durée (min)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) =>
                  setState(() => _duration = int.tryParse(v)),
            ),
          ),
        ]),
        const SizedBox(height: 14),

        // Visibilité
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outline),
            borderRadius: BorderRadius.circular(10),
          ),
          child: SwitchListTile(
            title: const Text('Visible aux parents',
                style: TextStyle(fontSize: 14)),
            value: _isVisibleToParent,
            activeThumbColor: AppColors.primary,
            onChanged: (v) =>
                setState(() => _isVisibleToParent = v),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
      ],
    );
  }

  // ── Ligne étudiant ─────────────────────────────────────────────────────────

  Widget _buildStudentRow(ActivityModel a, ColorScheme colorScheme) {
    final student = _studentCache[a.studentId];
    final name = student?.fullName ?? '…';
    final status = a.status; // computed from date/duration
    final mood = _moodMap[a.id];
    final concentration = _concentrationMap[a.id] ?? a.concentrationRate;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nom étudiant + statut calculé
          Row(children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withAlpha(20),
              backgroundImage: student?.profileImageUrl != null
                  ? NetworkImage(student!.profileImageUrl!)
                  : null,
              child: student?.profileImageUrl == null
                  ? Text(
                      student?.initials ?? '?',
                      style: TextStyle(
                          fontSize: 11,
                          color: context.brand,
                          fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(name,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface)),
            ),
            // Statut en lecture seule
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor(status).withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status.label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _statusColor(status)),
              ),
            ),
          ]),

          const SizedBox(height: 10),

          // Humeur
          Row(
            children: [
              Text('Humeur :',
                  style: TextStyle(
                      fontSize: 12, color: colorScheme.onSurfaceVariant)),
              const SizedBox(width: 8),
              DropdownButton<MoodLevel?>(
                value: mood,
                isDense: true,
                hint: const Text('—', style: TextStyle(fontSize: 12)),
                underline: const SizedBox(),
                items: [
                  const DropdownMenuItem<MoodLevel?>(
                    value: null,
                    child: Text('—', style: TextStyle(fontSize: 12)),
                  ),
                  ...MoodLevel.values.map((m) => DropdownMenuItem(
                        value: m,
                        child: Text('${m.emoji} ${m.label}',
                            style: const TextStyle(fontSize: 12)),
                      )),
                ],
                onChanged: (v) => setState(() => _moodMap[a.id] = v),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Taux de concentration
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Concentration :',
                      style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant)),
                  Text('${concentration.toInt()}%',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _statusColor(status))),
                ],
              ),
              const SizedBox(height: 6),
              Slider(
                value: concentration,
                min: 0,
                max: 100,
                divisions: 20,
                activeColor: _statusColor(status),
                label: '${concentration.toInt()}%',
                onChanged: (v) =>
                    setState(() => _concentrationMap[a.id] = v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Base card ──────────────────────────────────────────────────────────────

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [
              Icon(icon, size: 17, color: context.brand),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface)),
            ]),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}
