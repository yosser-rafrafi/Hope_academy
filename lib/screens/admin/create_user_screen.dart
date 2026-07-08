import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/ha_text_field.dart';
import '../../widgets/profile_photo_picker.dart';

// ─── Main screen ─────────────────────────────────────────────────────────────

class CreateUserScreen extends StatefulWidget {
  final UserModel currentUser;
  final UserModel? editUser;

  const CreateUserScreen({
    super.key,
    required this.currentUser,
    this.editUser,
  });

  bool get isEditing => editUser != null;

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // ── Step navigation ────────────────────────────────────────────────────────
  int _currentStep = 0;

  // ── Account fields ─────────────────────────────────────────────────────────
  final _firstNameCtrl   = TextEditingController();
  final _lastNameCtrl    = TextEditingController();
  final _emailCtrl       = TextEditingController();
  final _passwordCtrl    = TextEditingController();
  final _confirmCtrl     = TextEditingController();
  bool _obscurePwd       = true;
  bool _obscureConfirm   = true;

  // ── Personal / contact ─────────────────────────────────────────────────────
  final _phoneCtrl       = TextEditingController();
  final _addressCtrl     = TextEditingController();
  final _cinCtrl         = TextEditingController();
  final _nationalityCtrl = TextEditingController();
  DateTime? _birthday;
  Gender?   _gender;
  String?   _language;

  // ── Role / status ──────────────────────────────────────────────────────────
  late UserRole    _role;
  UserStatus       _status = UserStatus.newUser;
  bool             _isActive = true;
  DateTime?        _enrollmentDate;

  // ── Family (student role) ──────────────────────────────────────────────────
  final _motherNameCtrl  = TextEditingController();
  final _motherPhoneCtrl = TextEditingController();
  final _fatherNameCtrl  = TextEditingController();
  final _fatherPhoneCtrl = TextEditingController();

  // ── Medical ────────────────────────────────────────────────────────────────
  List<String>     _diagnoses   = [];
  List<String>     _allergies   = [];
  List<Medication> _medications = [];
  final _diagnosisInputCtrl  = TextEditingController();
  final _allergyInputCtrl    = TextEditingController();
  final _medNameCtrl         = TextEditingController();
  final _medDosageCtrl       = TextEditingController();
  final _additionalInfoCtrl  = TextEditingController();

  // ── Predefined diagnoses ───────────────────────────────────────────────────
  static const List<String> _predefinedDiagnoses = [
    'Autism Spectrum Disorder (ASD)',
    'Attention Deficit Hyperactivity Disorder (ADHD)',
    'Down Syndrome',
    'Cerebral Palsy',
    'Intellectual Disability',
    'Speech & Language Disorder',
    'Dyslexia',
    'Dyspraxia / DCD',
    'Hearing Impairment',
    'Visual Impairment',
    'Epilepsy',
    'Anxiety Disorder',
    'Behavioral Disorder',
    'Sensory Processing Disorder',
    'Learning Disability',
    'Physical Disability',
    'Global Developmental Delay',
  ];

  // ── Teacher-specific ───────────────────────────────────────────────────────
  final _specialityCtrl = TextEditingController();
  final _groupCtrl      = TextEditingController();
  final _salaryCtrl     = TextEditingController();
  List<String> _diplomas  = [];
  List<String> _languages = [];
  final _diplomaInputCtrl  = TextEditingController();
  final _languageInputCtrl = TextEditingController();

  // ── Profile photo ──────────────────────────────────────────────────────────
  XFile?  _pickedPhoto;
  bool    _photoUploading = false;
  double  _photoProgress  = 0;
  bool    _removePhoto    = false;
  final   _storageService = StorageService();

  bool _loading = false;
  String? _error;
  String? _success;

  List<UserRole> get _allowedRoles =>
      UserRole.values.where((r) => widget.currentUser.role.canCreateRole(r)).toList();

  // Steps vary by role
  List<_StepDef> get _steps {
    final base = [
      _StepDef('Account', Icons.person_outline, required: true),
      _StepDef('Personal', Icons.badge_outlined),
      _StepDef('Status', Icons.toggle_on_outlined),
    ];
    if (_role == UserRole.student) {
      return [...base, _StepDef('Family', Icons.family_restroom), _StepDef('Medical', Icons.medical_information_outlined)];
    }
    if (_role == UserRole.teacher) {
      return [...base, _StepDef('Professional', Icons.workspace_premium_outlined)];
    }
    return base;
  }

  int get _stepCount => _steps.length;
  bool get _isLastStep => _currentStep == _stepCount - 1;
  bool get _isFirstStep => _currentStep == 0;

  @override
  void initState() {
    super.initState();
    _role = _allowedRoles.isNotEmpty ? _allowedRoles.first : UserRole.teacher;
    if (widget.isEditing) _populateFromUser(widget.editUser!);
  }

