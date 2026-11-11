import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';
import '../../models/class_model.dart';
import '../../models/user_model.dart';
import '../../services/class_service.dart';
import '../../services/user_service.dart';
import '../../widgets/user_avatar.dart';
import 'class_detail_screen.dart';

// ─── Main screen ──────────────────────────────────────────────────────────────

class ClassManagementScreen extends StatefulWidget {
  final UserModel currentUser;
  const ClassManagementScreen({super.key, required this.currentUser});

  @override
  State<ClassManagementScreen> createState() => _ClassManagementScreenState();
}

class _ClassManagementScreenState extends State<ClassManagementScreen> {
  final ClassService _classService = ClassService();
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(child: _buildList()),
      ],
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      color: context.surfaceBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Class Management',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,)),
                    const SizedBox(height: 2),
                    Text(
                      'Create, edit and assign students to classes',
                      style: TextStyle(
                          fontSize: 13,
                          color: context.textSecondary,),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _openCreateClass,
                icon: const Icon(Icons.add, size: 17),
                label: const Text('New Class'),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 16)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search classes…',
              prefixIcon: Icon(Icons.search,
                  color: context.textSecondary, size: 20),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear,
                          color: context.textSecondary, size: 17),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _search = '');
                      })
                  : null,
              filled: true,
              fillColor: context.softFill,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.divider)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.divider)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5)),
            ),
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ── Class list ────────────────────────────────────────────────────────────
  Widget _buildList() {
    return StreamBuilder<List<ClassModel>>(
      stream: _classService.streamAll(activeOnly: false),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(color: context.brand));
        }
        if (snap.hasError) {
          return Center(
              child: Text('Error: ${snap.error}',
                  style: const TextStyle(
                      color: AppColors.error,)));
        }

        final all = snap.data ?? [];
        final classes = _search.isEmpty
            ? all
            : all
                .where((c) =>
                    c.name.toLowerCase().contains(_search) ||
                    c.academicYear.toLowerCase().contains(_search) ||
                    c.level.label.toLowerCase().contains(_search))
                .toList();

        if (classes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.class_outlined,
                    size: 56,
                    color: context.textSecondary.withAlpha(80)),
                const SizedBox(height: 14),
                Text(
                  _search.isNotEmpty
                      ? 'No classes match "$_search"'
                      : 'No classes yet',
                  style: TextStyle(
                      fontSize: 15,
                      color: context.textSecondary,),
                ),
                if (_search.isEmpty) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _openCreateClass,
                    icon: const Icon(Icons.add, size: 15),
                    label: const Text('Create First Class'),
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 14)),
                  ),
                ],
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          itemCount: classes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _ClassCard(
            cls: classes[i],
            onTap: () => _openDetail(classes[i]),
            onEdit: () => _openEditClass(classes[i]),
            onToggle: () => _toggleActive(classes[i]),
            onAssignStudents: () => _openAssignStudents(classes[i]),
            onAssignTeachers: () => _openAssignTeachers(classes[i]),
          ),
        );
      },
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────
  void _openCreateClass() {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            ClassFormScreen(classService: _classService)));
  }

  void _openEditClass(ClassModel cls) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            ClassFormScreen(classService: _classService, editClass: cls)));
  }

  void _openAssignStudents(ClassModel cls) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AssignStudentsScreen(
            cls: cls, classService: _classService)));
  }

  void _openAssignTeachers(ClassModel cls) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AssignTeachersScreen(
            cls: cls, classService: _classService)));
  }

  void _openDetail(ClassModel cls) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            ClassDetailScreen(cls: cls, classService: _classService)));
  }

  Future<void> _toggleActive(ClassModel cls) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          cls.isActive ? 'Deactivate Class' : 'Activate Class',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          cls.isActive
              ? 'Deactivate "${cls.name}"? It will be hidden from teachers.'
              : 'Activate "${cls.name}"?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle())),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor:
                    cls.isActive ? AppColors.error : AppColors.success),
            child: Text(cls.isActive ? 'Deactivate' : 'Activate',
                style: const TextStyle()),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _classService.setActive(cls.id, !cls.isActive);
    }
  }
}

