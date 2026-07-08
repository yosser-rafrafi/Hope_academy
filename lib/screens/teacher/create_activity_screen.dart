import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/activity_model.dart';
import '../../models/class_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/activity_service.dart';
import '../../services/class_service.dart';
import '../../services/user_service.dart';

class CreateActivityScreen extends StatefulWidget {
  const CreateActivityScreen({super.key});

  @override
  State<CreateActivityScreen> createState() => _CreateActivityScreenState();
}

class _CreateActivityScreenState extends State<CreateActivityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _activityService = ActivityService();
  final _classService = ClassService();
  final _userService = UserService();

  bool _isSaving = false;

  // ── Form fields ──
  String _title = '';
  String _description = '';
  ActivityCategory _category = ActivityCategory.computerSkills;
  DateTime _date = DateTime.now();
  int? _duration;
  bool _isVisibleToParent = true;

  // ── Objectives ──
  final _objectiveCtrl = TextEditingController();
  final List<String> _objectives = [];

  // ── Targeting ──
  ActivityTargetMode _targetMode = ActivityTargetMode.individual;
  ClassModel? _selectedClass;
  List<UserModel> _selectedStudents = [];
  
  // ── Data ──
  List<ClassModel> _teacherClasses = [];
  List<UserModel> _allStudents = [];
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final teacherId = context.read<AuthProvider>().currentUser!.uid;
    try {
      // Load teacher's classes for the "Full Class" mode
      _classService.streamByTeacher(teacherId).listen((classes) {
        if (mounted) setState(() => _teacherClasses = classes);
      });
      // Load all students for global selection
      _userService.streamUsersByRole(UserRole.student).listen((students) {
        if (mounted) {
          setState(() {
            _allStudents = students;
            _isLoadingData = false;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  void dispose() {
    _objectiveCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
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
  }

  void _addObjective() {
    final text = _objectiveCtrl.text.trim();
    if (text.isNotEmpty && !_objectives.contains(text)) {
      setState(() {
        _objectives.add(text);
        _objectiveCtrl.clear();
      });
    }
  }

  void _removeObjective(String obj) {
    setState(() => _objectives.remove(obj));
  }

  Future<void> _pickStudents() async {
    final isMulti = _targetMode == ActivityTargetMode.selection;
    final initialSelection = Set<String>.from(_selectedStudents.map((s) => s.uid));
    
    final result = await showDialog<List<UserModel>>(
      context: context,
      builder: (ctx) => _StudentSelectionDialog(
        allStudents: _allStudents,
        initialSelection: initialSelection,
        isMultiSelect: isMulti,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        if (isMulti) {
          _selectedStudents = result;
        } else {
          _selectedStudents = result.isNotEmpty ? [result.first] : [];
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    List<String> finalStudentIds = [];

    if (_targetMode == ActivityTargetMode.fullClass) {
      if (_selectedClass == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a class'), backgroundColor: AppColors.error),
        );
        return;
      }
      if (_selectedClass!.studentIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected class has no students'), backgroundColor: AppColors.warning),
        );
        return;
      }
      finalStudentIds = _selectedClass!.studentIds;
    } else {
      if (_selectedStudents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one student'), backgroundColor: AppColors.error),
        );
        return;
      }
      finalStudentIds = _selectedStudents.map((s) => s.uid).toList();
    }

    setState(() => _isSaving = true);
    final teacherId = context.read<AuthProvider>().currentUser!.uid;

    try {
      await _activityService.createBatch(
        studentIds: finalStudentIds,
        title: _title.trim(),
        description: _description.trim(),
        category: _category,
        date: _date,
        teacherId: teacherId,
        targetMode: _targetMode,
        objectives: _objectives,
        duration: _duration,
        isVisibleToParent: _isVisibleToParent,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activity created successfully!'), backgroundColor: AppColors.success),
      );
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Create Activity'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            )
          else
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildTargetSection(),
                  const SizedBox(height: 16),
                  _buildDetailsSection(),
                  const SizedBox(height: 16),
                  _buildObjectivesSection(),
                  const SizedBox(height: 16),
                  _buildSettingsSection(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Georgia')),
            ]),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }

  Widget _buildTargetSection() {
    return _buildCard(
      title: 'Target Audience',
      icon: Icons.people_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Assignment Mode', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ActivityTargetMode.values.map((mode) {
              final isSelected = _targetMode == mode;
              return ChoiceChip(
                label: Text(mode == ActivityTargetMode.individual ? 'Individual' :
                            mode == ActivityTargetMode.selection ? 'Selection' : 'Full Class'),
                selected: isSelected,
                selectedColor: AppColors.primary.withValues(alpha: 0.2),
                labelStyle: TextStyle(color: isSelected ? AppColors.primary : AppColors.textPrimary, fontFamily: 'Georgia'),
                onSelected: (val) {
                  if (val) setState(() => _targetMode = mode);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          
          if (_targetMode == ActivityTargetMode.fullClass) ...[
            DropdownButtonFormField<ClassModel>(
              initialValue: _selectedClass,
              decoration: InputDecoration(
                labelText: 'Select Class',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: _teacherClasses.map((c) => DropdownMenuItem(
                value: c,
                child: Text('${c.name} (${c.studentCount} students)'),
              )).toList(),
              onChanged: (v) => setState(() => _selectedClass = v),
              validator: (v) => v == null ? 'Required' : null,
            ),
          ] else ...[
            OutlinedButton.icon(
              onPressed: _pickStudents,
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(_selectedStudents.isEmpty
                  ? 'Select Student(s)'
                  : '${_selectedStudents.length} selected'),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            if (_selectedStudents.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _selectedStudents.map((s) => Chip(
                  label: Text(s.fullName, style: const TextStyle(fontSize: 12)),
                  onDeleted: () => setState(() => _selectedStudents.remove(s)),
                  backgroundColor: AppColors.backgroundLight,
                )).toList(),
              ),
            ]
          ],
        ],
      ),
    );
  }

  Widget _buildDetailsSection() {
    return _buildCard(
      title: 'Activity Details',
      icon: Icons.edit_note,
      child: Column(
        children: [
          TextFormField(
            decoration: InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            onSaved: (v) => _title = v!,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ActivityCategory>(
            initialValue: _category,
            decoration: InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            items: ActivityCategory.values.map((c) => DropdownMenuItem(
              value: c,
              child: Row(
                children: [
                  Text(c.emoji),
                  const SizedBox(width: 8),
                  Text(c.label, style: const TextStyle(fontFamily: 'Georgia')),
                ],
              ),
            )).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _category = v);
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            decoration: InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            maxLines: 3,
            onSaved: (v) => _description = v ?? '',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: OutlinedButton.icon(
                  onPressed: _selectDate,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text('${_date.day}/${_date.month}/${_date.year} ${_date.hour}:${_date.minute.toString().padLeft(2, '0')}'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Duration (min)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  keyboardType: TextInputType.number,
                  onSaved: (v) => _duration = int.tryParse(v ?? ''),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildObjectivesSection() {
    return _buildCard(
      title: 'Pedagogical Objectives',
      icon: Icons.flag_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _objectiveCtrl,
                  decoration: InputDecoration(
                    hintText: 'Add an objective...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onSubmitted: (_) => _addObjective(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _addObjective,
                icon: const Icon(Icons.add_circle, color: AppColors.primary),
                tooltip: 'Add Objective',
              )
            ],
          ),
          if (_objectives.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _objectives.map((obj) => Chip(
                label: Text(obj, style: const TextStyle(fontSize: 12)),
                onDeleted: () => _removeObjective(obj),
                backgroundColor: AppColors.success.withValues(alpha: 0.1),
                side: BorderSide(color: AppColors.success.withValues(alpha: 0.3)),
              )).toList(),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return _buildCard(
      title: 'Settings',
      icon: Icons.settings_outlined,
      child: SwitchListTile(
        title: const Text('Visible to Parents', style: TextStyle(fontFamily: 'Georgia', fontSize: 14)),
        subtitle: const Text('Parents will be notified and can view this activity.', style: TextStyle(fontSize: 12)),
        value: _isVisibleToParent,
        activeThumbColor: AppColors.primary,
        onChanged: (v) => setState(() => _isVisibleToParent = v),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

// ─── Dialog for selecting students ─────────────────────────────────────────────

class _StudentSelectionDialog extends StatefulWidget {
  final List<UserModel> allStudents;
  final Set<String> initialSelection;
  final bool isMultiSelect;

  const _StudentSelectionDialog({
    required this.allStudents,
    required this.initialSelection,
    required this.isMultiSelect,
  });

  @override
  State<_StudentSelectionDialog> createState() => _StudentSelectionDialogState();
}

class _StudentSelectionDialogState extends State<_StudentSelectionDialog> {
  late Set<String> _selectedIds;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.initialSelection);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.allStudents
        .where((s) => s.fullName.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return AlertDialog(
      title: Text(widget.isMultiSelect ? 'Select Students' : 'Select Student', style: const TextStyle(fontFamily: 'Georgia')),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final s = filtered[i];
                  final isSelected = _selectedIds.contains(s.uid);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      backgroundImage: s.profileImageUrl != null ? NetworkImage(s.profileImageUrl!) : null,
                      child: s.profileImageUrl == null ? const Icon(Icons.person, color: AppColors.primary) : null,
                    ),
                    title: Text(s.fullName, style: const TextStyle(fontFamily: 'Georgia')),
                    subtitle: Text(s.group ?? 'No group', style: const TextStyle(fontSize: 12)),
                    trailing: widget.isMultiSelect
                        ? Checkbox(
                            value: isSelected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedIds.add(s.uid);
                                } else {
                                  _selectedIds.remove(s.uid);
                                }
                              });
                            },
                          )
                        : isSelected
                            ? const Icon(Icons.check_circle, color: AppColors.success)
                            : null,
                    onTap: () {
                      if (widget.isMultiSelect) {
                        setState(() {
                          if (isSelected) {
                            _selectedIds.remove(s.uid);
                          } else {
                            _selectedIds.add(s.uid);
                          }
                        });
                      } else {
                        Navigator.of(context).pop([s]);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        if (widget.isMultiSelect)
          ElevatedButton(
            onPressed: () {
              final result = widget.allStudents.where((s) => _selectedIds.contains(s.uid)).toList();
              Navigator.of(context).pop(result);
            },
            child: const Text('Confirm'),
          ),
      ],
    );
  }
}