  void _populateFromUser(UserModel u) {
    _role              = u.role;
    _status            = u.status;
    _isActive          = u.isActive;
    _birthday          = u.birthday;
    _gender            = u.gender;
    _language          = u.language;
    _enrollmentDate    = u.enrollmentDate;
    _diagnoses         = List.from(u.diagnoses);
    _allergies         = List.from(u.allergies);
    _medications       = List.from(u.medications);
    _diplomas          = List.from(u.diplomas);
    _languages         = List.from(u.languages);

    _firstNameCtrl.text    = u.firstName;
    _lastNameCtrl.text     = u.lastName;
    _emailCtrl.text        = u.email;
    _phoneCtrl.text        = u.phoneNumber    ?? '';
    _addressCtrl.text      = u.address        ?? '';
    _cinCtrl.text          = u.cin            ?? '';
    _nationalityCtrl.text  = u.nationality    ?? '';
    _motherNameCtrl.text   = u.motherName     ?? '';
    _motherPhoneCtrl.text  = u.motherPhone    ?? '';
    _fatherNameCtrl.text   = u.fatherName     ?? '';
    _fatherPhoneCtrl.text  = u.fatherPhone    ?? '';
    _additionalInfoCtrl.text = u.additionalInfo ?? '';
    _specialityCtrl.text   = u.speciality     ?? '';
    _groupCtrl.text        = u.group          ?? '';
    _salaryCtrl.text       = u.salary != null ? u.salary!.toStringAsFixed(0) : '';
  }

  @override
  void dispose() {
    for (final c in [
      _firstNameCtrl, _lastNameCtrl, _emailCtrl, _passwordCtrl, _confirmCtrl,
      _phoneCtrl, _addressCtrl, _cinCtrl, _nationalityCtrl,
      _motherNameCtrl, _motherPhoneCtrl, _fatherNameCtrl, _fatherPhoneCtrl,
      _additionalInfoCtrl, _specialityCtrl, _groupCtrl, _salaryCtrl,
      _diagnosisInputCtrl, _allergyInputCtrl, _medNameCtrl, _medDosageCtrl,
      _diplomaInputCtrl, _languageInputCtrl,
    ]) { c.dispose(); }
    super.dispose();
  }

  // ── Role change ────────────────────────────────────────────────────────────
  void _onRoleChanged(UserRole r) {
    setState(() {
      _role = r;
      _currentStep = 0;
    });
  }

  // ── Step navigation ────────────────────────────────────────────────────────
  void _goToStep(int step) {
    if (step < 0 || step >= _stepCount) return;
    FocusScope.of(context).unfocus();
    setState(() => _currentStep = step);
  }

  void _next() {
    if (_isLastStep) {
      _submit();
    } else {
      _goToStep(_currentStep + 1);
    }
  }