// ─── Class card ───────────────────────────────────────────────────────────────

class _ClassCard extends StatelessWidget {
  final ClassModel cls;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onAssignStudents;
  final VoidCallback onAssignTeachers;

  const _ClassCard({
    required this.cls,
    required this.onTap,
    required this.onEdit,
    required this.onToggle,
    required this.onAssignStudents,
    required this.onAssignTeachers,
  });

  @override
  Widget build(BuildContext context) {
    final levelColor = _levelColor(cls.level);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surfaceBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: cls.isActive
                  ? context.divider
                  : AppColors.error.withAlpha(60)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row ──────────────────────────────────────────────────────
          Row(
            children: [
              // Level badge + icon
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: levelColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: levelColor.withAlpha(80)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.class_outlined, size: 13, color: levelColor),
                  const SizedBox(width: 4),
                  Text(cls.level.label,
                      style: TextStyle(
                          fontSize: 11,
                          color: levelColor,
                          fontWeight: FontWeight.w600,)),
                ]),
              ),
              const SizedBox(width: 8),
              if (!cls.isActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.error.withAlpha(20),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Inactive',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,)),
                ),
              const Spacer(),
              // Actions menu
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert,
                    color: context.textSecondary, size: 20),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'students') onAssignStudents();
                  if (v == 'teachers') onAssignTeachers();
                  if (v == 'toggle') onToggle();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined,
                            size: 17, color: context.brand),
                        SizedBox(width: 8),
                        Text('Edit Class',
                            style: TextStyle()),
                      ])),
                  const PopupMenuItem(
                      value: 'teachers',
                      child: Row(children: [
                        Icon(Icons.school_outlined,
                            size: 17, color: AppColors.warning),
                        SizedBox(width: 8),
                        Text('Assign Teachers',
                            style: TextStyle()),
                      ])),
                  const PopupMenuItem(
                      value: 'students',
                      child: Row(children: [
                        Icon(Icons.people_alt_outlined,
                            size: 17, color: AppColors.success),
                        SizedBox(width: 8),
                        Text('Assign Students',
                            style: TextStyle()),
                      ])),
                  PopupMenuItem(
                      value: 'toggle',
                      child: Row(children: [
                        Icon(
                            cls.isActive
                                ? Icons.block
                                : Icons.check_circle_outline,
                            size: 17,
                            color: cls.isActive
                                ? AppColors.error
                                : AppColors.success),
                        const SizedBox(width: 8),
                        Text(cls.isActive ? 'Deactivate' : 'Activate',
                            style: TextStyle(color: cls.isActive
                                    ? AppColors.error
                                    : AppColors.success)),
                      ])),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Name & year ───────────────────────────────────────────────────
          Text(cls.name,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,)),
          const SizedBox(height: 2),
          Row(children: [
            Icon(Icons.calendar_today_outlined,
                size: 13, color: context.textSecondary),
            const SizedBox(width: 4),
            Text(cls.academicYear,
                style: TextStyle(
                    fontSize: 12,
                    color: context.textSecondary,)),
            if (cls.room != null) ...[
              const SizedBox(width: 12),
              Icon(Icons.room_outlined,
                  size: 13, color: context.textSecondary),
              const SizedBox(width: 4),
              Text(cls.room!,
                  style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,)),
            ],
            if (cls.schedule.day.isNotEmpty) ...[
              const SizedBox(width: 12),
              Icon(Icons.schedule_outlined,
                  size: 13, color: context.textSecondary),
              const SizedBox(width: 4),
              Text(cls.schedule.display,
                  style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,)),
            ],
          ]),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // ── Stats row ─────────────────────────────────────────────────────
          Row(children: [
            Flexible(
              child: _StatPill(
                icon: Icons.people_outline,
                label: '${cls.studentCount} / ${cls.capacity} students',
                color: cls.isFull ? AppColors.error : AppColors.success,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: _StatPill(
                icon: Icons.school_outlined,
                label: '${cls.teacherCount} teacher${cls.teacherCount != 1 ? 's' : ''}',
                color: AppColors.primary,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            // Quick assign teachers button
            TextButton.icon(
              onPressed: onAssignTeachers,
              icon: const Icon(Icons.school_outlined, size: 15),
              label: const Text('Teachers',
                  style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.warning,
                minimumSize: const Size(0, 32),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
            ),
            const SizedBox(width: 4),
            // Quick assign students button
            TextButton.icon(
              onPressed: onAssignStudents,
              icon: const Icon(Icons.person_add_outlined, size: 15),
              label: const Text('Students',
                  style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: context.brand,
                minimumSize: const Size(0, 32),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
            ),
          ]),
        ],
      ),
    ), // Container
  ); // InkWell
  }

  Color _levelColor(ClassLevel l) {
    switch (l) {
      case ClassLevel.beginner:     return AppColors.success;
      case ClassLevel.intermediate: return AppColors.warning;
      case ClassLevel.advanced:     return AppColors.primary;
    }
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatPill(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,)),
    ]);
  }
}