  void _previous() => _goToStep(_currentStep - 1);
  void _skip()     => _goToStep(_currentStep + 1);

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      _goToStep(0);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() { _loading = true; _error = null; _success = null; });

    try {
      if (widget.isEditing) {
        await _update();
      } else {
        await _create();
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _create() async {
    final auth = context.read<AuthProvider>();
    final u = await auth.createUser(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      firstName: _firstNameCtrl.text.trim(),
      lastName:  _lastNameCtrl.text.trim(),
      role: _role,
      phoneNumber:   _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      speciality:    _specialityCtrl.text.trim().isEmpty ? null : _specialityCtrl.text.trim(),
    );
    setState(() => _loading = false);
    if (u != null) {
      // Upload photo if picked
      String? photoUrl;
      if (_pickedPhoto != null) {
        photoUrl = await _uploadPhoto(u.uid);
      }
      await AuthService().updateUser(u.copyWith(
        status: _status, isActive: _isActive, birthday: _birthday, gender: _gender,
        language: _language, enrollmentDate: _enrollmentDate,
        profileImageUrl: photoUrl,
        cin: _cinCtrl.text.trim().isEmpty ? null : _cinCtrl.text.trim(),
        nationality: _nationalityCtrl.text.trim().isEmpty ? null : _nationalityCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        motherName: _motherNameCtrl.text.trim().isEmpty ? null : _motherNameCtrl.text.trim(),
        motherPhone: _motherPhoneCtrl.text.trim().isEmpty ? null : _motherPhoneCtrl.text.trim(),
        fatherName: _fatherNameCtrl.text.trim().isEmpty ? null : _fatherNameCtrl.text.trim(),
        fatherPhone: _fatherPhoneCtrl.text.trim().isEmpty ? null : _fatherPhoneCtrl.text.trim(),
        diagnoses: _diagnoses, allergies: _allergies, medications: _medications,
        diplomas: _diplomas, languages: _languages,
        group: _groupCtrl.text.trim().isEmpty ? null : _groupCtrl.text.trim(),
        salary: _salaryCtrl.text.trim().isEmpty ? null : double.tryParse(_salaryCtrl.text.trim()),
        additionalInfo: _additionalInfoCtrl.text.trim().isEmpty ? null : _additionalInfoCtrl.text.trim(),
      ));
      setState(() => _success = '${u.fullName} (${u.role.label}) created successfully.');
      _resetForm();
    } else {
      setState(() => _error = auth.createUserError ?? 'Failed to create user.');
    }
  }

  Future<void> _update() async {
    // Upload new photo or clear it
    String? photoUrl = widget.editUser!.profileImageUrl;
    if (_pickedPhoto != null) {
      photoUrl = await _uploadPhoto(widget.editUser!.uid);
    } else if (_removePhoto) {
      await _storageService.deleteProfilePhoto(widget.editUser!.uid);
      photoUrl = null;
    }

    final updated = widget.editUser!.copyWith(
      firstName: _firstNameCtrl.text.trim(),
      lastName:  _lastNameCtrl.text.trim(),
      role:      widget.currentUser.role.canCreateRole(_role) ? _role : widget.editUser!.role,
      status:    _status,
      isActive:  _isActive,
      birthday:  _birthday,
      gender:    _gender,
      language:  _language,
      enrollmentDate: _enrollmentDate,
      profileImageUrl: photoUrl,
      phoneNumber: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      address:    _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      cin:        _cinCtrl.text.trim().isEmpty ? null : _cinCtrl.text.trim(),
      nationality: _nationalityCtrl.text.trim().isEmpty ? null : _nationalityCtrl.text.trim(),
      motherName: _motherNameCtrl.text.trim().isEmpty ? null : _motherNameCtrl.text.trim(),
      motherPhone: _motherPhoneCtrl.text.trim().isEmpty ? null : _motherPhoneCtrl.text.trim(),
      fatherName: _fatherNameCtrl.text.trim().isEmpty ? null : _fatherNameCtrl.text.trim(),
      fatherPhone: _fatherPhoneCtrl.text.trim().isEmpty ? null : _fatherPhoneCtrl.text.trim(),
      diagnoses: _diagnoses, allergies: _allergies, medications: _medications,
      speciality: _specialityCtrl.text.trim().isEmpty ? null : _specialityCtrl.text.trim(),
      group:      _groupCtrl.text.trim().isEmpty ? null : _groupCtrl.text.trim(),
      diplomas:   _diplomas, languages: _languages,
      salary:     _salaryCtrl.text.trim().isEmpty ? null : double.tryParse(_salaryCtrl.text.trim()),
      additionalInfo: _additionalInfoCtrl.text.trim().isEmpty ? null : _additionalInfoCtrl.text.trim(),
    );
    await AuthService().updateUser(updated);
    setState(() { _loading = false; _success = 'User updated successfully.'; });
  }

  // ── Photo helpers ──────────────────────────────────────────────────────────

  Future<String?> _uploadPhoto(String uid) async {
    if (_pickedPhoto == null) return null;
    setState(() { _photoUploading = true; _photoProgress = 0; });
    try {
      final url = await _storageService.uploadProfilePhoto(
        uid: uid,
        file: _pickedPhoto!,
        onProgress: (p) => setState(() => _photoProgress = p),
      );
      return url;
    } finally {
      setState(() { _photoUploading = false; _photoProgress = 0; });
    }
  }

  Future<void> _pickPhoto({bool fromCamera = false}) async {
    final file = await _storageService.pickImage(fromCamera: fromCamera);
    if (file != null) {
      setState(() { _pickedPhoto = file; _removePhoto = false; });
    }
  }

  void _resetForm() {
    _firstNameCtrl.clear(); _lastNameCtrl.clear(); _emailCtrl.clear();
    _passwordCtrl.clear(); _confirmCtrl.clear(); _phoneCtrl.clear();
    _addressCtrl.clear(); _cinCtrl.clear(); _nationalityCtrl.clear();
    _motherNameCtrl.clear(); _motherPhoneCtrl.clear();
    _fatherNameCtrl.clear(); _fatherPhoneCtrl.clear();
    _specialityCtrl.clear(); _groupCtrl.clear(); _salaryCtrl.clear();
    _additionalInfoCtrl.clear();
    setState(() {
      _birthday = null; _gender = null; _language = null; _enrollmentDate = null;
      _diagnoses = []; _allergies = []; _medications = [];
      _diplomas = []; _languages = [];
      _status = UserStatus.newUser; _isActive = true;
      _role = _allowedRoles.first;
      _currentStep = 0;
      _pickedPhoto = null; _removePhoto = false;
    });
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final title = widget.isEditing
        ? 'Edit ${widget.editUser!.fullName}'
        : 'Create New User';

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontSize: 17)),
        leading: const BackButton(color: Colors.white),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton(
                onPressed: _submit,
                style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                child: Text(
                  widget.isEditing ? 'Save' : 'Create',
                  style: const TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            if (_success != null) _Banner(msg: _success!, color: AppColors.success,
                icon: Icons.check_circle_outline, onClose: () => setState(() => _success = null)),
            if (_error != null) _Banner(msg: _error!, color: AppColors.error,
                icon: Icons.error_outline, onClose: () => setState(() => _error = null)),

            // ── Stepper header ─────────────────────────────────────────────
            _buildStepperHeader(),

            // ── Page content ───────────────────────────────────────────────
            Expanded(
              child: _buildCurrentPage(),
            ),

            // ── Bottom navigation bar ──────────────────────────────────────
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  // ── Stepper header ─────────────────────────────────────────────────────────
  Widget _buildStepperHeader() {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        children: [
          // Step indicators row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_stepCount, (i) {
              final step = _steps[i];
              final isDone = i < _currentStep;
              final isCurrent = i == _currentStep;

              return Expanded(
                child: GestureDetector(
                  onTap: () => _goToStep(i),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Connector line before (except first)
                      Row(children: [
                        Expanded(
                          child: Container(
                            height: 2,
                            color: i == 0
                                ? Colors.transparent
                                : (i <= _currentStep ? AppColors.accent : Colors.white24),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? AppColors.accent
                                : isDone
                                    ? Colors.white.withAlpha(25)
                                    : Colors.white.withAlpha(12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isCurrent
                                  ? AppColors.accent
                                  : isDone ? Colors.white60 : Colors.white24,
                              width: isCurrent ? 2.5 : 1.5,
                            ),
                          ),
                          child: Center(
                            child: isDone
                                ? const Icon(Icons.check, size: 19, color: Colors.white)
                                : Icon(step.icon, size: 19,
                                    color: isCurrent ? Colors.white : Colors.white54),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 2,
                            color: i == _stepCount - 1
                                ? Colors.transparent
                                : (i < _currentStep ? AppColors.accent : Colors.white24),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 7),
                      Text(
                        step.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 11,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCurrent
                              ? AppColors.accent
                              : isDone ? Colors.white : Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _stepCount > 1 ? _currentStep / (_stepCount - 1) : 1.0,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Step ${_currentStep + 1} of $_stepCount — ${_steps[_currentStep].label}',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 12,
              color: Colors.white.withAlpha(180),
            ),
          ),
        ],
      ),
    );
  }

  // ── Current page ───────────────────────────────────────────────────────────
  Widget _buildCurrentPage() {
    final pages = <Widget>[
      _buildAccountTab(),
      _buildPersonalTab(),
      _buildStatusTab(),
    ];
    if (_role == UserRole.student) {
      pages.add(_buildFamilyTab());
      pages.add(_buildMedicalTab());
    } else if (_role == UserRole.teacher) {
      pages.add(_buildProfessionalTab());
    }
    final idx = _currentStep.clamp(0, pages.length - 1);
    return pages[idx];
  }

  // ── Bottom navigation bar ──────────────────────────────────────────────────
  Widget _buildBottomNav() {
    final isRequired = _steps[_currentStep].required;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          // Back button
          if (!_isFirstStep)
            OutlinedButton.icon(
              onPressed: _previous,
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Back', style: TextStyle(fontFamily: 'Georgia')),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )
          else
            const SizedBox(width: 0),

          const Spacer(),

          // Skip button (only for non-required, non-last steps)
          if (!isRequired && !_isLastStep) ...[
            TextButton(
              onPressed: _skip,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Skip', style: TextStyle(fontFamily: 'Georgia', fontSize: 14)),
                SizedBox(width: 4),
                Icon(Icons.skip_next, size: 16),
              ]),
            ),
            const SizedBox(width: 8),
          ],

          // Continue / Submit button
          ElevatedButton.icon(
            onPressed: _loading ? null : _next,
            icon: _loading
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(_isLastStep ? Icons.check_circle_outline : Icons.arrow_forward, size: 18),
            label: Text(
              _isLastStep
                  ? (widget.isEditing ? 'Save Changes' : 'Create User')
                  : 'Continue',
              style: const TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isLastStep ? AppColors.success : AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(150, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 1: Account ──────────────────────────────────────────────────────────
  Widget _buildAccountTab() {
    return _TabScroll(children: [

      // ── Profile Photo ──────────────────────────────────────────────────────
      _SectionTitle('Profile Photo'),
      const SizedBox(height: 16),
      Center(
        child: ProfilePhotoPicker(
          currentUrl: _removePhoto ? null : widget.editUser?.profileImageUrl,
          localFile: _pickedPhoto,
          role: _role,
          radius: 52,
          uploading: _photoUploading,
          uploadProgress: _photoProgress,
          onPickGallery: () => _pickPhoto(fromCamera: false),
          onPickCamera: () => _pickPhoto(fromCamera: true),
          onRemove: (widget.editUser?.profileImageUrl != null || _pickedPhoto != null)
              ? () => setState(() { _pickedPhoto = null; _removePhoto = true; })
              : null,
        ),
      ),
      const SizedBox(height: 28),

      // ── Role ──────────────────────────────────────────────────────────────
      _SectionTitle('Role'),
      const SizedBox(height: 12),
      SizedBox(
        height: 100,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _allowedRoles.map((r) {
            final sel = _role == r;
            final (color, icon) = _roleStyle(r);
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: r != _allowedRoles.last ? 10 : 0,
                ),
                child: GestureDetector(
                  onTap: () => _onRoleChanged(r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: sel ? color.withAlpha(20) : AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: sel ? color : AppColors.divider,
                          width: sel ? 2 : 1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: sel ? color.withAlpha(35) : AppColors.backgroundLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, color: color, size: 22),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          r.shortLabel,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                            color: sel ? color : AppColors.textSecondary,
                            fontFamily: 'Georgia',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),

      const SizedBox(height: 28),

      // ── Full Name ──────────────────────────────────────────────────────────
      _SectionTitle('Full Name'),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: HaTextField(
            controller: _firstNameCtrl, label: 'First Name',
            prefixIcon: Icons.person_outline,
            textInputAction: TextInputAction.next,
            validator: (v) => v == null || v.isEmpty ? 'Required' : null)),
        const SizedBox(width: 14),
        Expanded(child: HaTextField(
            controller: _lastNameCtrl, label: 'Last Name',
            textInputAction: TextInputAction.next,
            validator: (v) => v == null || v.isEmpty ? 'Required' : null)),
      ]),

      const SizedBox(height: 28),

      // ── Credentials ────────────────────────────────────────────────────────
      _SectionTitle('Account Credentials'),
      const SizedBox(height: 12),
      HaTextField(controller: _emailCtrl, label: 'Email Address',
          hint: 'user@hopeacademy.eg', prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          enabled: !widget.isEditing,
          textInputAction: TextInputAction.next,
          validator: (v) {
            if (v == null || v.isEmpty) return 'Required';
            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) return 'Invalid email';
            return null;
          }),
      if (!widget.isEditing) ...[
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: HaTextField(
              controller: _passwordCtrl, label: 'Password',
              prefixIcon: Icons.lock_outline, obscureText: _obscurePwd,
              textInputAction: TextInputAction.next,
              suffixWidget: GestureDetector(
                onTap: () => setState(() => _obscurePwd = !_obscurePwd),
                child: Icon(_obscurePwd ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.textSecondary, size: 19),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v.length < 6) return 'Minimum 6 characters';
                return null;
              })),
          const SizedBox(width: 14),
          Expanded(child: HaTextField(
              controller: _confirmCtrl, label: 'Confirm Password',
              prefixIcon: Icons.lock_outline, obscureText: _obscureConfirm,
              textInputAction: TextInputAction.done,
              suffixWidget: GestureDetector(
                onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                child: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.textSecondary, size: 19),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v != _passwordCtrl.text) return 'Passwords do not match';
                return null;
              })),
        ]),
      ],

      const SizedBox(height: 28),

      // ── Preferences ────────────────────────────────────────────────────────
      _SectionTitle('Preferences'),
      const SizedBox(height: 12),
      _DropdownField<String>(
        label: 'Interface Language',
        icon: Icons.language,
        value: _language,
        items: const {'en': 'English', 'fr': 'Français', 'ar': 'العربية'},
        onChanged: (v) => setState(() => _language = v),
      ),
    ]);
  }

  // ── Tab 2: Personal ─────────────────────────────────────────────────────────
  Widget _buildPersonalTab() {
    return _TabScroll(children: [

      // ── Identity ──────────────────────────────────────────────────────────
      _SectionTitle('Identity'),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _DropdownField<Gender>(
          label: 'Gender',
          icon: Icons.wc,
          value: _gender,
          items: {for (final g in Gender.values) g: g.label},
          onChanged: (v) => setState(() => _gender = v),
        )),
        const SizedBox(width: 14),
        Expanded(child: _DateField(
          label: 'Date of Birth',
          icon: Icons.cake_outlined,
          value: _birthday,
          onChanged: (d) => setState(() => _birthday = d),
          lastDate: DateTime.now(),
        )),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: HaTextField(controller: _cinCtrl, label: 'CIN / National ID',
            prefixIcon: Icons.badge_outlined, textInputAction: TextInputAction.next)),
        const SizedBox(width: 14),
        Expanded(child: _NationalityField(
          controller: _nationalityCtrl,
          onChanged: (v) => setState(() {}),
        )),
      ]),

      const SizedBox(height: 28),

      // ── Contact ───────────────────────────────────────────────────────────
      _SectionTitle('Contact'),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: HaTextField(controller: _phoneCtrl, label: 'Phone Number',
            prefixIcon: Icons.phone_outlined, keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next)),
        const SizedBox(width: 14),
        Expanded(child: HaTextField(controller: _addressCtrl, label: 'Address',
            prefixIcon: Icons.home_outlined, maxLines: 1,
            textInputAction: TextInputAction.next)),
      ]),
    ]);
  }

  // ── Tab 3: Status ───────────────────────────────────────────────────────────
  Widget _buildStatusTab() {
    return _TabScroll(children: [
      _SectionTitle('Account Status'),
      const SizedBox(height: 12),
      // Active/Inactive toggle
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (_isActive ? AppColors.success : AppColors.error).withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _isActive ? Icons.check_circle_outline : Icons.block_outlined,
              color: _isActive ? AppColors.success : AppColors.error,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                    fontFamily: 'Georgia', fontWeight: FontWeight.bold, fontSize: 14,
                    color: _isActive ? AppColors.success : AppColors.error)),
            Text(_isActive ? 'User can sign in to the platform' : 'User cannot sign in',
                style: const TextStyle(fontFamily: 'Georgia', fontSize: 12, color: AppColors.textSecondary)),
          ])),
          Switch(
            value: _isActive,
            thumbColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? AppColors.success : null,
            ),
            onChanged: (v) => setState(() => _isActive = v),
          ),
        ]),
      ),
      const SizedBox(height: 24),
      _SectionTitle('Progress Status'),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10, runSpacing: 10,
        children: UserStatus.values.map((s) {
          final sel = _status == s;
          final color = _statusColor(s);
          return GestureDetector(
            onTap: () => setState(() => _status = s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: sel ? color.withAlpha(30) : AppColors.background,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? color : AppColors.divider, width: sel ? 2 : 1),
              ),
              child: Text(s.label,
                  style: TextStyle(
                      fontFamily: 'Georgia', fontSize: 13,
                      fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                      color: sel ? color : AppColors.textSecondary)),
            ),
          );
        }).toList(),
      ),
      const SizedBox(height: 24),
      _SectionTitle('Dates'),
      const SizedBox(height: 12),
      _DateField(
        label: 'Enrollment Date',
        icon: Icons.event_outlined,
        value: _enrollmentDate,
        onChanged: (d) => setState(() => _enrollmentDate = d),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      ),
      const SizedBox(height: 14),
      HaTextField(controller: _additionalInfoCtrl, label: 'Additional Information',
          prefixIcon: Icons.notes_outlined, maxLines: 3),
    ]);
  }

  // ── Tab 4: Family (student) ──────────────────────────────────────────────────
  Widget _buildFamilyTab() {
    return _TabScroll(children: [
      _SectionTitle('Mother'),
      const SizedBox(height: 12),
      HaTextField(controller: _motherNameCtrl, label: "Mother's Full Name",
          prefixIcon: Icons.person_outline, textInputAction: TextInputAction.next),
      const SizedBox(height: 14),
      HaTextField(controller: _motherPhoneCtrl, label: "Mother's Phone",
          prefixIcon: Icons.phone_outlined, keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next),
      const SizedBox(height: 24),
      _SectionTitle('Father'),
      const SizedBox(height: 12),
      HaTextField(controller: _fatherNameCtrl, label: "Father's Full Name",
          prefixIcon: Icons.person_outline, textInputAction: TextInputAction.next),
      const SizedBox(height: 14),
      HaTextField(controller: _fatherPhoneCtrl, label: "Father's Phone",
          prefixIcon: Icons.phone_outlined, keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next),
    ]);
  }

  // ── Tab 5: Medical (student) ─────────────────────────────────────────────────
  Widget _buildMedicalTab() {
    return _TabScroll(children: [
      _SectionTitle('Diagnoses'),
      const SizedBox(height: 12),
      _MultiSelectChipField(
        predefinedItems: _predefinedDiagnoses,
        selectedItems: _diagnoses,
        hint: 'Add custom diagnosis…',
        icon: Icons.medical_information_outlined,
        chipColor: AppColors.primary,
        onChanged: (updated) => setState(() => _diagnoses = updated),
      ),
      const SizedBox(height: 24),
      _SectionTitle('Allergies'),
      const SizedBox(height: 12),
      _ChipInput(
        controller: _allergyInputCtrl,
        items: _allergies,
        hint: 'e.g. Penicillin, Peanuts',
        icon: Icons.warning_amber_outlined,
        chipColor: AppColors.error,
        onAdd: (v) => setState(() => _allergies.add(v)),
        onRemove: (v) => setState(() => _allergies.remove(v)),
      ),
      const SizedBox(height: 24),
      _SectionTitle('Medications'),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: HaTextField(controller: _medNameCtrl, label: 'Medication name',
            prefixIcon: Icons.medication_outlined, textInputAction: TextInputAction.next)),
        const SizedBox(width: 10),
        Expanded(child: HaTextField(controller: _medDosageCtrl, label: 'Dosage',
            prefixIcon: Icons.scale_outlined, textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _addMedication())),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _addMedication,
          icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 28),
          tooltip: 'Add medication',
        ),
      ]),
      if (_medications.isNotEmpty) ...[
        const SizedBox(height: 10),
        ...(_medications.map((m) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(children: [
            const Icon(Icons.medication, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text('${m.name} — ${m.dosage}',
                style: const TextStyle(fontFamily: 'Georgia', fontSize: 13))),
            GestureDetector(
              onTap: () => setState(() => _medications.remove(m)),
              child: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
            ),
          ]),
        ))),
      ],
    ]);
  }

  // ── Tab 4: Professional (teacher) ───────────────────────────────────────────
  Widget _buildProfessionalTab() {
    return _TabScroll(children: [
      _SectionTitle('Teaching Profile'),
      const SizedBox(height: 12),
      HaTextField(controller: _specialityCtrl, label: 'Speciality',
          prefixIcon: Icons.workspace_premium_outlined, textInputAction: TextInputAction.next,
          hint: 'e.g. Speech Therapy, Occupational Therapy'),
      const SizedBox(height: 14),
      HaTextField(controller: _groupCtrl, label: 'Assigned Class / Group',
          prefixIcon: Icons.class_outlined, textInputAction: TextInputAction.next),
      const SizedBox(height: 14),
      HaTextField(controller: _salaryCtrl, label: 'Monthly Salary (EGP)',
          prefixIcon: Icons.payments_outlined, keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next),
      const SizedBox(height: 24),
      _SectionTitle('Diplomas & Certifications'),
      const SizedBox(height: 12),
      _ChipInput(
        controller: _diplomaInputCtrl,
        items: _diplomas,
        hint: 'e.g. B.Sc. Special Education',
        icon: Icons.school_outlined,
        chipColor: AppColors.success,
        onAdd: (v) => setState(() => _diplomas.add(v)),
        onRemove: (v) => setState(() => _diplomas.remove(v)),
      ),
      const SizedBox(height: 24),
      _SectionTitle('Languages Spoken'),
      const SizedBox(height: 12),
      _ChipInput(
        controller: _languageInputCtrl,
        items: _languages,
        hint: 'e.g. Arabic, English, French',
        icon: Icons.record_voice_over_outlined,
        chipColor: AppColors.primary,
        onAdd: (v) => setState(() => _languages.add(v)),
        onRemove: (v) => setState(() => _languages.remove(v)),
      ),
    ]);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  void _addMedication() {
    final name = _medNameCtrl.text.trim();
    final dosage = _medDosageCtrl.text.trim();
    if (name.isEmpty || dosage.isEmpty) return;
    setState(() {
      _medications.add(Medication(name: name, dosage: dosage));
      _medNameCtrl.clear();
      _medDosageCtrl.clear();
    });
  }

  (Color, IconData) _roleStyle(UserRole r) {
    switch (r) {
      case UserRole.admin:    return (AppColors.primary, Icons.admin_panel_settings);
      case UserRole.subAdmin: return (const Color(0xFF6A0DAD), Icons.manage_accounts);
      case UserRole.teacher:  return (AppColors.success, Icons.school);
      case UserRole.student:  return (const Color(0xFFB8860B), Icons.family_restroom);
    }
  }

  Color _statusColor(UserStatus s) {
    switch (s) {
      case UserStatus.newUser:     return AppColors.primary;
      case UserStatus.notStarted:  return AppColors.textSecondary;
      case UserStatus.inProgress:  return AppColors.success;
      case UserStatus.holding:     return AppColors.warning;
      case UserStatus.completed:   return const Color(0xFF0D6E3A);
      case UserStatus.blocked:     return AppColors.error;
    }
  }
}

// ─── Step definition ─────────────────────────────────────────────────────────

class _StepDef {
  final String label;
  final IconData icon;
  final bool required;
  const _StepDef(this.label, this.icon, {this.required = false});
}

// ─── Reusable sub-widgets ────────────────────────────────────────────────────

class _TabScroll extends StatelessWidget {
  final List<Widget> children;
  const _TabScroll({required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ),
    );
  }
}

// Keep _SectionTitle for inline section labels
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 3, height: 18,
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.bold,
          color: AppColors.textSecondary, fontFamily: 'Georgia')),
    ]);
  }
}

class _Banner extends StatelessWidget {
  final String msg;
  final Color color;
  final IconData icon;
  final VoidCallback onClose;

  const _Banner({required this.msg, required this.color, required this.icon, required this.onClose});

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
        Expanded(child: Text(msg, style: TextStyle(color: color, fontSize: 13, fontFamily: 'Georgia'))),
        GestureDetector(onTap: onClose, child: Icon(Icons.close, color: color, size: 16)),
      ]),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final IconData icon;
  final T? value;
  final Map<T, String> items;
  final void Function(T?) onChanged;

  const _DropdownField({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 19, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.divider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      ),
      style: const TextStyle(fontFamily: 'Georgia', fontSize: 14, color: AppColors.textPrimary),
      onChanged: onChanged,
      items: items.entries.map((e) => DropdownMenuItem<T>(
        value: e.key,
        child: Text(e.value, style: const TextStyle(fontFamily: 'Georgia', fontSize: 14)),
      )).toList(),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final IconData icon;
  final DateTime? value;
  final DateTime? lastDate;
  final void Function(DateTime) onChanged;

  const _DateField({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.lastDate,
  });

  @override
  Widget build(BuildContext context) {
    final displayText = value != null
        ? '${value!.day.toString().padLeft(2,'0')}/${value!.month.toString().padLeft(2,'0')}/${value!.year}'
        : 'Select date';

    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime(2000),
          firstDate: DateTime(1940),
          lastDate: lastDate ?? DateTime(2100),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(primary: AppColors.primary),
            ),
            child: child!,
          ),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider, width: 1.5),
        ),
        child: Row(children: [
          Icon(icon, size: 19, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Georgia')),
            const SizedBox(height: 2),
            Text(displayText, style: TextStyle(
                fontSize: 14, fontFamily: 'Georgia',
                color: value != null ? AppColors.textPrimary : AppColors.textSecondary)),
          ])),
          const Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.textSecondary),
        ]),
      ),
    );
  }
}