// ─── Class form screen (create / edit) ───────────────────────────────────────

class ClassFormScreen extends StatefulWidget {
  final ClassService classService;
  final ClassModel? editClass;

  const ClassFormScreen(
      {super.key, required this.classService, this.editClass});

  bool get isEditing => editClass != null;

  @override
  State<ClassFormScreen> createState() => _ClassFormScreenState();
}

class _ClassFormScreenState extends State<ClassFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl         = TextEditingController();
  final _capacityCtrl     = TextEditingController();
  final _roomCtrl         = TextEditingController();
  final _yearCtrl         = TextEditingController();
  final _startTimeCtrl    = TextEditingController();
  final _endTimeCtrl      = TextEditingController();

  ClassLevel _level   = ClassLevel.beginner;
  String?    _day;

  bool    _loading = false;
  String? _error;

  static const _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.editClass;
    if (e != null) {
      _nameCtrl.text      = e.name;
      _capacityCtrl.text  = e.capacity.toString();
      _roomCtrl.text      = e.room ?? '';
      _yearCtrl.text      = e.academicYear;
      _level              = e.level;
      _day                = e.schedule.day.isEmpty ? null : e.schedule.day;
      _startTimeCtrl.text = e.schedule.startTime;
      _endTimeCtrl.text   = e.schedule.endTime;
    } else {
      _yearCtrl.text = _currentAcademicYear();
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _capacityCtrl, _roomCtrl, _yearCtrl,
      _startTimeCtrl, _endTimeCtrl,
    ]) c.dispose();
    super.dispose();
  }

  String _currentAcademicYear() {
    final now = DateTime.now();
    final y = now.month >= 9 ? now.year : now.year - 1;
    return '$y-${y + 1}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() { _loading = true; _error = null; });

    try {
      final schedule = ClassSchedule(
        day: _day ?? '',
        startTime: _startTimeCtrl.text.trim(),
        endTime:   _endTimeCtrl.text.trim(),
      );

      if (widget.isEditing) {
        final updated = widget.editClass!.copyWith(
          name:         _nameCtrl.text.trim(),
          level:        _level,
          capacity:     int.parse(_capacityCtrl.text.trim()),
          room:         _roomCtrl.text.trim().isEmpty ? null : _roomCtrl.text.trim(),
          academicYear: _yearCtrl.text.trim(),
          schedule:     schedule,
        );
        await widget.classService.update(updated);
      } else {
        final cls = ClassModel(
          id:           '',
          name:         _nameCtrl.text.trim(),
          level:        _level,
          capacity:     int.parse(_capacityCtrl.text.trim()),
          room:         _roomCtrl.text.trim().isEmpty ? null : _roomCtrl.text.trim(),
          academicYear: _yearCtrl.text.trim(),
          schedule:     schedule,
          createdAt:    DateTime.now(),
        );
        await widget.classService.create(cls);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Class' : 'New Class',
            style: const TextStyle(fontSize: 17)),
        leading: const BackButton(color: Colors.white),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white)),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton(
                onPressed: _submit,
                style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                child: Text(
                  widget.isEditing ? 'Save' : 'Create',
                  style: const TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            if (_error != null)
              _ClassBanner(
                  msg: _error!,
                  color: AppColors.error,
                  icon: Icons.error_outline,
                  onClose: () => setState(() => _error = null)),
            Expanded(child: _buildFormBody()),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildFormBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Basic info ──────────────────────────────────────────────
              _ClassSectionTitle('Basic Information'),
              const SizedBox(height: 12),
              _buildField(_nameCtrl, 'Class Name',
                  icon: Icons.drive_file_rename_outline,
                  hint: 'e.g. Butterflies Group',
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: _buildField(_capacityCtrl, 'Capacity',
                      icon: Icons.people_outline,
                      hint: 'e.g. 10',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        final n = int.tryParse(v);
                        if (n == null || n <= 0) return 'Must be > 0';
                        return null;
                      }),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildField(_roomCtrl, 'Room (optional)',
                      icon: Icons.room_outlined,
                      hint: 'e.g. Room 3A'),
                ),
              ]),

              const SizedBox(height: 32),

              // ── Level & Year ────────────────────────────────────────────
              _ClassSectionTitle('Level & Academic Year'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<ClassLevel>(
                    value: _level,
                    isExpanded: true,
                    decoration: _inputDeco('Level', Icons.bar_chart_outlined),
                    style: TextStyle(fontSize: 14,
                        color: context.textPrimary),
                    items: ClassLevel.values
                        .map((l) => DropdownMenuItem(
                            value: l,
                            child: Text(l.label,
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => setState(() => _level = v!),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildField(_yearCtrl, 'Academic Year',
                      icon: Icons.calendar_today_outlined,
                      hint: '2024-2025',
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null),
                ),
              ]),

              const SizedBox(height: 32),

              // ── Schedule ────────────────────────────────────────────────
              _ClassSectionTitle('Schedule'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _day,
                isExpanded: true,
                decoration: _inputDeco('Day', Icons.today_outlined),
                hint: const Text('Select day',
                    style: TextStyle(fontSize: 14)),
                style: TextStyle(fontSize: 14,
                    color: context.textPrimary),
                items: _days
                    .map((d) => DropdownMenuItem(
                        value: d,
                        child: Text(d,
                            style: const TextStyle(fontSize: 14))))
                    .toList(),
                onChanged: (v) => setState(() => _day = v),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: _buildField(_startTimeCtrl, 'Start Time',
                      icon: Icons.play_arrow_outlined,
                      hint: 'e.g. 09:00'),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildField(_endTimeCtrl, 'End Time',
                      icon: Icons.stop_outlined,
                      hint: 'e.g. 10:30'),
                ),
              ]),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: context.surfaceBg,
        border: Border(top: BorderSide(color: context.divider)),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, size: 16),
            label:
                const Text('Cancel', style: TextStyle()),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.textSecondary,
              side: BorderSide(color: context.divider),
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _loading ? null : _submit,
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_outline, size: 18),
            label: Text(
              widget.isEditing ? 'Save Changes' : 'Create Class',
              style: const TextStyle(fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              minimumSize: const Size(160, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String label, {
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(fontSize: 14),
      decoration: _inputDeco(label, icon, hint: hint),
      validator: validator,
    );
  }

  InputDecoration _inputDeco(String label, IconData icon, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 19, color: context.textSecondary),
      filled: true,
      fillColor: context.surfaceBg,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.divider)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.divider)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      labelStyle: const TextStyle(fontSize: 14),
      hintStyle: TextStyle(fontSize: 13,
          color: context.textSecondary),
    );
  }
}