class _ChipInput extends StatelessWidget {
  final TextEditingController controller;
  final List<String> items;
  final String hint;
  final IconData icon;
  final Color chipColor;
  final void Function(String) onAdd;
  final void Function(String) onRemove;

  const _ChipInput({
    required this.controller,
    required this.items,
    required this.hint,
    required this.icon,
    required this.chipColor,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: TextField(
          controller: controller,
          style: const TextStyle(fontFamily: 'Georgia', fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 18, color: AppColors.textSecondary),
            filled: true, fillColor: AppColors.background,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.divider)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.divider)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) { onAdd(v.trim()); controller.clear(); }
          },
        )),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () {
            if (controller.text.trim().isNotEmpty) {
              onAdd(controller.text.trim());
              controller.clear();
            }
          },
          icon: Icon(Icons.add_circle, color: chipColor, size: 28),
          tooltip: 'Add',
        ),
      ]),
      if (items.isNotEmpty) ...[
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 6,
          children: items.map((item) => Chip(
            label: Text(item, style: TextStyle(
                fontFamily: 'Georgia', fontSize: 12,
                color: chipColor, fontWeight: FontWeight.w600)),
            backgroundColor: chipColor.withAlpha(20),
            side: BorderSide(color: chipColor.withAlpha(76)),
            deleteIconColor: chipColor,
            onDeleted: () => onRemove(item),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          )).toList(),
        ),
      ],
    ]);
  }
}

// ─── Multi-Select Chip Field ─────────────────────────────────────────────────
/// Shows a grid of predefined options to tap-select, plus a text field to add
/// custom entries that don't exist in the predefined list.
class _MultiSelectChipField extends StatefulWidget {
  final List<String> predefinedItems;
  final List<String> selectedItems;
  final String hint;
  final IconData icon;
  final Color chipColor;
  final void Function(List<String>) onChanged;

  const _MultiSelectChipField({
    required this.predefinedItems,
    required this.selectedItems,
    required this.hint,
    required this.icon,
    required this.chipColor,
    required this.onChanged,
  });

  @override
  State<_MultiSelectChipField> createState() => _MultiSelectChipFieldState();
}

class _MultiSelectChipFieldState extends State<_MultiSelectChipField> {
  final _customCtrl = TextEditingController();
  bool _showAll = false;

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  void _toggle(String item) {
    final updated = List<String>.from(widget.selectedItems);
    if (updated.contains(item)) {
      updated.remove(item);
    } else {
      updated.add(item);
    }
    widget.onChanged(updated);
  }

  void _addCustom() {
    final v = _customCtrl.text.trim();
    if (v.isEmpty) return;
    if (!widget.selectedItems.contains(v)) {
      widget.onChanged([...widget.selectedItems, v]);
    }
    _customCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    // Custom entries = selected items not in predefined list
    final customSelected = widget.selectedItems
        .where((s) => !widget.predefinedItems.contains(s))
        .toList();

    final displayList =
        _showAll ? widget.predefinedItems : widget.predefinedItems.take(8).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Predefined options grid ──────────────────────────────────────────
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ...displayList.map((item) {
            final selected = widget.selectedItems.contains(item);
            return GestureDetector(
              onTap: () => _toggle(item),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? widget.chipColor.withAlpha(25)
                      : AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? widget.chipColor
                        : AppColors.divider,
                    width: selected ? 1.8 : 1,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (selected) ...[
                    Icon(Icons.check_circle, size: 14, color: widget.chipColor),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    item,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      color: selected ? widget.chipColor : AppColors.textSecondary,
                    ),
                  ),
                ]),
              ),
            );
          }),
          // Show more / less toggle
          if (widget.predefinedItems.length > 8)
            GestureDetector(
              onTap: () => setState(() => _showAll = !_showAll),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withAlpha(80)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    _showAll ? Icons.expand_less : Icons.expand_more,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _showAll ? 'Show less' : '+ ${widget.predefinedItems.length - 8} more',
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ]),
              ),
            ),
        ],
      ),

      const SizedBox(height: 14),

      // ── Custom / "Other" entry ───────────────────────────────────────────
      Row(children: [
        Expanded(
          child: TextField(
            controller: _customCtrl,
            style: const TextStyle(fontFamily: 'Georgia', fontSize: 14),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _addCustom(),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: const TextStyle(
                  fontFamily: 'Georgia', fontSize: 13, color: AppColors.textSecondary),
              prefixIcon:
                  Icon(widget.icon, size: 18, color: AppColors.textSecondary),
              suffixText: 'Other',
              suffixStyle: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 11,
                  color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.background,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.divider)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.divider)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: widget.chipColor, width: 1.5)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _addCustom,
          icon: Icon(Icons.add_circle, color: widget.chipColor, size: 28),
          tooltip: 'Add custom',
        ),
      ]),

      // ── Custom items chips ───────────────────────────────────────────────
      if (customSelected.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: customSelected
              .map((item) => Chip(
                    label: Text(item,
                        style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 12,
                            color: widget.chipColor,
                            fontWeight: FontWeight.w600)),
                    backgroundColor: widget.chipColor.withAlpha(20),
                    side: BorderSide(color: widget.chipColor.withAlpha(76)),
                    deleteIconColor: widget.chipColor,
                    onDeleted: () => _toggle(item),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ))
              .toList(),
        ),
      ],

      // ── Summary of selected count ────────────────────────────────────────
      if (widget.selectedItems.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text(
          '${widget.selectedItems.length} selected',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 11,
            color: widget.chipColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ]);
  }
}