// ─── Assign Students screen ───────────────────────────────────────────────────

class AssignStudentsScreen extends StatefulWidget {
  final ClassModel cls;
  final ClassService classService;

  const AssignStudentsScreen(
      {super.key, required this.cls, required this.classService});

  @override
  State<AssignStudentsScreen> createState() => _AssignStudentsScreenState();
}

class _AssignStudentsScreenState extends State<AssignStudentsScreen> {
  final UserService _userService = UserService();
  late Set<String> _enrolled;
  String _search = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _enrolled = Set.from(widget.cls.studentIds);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // Build the updated studentIds list and save to the class doc
      await widget.classService.update(
        widget.cls.copyWith(studentIds: _enrolled.toList()),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e',
                style: const TextStyle())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        title: Text('Assign Students — ${widget.cls.name}',
            style: const TextStyle(fontSize: 15)),
        leading: const BackButton(color: Colors.white),
        actions: [
          if (_saving)
            const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white)))
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save',
                  style: TextStyle(
                      color: Colors.white,fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Capacity banner ───────────────────────────────────────────────
          Container(
            color: context.surfaceBg,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              Icon(Icons.people_outline,
                  size: 18, color: context.brand),
              const SizedBox(width: 8),
              Text(
                '${_enrolled.length} / ${widget.cls.capacity} enrolled',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,),
              ),
              const Spacer(),
              if (widget.cls.isFull && _enrolled.length >= widget.cls.capacity)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.error.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Class Full',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,)),
                ),
            ]),
          ),

          // ── Search ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: TextField(
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search students…',
                prefixIcon: Icon(Icons.search,
                    color: context.textSecondary, size: 19),
                filled: true,
                fillColor: context.surfaceBg,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 11),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: context.divider)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: context.divider)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1.5)),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),

          // ── Student list ──────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: _userService.streamUsersByRole(UserRole.student),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Center(
                      child: CircularProgressIndicator(
                          color: context.brand));
                }

                final all = snap.data ?? [];
                final students = _search.isEmpty
                    ? all
                    : all
                        .where((u) =>
                            u.fullName
                                .toLowerCase()
                                .contains(_search) ||
                            u.email
                                .toLowerCase()
                                .contains(_search))
                        .toList();

                if (students.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off_outlined,
                            size: 48,
                            color: context.textSecondary.withAlpha(80)),
                        const SizedBox(height: 12),
                        Text('No students found',
                            style: TextStyle(
                                fontSize: 14,
                                color: context.textSecondary,)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: students.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final s = students[i];
                    final isEnrolled = _enrolled.contains(s.uid);
                    final isFull = _enrolled.length >=
                            widget.cls.capacity &&
                        !isEnrolled;

                    return Container(
                      decoration: BoxDecoration(
                        color: isEnrolled
                            ? AppColors.primary.withAlpha(10)
                            : context.surfaceBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isEnrolled
                              ? AppColors.primary.withAlpha(80)
                              : context.divider,
                          width: isEnrolled ? 1.5 : 1,
                        ),
                      ),
                      child: ListTile(
                        leading: UserAvatar(user: s, radius: 20),
                        title: Text(s.fullName,
                            style: const TextStyle(fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(s.email,
                            style: TextStyle(fontSize: 12,
                                color: context.textSecondary)),
                        trailing: isFull
                            ? Tooltip(
                                message: 'Class is full',
                                child: Icon(Icons.block,
                                    color: context.textSecondary,
                                    size: 20))
                            : Checkbox(
                                value: isEnrolled,
                                activeColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(4)),
                                onChanged: (_) {
                                  setState(() {
                                    if (isEnrolled) {
                                      _enrolled.remove(s.uid);
                                    } else {
                                      _enrolled.add(s.uid);
                                    }
                                  });
                                },
                              ),
                        onTap: isFull
                            ? null
                            : () {
                                setState(() {
                                  if (isEnrolled) {
                                    _enrolled.remove(s.uid);
                                  } else {
                                    _enrolled.add(s.uid);
                                  }
                                });
                              },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

// ─── Assign Teachers screen ───────────────────────────────────────────────────

class AssignTeachersScreen extends StatefulWidget {
  final ClassModel cls;
  final ClassService classService;

  const AssignTeachersScreen(
      {super.key, required this.cls, required this.classService});

  @override
  State<AssignTeachersScreen> createState() => _AssignTeachersScreenState();
}

class _AssignTeachersScreenState extends State<AssignTeachersScreen> {
  final UserService _userService = UserService();
  late Set<String> _assigned;
  String _search = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _assigned = Set.from(widget.cls.teacherIds);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.classService.update(
        widget.cls.copyWith(teacherIds: _assigned.toList()),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e',
                style: const TextStyle())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        title: Text('Assign Teachers — ${widget.cls.name}',
            style: const TextStyle(fontSize: 15)),
        leading: const BackButton(color: Colors.white),
        actions: [
          if (_saving)
            const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white)))
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save',
                  style: TextStyle(
                      color: Colors.white,fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Summary banner ──────────────────────────────────────────────
          Container(
            color: context.surfaceBg,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              const Icon(Icons.school_outlined,
                  size: 18, color: AppColors.warning),
              const SizedBox(width: 8),
              Text(
                '${_assigned.length} teacher${_assigned.length != 1 ? 's' : ''} assigned',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,),
              ),
              const Spacer(),
              Text(widget.cls.name,
                  style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,)),
            ]),
          ),

          // ── Search ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: TextField(
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search teachers…',
                prefixIcon: Icon(Icons.search,
                    color: context.textSecondary, size: 19),
                filled: true,
                fillColor: context.surfaceBg,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 11),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: context.divider)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: context.divider)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1.5)),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),

          // ── Teacher list ─────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: _userService.streamUsersByRole(UserRole.teacher),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Center(
                      child: CircularProgressIndicator(
                          color: context.brand));
                }

                final all = snap.data ?? [];
                final teachers = _search.isEmpty
                    ? all
                    : all
                        .where((u) =>
                            u.fullName
                                .toLowerCase()
                                .contains(_search) ||
                            u.email
                                .toLowerCase()
                                .contains(_search))
                        .toList();

                if (teachers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off_outlined,
                            size: 48,
                            color: context.textSecondary.withAlpha(80)),
                        const SizedBox(height: 12),
                        Text('No teachers found',
                            style: TextStyle(
                                fontSize: 14,
                                color: context.textSecondary,)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: teachers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final t = teachers[i];
                    final isAssigned = _assigned.contains(t.uid);

                    return Container(
                      decoration: BoxDecoration(
                        color: isAssigned
                            ? AppColors.warning.withAlpha(15)
                            : context.surfaceBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isAssigned
                              ? AppColors.warning.withAlpha(120)
                              : context.divider,
                          width: isAssigned ? 1.5 : 1,
                        ),
                      ),
                      child: ListTile(
                        leading: UserAvatar(user: t, radius: 20),
                        title: Text(t.fullName,
                            style: const TextStyle(fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          t.speciality != null && t.speciality!.isNotEmpty
                              ? t.speciality!
                              : t.email,
                          style: TextStyle(fontSize: 12,
                              color: context.textSecondary),
                        ),
                        trailing: Checkbox(
                          value: isAssigned,
                          activeColor: AppColors.warning,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
                          onChanged: (_) {
                            setState(() {
                              if (isAssigned) {
                                _assigned.remove(t.uid);
                              } else {
                                _assigned.add(t.uid);
                              }
                            });
                          },
                        ),
                        onTap: () {
                          setState(() {
                            if (isAssigned) {
                              _assigned.remove(t.uid);
                            } else {
                              _assigned.add(t.uid);
                            }
                          });
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Class form helpers ───────────────────────────────────────────────────────

class _ClassSectionTitle extends StatelessWidget {
  final String title;
  const _ClassSectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(title,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: context.textSecondary,)),
    ]);
  }
}

class _ClassBanner extends StatelessWidget {
  final String msg;
  final Color color;
  final IconData icon;
  final VoidCallback onClose;

  const _ClassBanner(
      {required this.msg,
      required this.color,
      required this.icon,
      required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(76)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
            child: Text(msg,
                style: TextStyle(
                    color: color, fontSize: 13,))),
        GestureDetector(
          onTap: onClose,
          child: Icon(Icons.close, color: color, size: 17),
        ),
      ]),
    );
  }
}