// ─── Nationality Autocomplete Field ─────────────────────────────────────────
/// Text field with autocomplete from a predefined list of nationalities.
/// User can also type freely any value not in the list.
class _NationalityField extends StatelessWidget {
  final TextEditingController controller;
  final void Function(String) onChanged;

  static const List<String> _nationalities = [
    'Egyptian', 'Saudi', 'Emirati', 'Qatari', 'Kuwaiti', 'Bahraini', 'Omani',
    'Jordanian', 'Lebanese', 'Syrian', 'Iraqi', 'Libyan', 'Tunisian', 'Algerian',
    'Moroccan', 'Sudanese', 'Yemeni', 'Palestinian', 'Somali', 'Mauritanian',
    'American', 'British', 'French', 'German', 'Italian', 'Spanish', 'Dutch',
    'Belgian', 'Swiss', 'Austrian', 'Swedish', 'Norwegian', 'Danish', 'Finnish',
    'Russian', 'Ukrainian', 'Polish', 'Turkish', 'Iranian', 'Pakistani', 'Indian',
    'Bangladeshi', 'Sri Lankan', 'Filipino', 'Indonesian', 'Malaysian', 'Chinese',
    'Japanese', 'Korean', 'Canadian', 'Australian', 'South African', 'Nigerian',
    'Kenyan', 'Ethiopian', 'Ghanaian', 'Senegalese', 'Other',
  ];

  const _NationalityField({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: controller.text),
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) return const [];
        final query = textEditingValue.text.toLowerCase();
        return _nationalities.where(
          (n) => n.toLowerCase().contains(query),
        );
      },
      onSelected: (String selection) {
        controller.text = selection;
        onChanged(selection);
      },
      fieldViewBuilder: (context, fieldController, focusNode, onFieldSubmitted) {
        // Sync external controller text when populated from edit
        if (fieldController.text.isEmpty && controller.text.isNotEmpty) {
          fieldController.text = controller.text;
        }
        fieldController.addListener(() {
          controller.text = fieldController.text;
          onChanged(fieldController.text);
        });
        return TextField(
          controller: fieldController,
          focusNode: focusNode,
          textInputAction: TextInputAction.next,
          style: const TextStyle(fontFamily: 'Georgia', fontSize: 14),
          decoration: InputDecoration(
            labelText: 'Nationality',
            labelStyle: const TextStyle(
                fontFamily: 'Georgia', fontSize: 14, color: AppColors.textSecondary),
            prefixIcon: const Icon(Icons.flag_outlined,
                size: 19, color: AppColors.textSecondary),
            suffixIcon: const Icon(Icons.arrow_drop_down,
                size: 20, color: AppColors.textSecondary),
            filled: true,
            fillColor: AppColors.background,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.divider)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.divider)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 2)),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: AppColors.divider),
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 11),
                      child: Row(children: [
                        const Icon(Icons.flag_outlined,
                            size: 15, color: AppColors.textSecondary),
                        const SizedBox(width: 10),
                        Text(option,
                            style: const TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 13,
                                color: AppColors.textPrimary)),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
