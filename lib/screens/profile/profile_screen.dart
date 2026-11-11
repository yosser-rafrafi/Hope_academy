import '../../widgets/kid_ui.dart';
import '../shared/portfolio_screen.dart';
import 'package:flutter/material.dart';
import '../../widgets/language_selector.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/storage_service.dart';
import '../../widgets/profile_photo_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _editMode = false;
  bool _saving = false;
  bool _uploadingPhoto = false;
  double _uploadProgress = 0;
  XFile? _localPhoto;

  // Controllers — personal
  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _cinCtrl;
  late TextEditingController _nationalityCtrl;
  DateTime? _birthday;
  Gender? _gender;

  // Controllers — professional
  late TextEditingController _specialityCtrl;
  late TextEditingController _groupCtrl;
  late TextEditingController _addInfoCtrl;

  final StorageService _storage = StorageService();

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser!;
    _initControllers(user);
    _tabController = TabController(
      length: _tabCount(user),
      vsync: this,
    );
  }

  int _tabCount(UserModel u) {
    if (u.role == UserRole.student) return 3; // Personal | Family | Medical
    if (u.role == UserRole.teacher) return 2; // Personal | Professional
    return 2; // Personal | Professional (admin/subAdmin)
  }

  void _initControllers(UserModel u) {
    _firstNameCtrl = TextEditingController(text: u.firstName);
    _lastNameCtrl  = TextEditingController(text: u.lastName);
    _phoneCtrl     = TextEditingController(text: u.phoneNumber ?? '');
    _addressCtrl   = TextEditingController(text: u.address ?? '');
    _cinCtrl       = TextEditingController(text: u.cin ?? '');
    _nationalityCtrl = TextEditingController(text: u.nationality ?? '');
    _specialityCtrl  = TextEditingController(text: u.speciality ?? '');
    _groupCtrl       = TextEditingController(text: u.group ?? '');
    _addInfoCtrl     = TextEditingController(text: u.additionalInfo ?? '');
    _birthday = u.birthday;
    _gender   = u.gender;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _cinCtrl.dispose();
    _nationalityCtrl.dispose();
    _specialityCtrl.dispose();
    _groupCtrl.dispose();
    _addInfoCtrl.dispose();
    super.dispose();
  }

  // ─── Role color ────────────────────────────────────────────────────────────

  Color _roleColor(UserRole r) {
    switch (r) {
      case UserRole.admin:    return AppColors.primary;
      case UserRole.subAdmin: return const Color(0xFF6A0DAD);
      case UserRole.teacher:  return AppColors.success;
      case UserRole.student:  return AppColors.accent;
    }
  }

  // ─── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser!;
    setState(() => _saving = true);

    try {
      String? newPhotoUrl = user.profileImageUrl;

      // Upload photo if picked
      if (_localPhoto != null) {
        setState(() { _uploadingPhoto = true; _uploadProgress = 0; });
        newPhotoUrl = await _storage.uploadProfilePhoto(
          uid: user.uid,
          file: _localPhoto!,
          onProgress: (p) => setState(() => _uploadProgress = p),
        );
        setState(() { _uploadingPhoto = false; _localPhoto = null; });
      }

      final updated = user.copyWith(
        firstName:      _firstNameCtrl.text.trim(),
        lastName:       _lastNameCtrl.text.trim(),
        phoneNumber:    _phoneCtrl.text.trim(),
        address:        _addressCtrl.text.trim(),
        cin:            _cinCtrl.text.trim(),
        nationality:    _nationalityCtrl.text.trim(),
        birthday:       _birthday,
        gender:         _gender,
        speciality:     _specialityCtrl.text.trim(),
        group:          _groupCtrl.text.trim(),
        additionalInfo: _addInfoCtrl.text.trim(),
        profileImageUrl: newPhotoUrl,
      );

      await auth.updateCurrentUserProfile(updated);
      if (mounted) {
        setState(() { _editMode = false; _saving = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _cancelEdit() {
    final user = context.read<AuthProvider>().currentUser!;
    _initControllers(user);
    setState(() { _editMode = false; _localPhoto = null; });
  }

  Future<void> _pickPhoto({bool fromCamera = false}) async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    final file = await _storage.pickImage(fromCamera: fromCamera);
    if (file == null) return;

    setState(() {
      _localPhoto = file;
      _uploadingPhoto = true;
      _uploadProgress = 0;
    });

    try {
      final photoUrl = await _storage.uploadProfilePhoto(
        uid: user.uid,
        file: file,
        onProgress: (p) => setState(() => _uploadProgress = p),
      );

      final updated = user.copyWith(profileImageUrl: photoUrl);
      await auth.updateCurrentUserProfile(updated);

      if (mounted) {
        setState(() {
          _uploadingPhoto = false;
          _localPhoto = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploadingPhoto = false;
          _localPhoto = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading photo: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _removePhoto() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    try {
      await _storage.deleteProfilePhoto(user.uid);
      final updated = user.copyWith(profileImageUrl: '');
      await auth.updateCurrentUserProfile(updated);
      if (mounted) {
        setState(() => _localPhoto = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo removed'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing photo: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ─── Change email dialog ───────────────────────────────────────────────────

  void _showChangeEmailDialog(UserModel user) {
    final newEmailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;
    String? error;
    bool obscure = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.email_outlined, color: AppColors.primary, size: 22),
            SizedBox(width: 10),
            Text('Change Email', style: TextStyle(fontSize: 18)),
          ]),
          content: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                'Current: ${user.email}',
                style: TextStyle(
                    fontSize: 12, color: context.textSecondary),
              ),
              const SizedBox(height: 16),
              if (error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Text(error!,
                      style: const TextStyle(
                          color: AppColors.error, fontSize: 12)),
                ),
              TextFormField(
                controller: newEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'New email address',
                  prefixIcon: Icon(Icons.alternate_email, size: 18),
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                    return 'Invalid email';
                  }
                  if (v.trim() == user.email) {
                    return 'Same as current email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'Current password (to confirm)',
                  prefixIcon:
                      const Icon(Icons.lock_outline, size: 18),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  suffixIcon: GestureDetector(
                    onTap: () => setLocal(() => obscure = !obscure),
                    child: Icon(obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                        size: 18),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              Text(
                'A verification link will be sent to the new address.',
                style: TextStyle(
                    fontSize: 11, color: context.textSecondary),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setLocal(() { loading = true; error = null; });
                      final err =
                          await context.read<AuthProvider>().updateEmail(
                                newEmail: newEmailCtrl.text.trim(),
                                currentPassword: passwordCtrl.text,
                              );
                      if (!ctx.mounted) return;
                      if (err == null) {
                        Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Verification email sent. Click the link to confirm.'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } else {
                        setLocal(() { loading = false; error = err; });
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Update Email'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Change password dialog ────────────────────────────────────────────────

  void _showChangePasswordDialog(UserModel user) {
    final currentPwdCtrl = TextEditingController();
    final newPwdCtrl     = TextEditingController();
    final confirmCtrl    = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;
    String? error;
    bool obscureCurrent = true;
    bool obscureNew = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.lock_reset_outlined,
                color: AppColors.primary, size: 22),
            SizedBox(width: 10),
            Text('Change Password',
                style: TextStyle(fontSize: 18)),
          ]),
          content: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Text(error!,
                      style: const TextStyle(
                          color: AppColors.error, fontSize: 12)),
                ),
              // Current password
              TextFormField(
                controller: currentPwdCtrl,
                obscureText: obscureCurrent,
                decoration: InputDecoration(
                  labelText: 'Current password',
                  prefixIcon:
                      const Icon(Icons.lock_outline, size: 18),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  suffixIcon: GestureDetector(
                    onTap: () =>
                        setLocal(() => obscureCurrent = !obscureCurrent),
                    child: Icon(obscureCurrent
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                        size: 18),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              // New password
              TextFormField(
                controller: newPwdCtrl,
                obscureText: obscureNew,
                decoration: InputDecoration(
                  labelText: 'New password',
                  prefixIcon:
                      const Icon(Icons.lock_open_outlined, size: 18),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  suffixIcon: GestureDetector(
                    onTap: () =>
                        setLocal(() => obscureNew = !obscureNew),
                    child: Icon(obscureNew
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                        size: 18),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length < 6) return 'Minimum 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              // Confirm
              TextFormField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                  prefixIcon:
                      Icon(Icons.lock_outline, size: 18),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                ),
                validator: (v) {
                  if (v != newPwdCtrl.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setLocal(() { loading = true; error = null; });
                      final err =
                          await context.read<AuthProvider>().changePassword(
                                currentPassword: currentPwdCtrl.text,
                                newPassword: newPwdCtrl.text,
                              );
                      if (!ctx.mounted) return;
                      if (err == null) {
                        Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Password changed successfully.'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } else {
                        setLocal(() { loading = false; error = err; });
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Update Password'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendPasswordReset() async {
    final user = context.read<AuthProvider>().currentUser!;
    final ok = await context.read<AuthProvider>().sendPasswordReset(user.email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Password reset email sent to ${user.email}'
          : 'Failed to send reset email'),
      backgroundColor: ok ? AppColors.success : AppColors.error,
    ));
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth  = context.watch<AuthProvider>();
    final user  = auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    final color     = _roleColor(user.role);
    final canEdit   = user.role != UserRole.student;
    final tabs      = _buildTabs(user);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: color,
            foregroundColor: Colors.white,
            actions: [
              if (user.role == UserRole.student)
                IconButton(
                  icon: const Icon(Icons.auto_awesome_rounded),
                  tooltip: 'My portfolio',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PortfolioScreen(student: user, viewer: user),
                    ),
                  ),
                ),
              if (canEdit && !_editMode)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit Profile',
                  onPressed: () => setState(() => _editMode = true),
                ),
              if (_editMode) ...[
                TextButton(
                  onPressed: _saving ? null : _cancelEdit,
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                ),
                TextButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeader(user, color),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              tabs: tabs,
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: _buildTabViews(user)
              .map((w) => FadeSlideIn(child: w))
              .toList(),
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(UserModel user, Color color) {
    return PlayfulHeader(
      borderRadius: BorderRadius.zero,
      gradient: LinearGradient(
        colors: [color, Color.lerp(color, AppColors.sky, 0.45)!],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              // Photo
              ProfilePhotoPicker(
                currentUrl:     user.profileImageUrl,
                localFile:      _localPhoto,
                role:           user.role,
                radius:         46,
                uploading:      _uploadingPhoto,
                uploadProgress: _uploadProgress,
                onPickGallery:  () => _pickPhoto(fromCamera: false),
                onPickCamera:   () => _pickPhoto(fromCamera: true),
                onRemove: (user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty) || _localPhoto != null
                    ? _removePhoto
                    : null,
              ),
              const SizedBox(height: 10),
              Text(
                user.fullName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                user.role.label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Tabs definition ───────────────────────────────────────────────────────

  List<Tab> _buildTabs(UserModel u) {
    if (u.role == UserRole.student) {
      return const [
        Tab(text: 'Personal'),
        Tab(text: 'Family'),
        Tab(text: 'Medical'),
      ];
    }
    return const [
      Tab(text: 'Personal'),
      Tab(text: 'Professional'),
    ];
  }

  List<Widget> _buildTabViews(UserModel u) {
    if (u.role == UserRole.student) {
      return [
        _buildPersonalTab(u),
        _buildFamilyTab(u),
        _buildMedicalTab(u),
      ];
    }
    return [
      _buildPersonalTab(u),
      _buildProfessionalTab(u),
    ];
  }

  // ─── Personal tab ──────────────────────────────────────────────────────────

  Widget _buildPersonalTab(UserModel user) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const LanguageSection(),
        _SectionCard(
          title: 'Basic Information',
          icon: Icons.person_outline,
          children: [
            _FieldRow(
              label: 'First Name',
              value: user.firstName,
              controller: _firstNameCtrl,
              editMode: _editMode,
            ),
            _FieldRow(
              label: 'Last Name',
              value: user.lastName,
              controller: _lastNameCtrl,
              editMode: _editMode,
            ),
            _FieldRow(
              label: 'Email',
              value: user.email,
              readOnly: true,
              editMode: false,
            ),
            _FieldRow(
              label: 'Phone',
              value: user.phoneNumber ?? '—',
              controller: _phoneCtrl,
              editMode: _editMode,
              keyboardType: TextInputType.phone,
            ),
            _FieldRow(
              label: 'Address',
              value: user.address ?? '—',
              controller: _addressCtrl,
              editMode: _editMode,
            ),
            _FieldRow(
              label: 'CIN',
              value: user.cin ?? '—',
              controller: _cinCtrl,
              editMode: _editMode,
            ),
            _FieldRow(
              label: 'Nationality',
              value: user.nationality ?? '—',
              controller: _nationalityCtrl,
              editMode: _editMode,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Additional Details',
          icon: Icons.info_outline,
          children: [
            // Birthday picker
            if (_editMode)
              _DatePickerRow(
                label: 'Birthday',
                date: _birthday,
                onChanged: (d) => setState(() => _birthday = d),
              )
            else
              _InfoRow(label: 'Birthday', value: user.birthday != null
                  ? '${user.birthday!.day}/${user.birthday!.month}/${user.birthday!.year}'
                  : '—'),

            // Gender selector
            if (_editMode)
              _GenderRow(
                gender: _gender,
                onChanged: (g) => setState(() => _gender = g),
              )
            else
              _InfoRow(label: 'Gender', value: user.gender?.label ?? '—'),

            _InfoRow(label: 'Role',   value: user.role.label),
            _InfoRow(label: 'Status', value: user.status.label),
            _InfoRow(
              label: 'Member Since',
              value: '${user.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}',
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Security
        _SectionCard(
          title: 'Security',
          icon: Icons.lock_outline,
          children: [
            // Change email
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.email_outlined, size: 18),
                label: const Text('Change Email Address'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.brand,
                  side: BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _showChangeEmailDialog(user),
              ),
            ),
            // Change password
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.lock_reset_outlined, size: 18),
                label: const Text('Change Password'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.brand,
                  side: BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _showChangePasswordDialog(user),
              ),
            ),
            // Send reset email (fallback)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.send_outlined, size: 18),
                label: const Text('Send Password Reset Email'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.textSecondary,
                  side: BorderSide(color: context.divider),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _sendPasswordReset,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ─── Professional tab ──────────────────────────────────────────────────────

  Widget _buildProfessionalTab(UserModel user) {
    final canEditProf = _editMode &&
        (user.role == UserRole.admin || user.role == UserRole.subAdmin || user.role == UserRole.teacher);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: 'Employment',
          icon: Icons.work_outline,
          children: [
            _FieldRow(
              label: 'Speciality',
              value: user.speciality ?? '—',
              controller: _specialityCtrl,
              editMode: canEditProf,
            ),
            _FieldRow(
              label: 'Group',
              value: user.group ?? '—',
              controller: _groupCtrl,
              editMode: canEditProf,
            ),
            if (user.salary != null)
              _InfoRow(label: 'Salary', value: '${user.salary!.toStringAsFixed(2)} TND'),
            if (user.enrollmentDate != null)
              _InfoRow(
                label: 'Enrollment Date',
                value: '${user.enrollmentDate!.day}/${user.enrollmentDate!.month}/${user.enrollmentDate!.year}',
              ),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Qualifications',
          icon: Icons.school_outlined,
          children: [
            _ChipListRow(label: 'Diplomas',  items: user.diplomas),
            _ChipListRow(label: 'Languages', items: user.languages),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Notes',
          icon: Icons.notes_outlined,
          children: [
            _FieldRow(
              label: 'Additional Info',
              value: user.additionalInfo ?? '—',
              controller: _addInfoCtrl,
              editMode: canEditProf,
              maxLines: 3,
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ─── Family tab (student read-only) ────────────────────────────────────────

  Widget _buildFamilyTab(UserModel user) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: 'Father',
          icon: Icons.man_outlined,
          children: [
            _InfoRow(label: 'Name',  value: user.fatherName  ?? '—'),
            _InfoRow(label: 'Phone', value: user.fatherPhone ?? '—'),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Mother',
          icon: Icons.woman_outlined,
          children: [
            _InfoRow(label: 'Name',  value: user.motherName  ?? '—'),
            _InfoRow(label: 'Phone', value: user.motherPhone ?? '—'),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ─── Medical tab (student read-only) ───────────────────────────────────────

  Widget _buildMedicalTab(UserModel user) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: 'Diagnoses',
          icon: Icons.medical_information_outlined,
          children: user.diagnoses.isEmpty
              ? [const _InfoRow(label: '', value: 'No diagnoses recorded')]
              : user.diagnoses.map((d) => _InfoRow(label: '', value: d)).toList(),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Allergies',
          icon: Icons.warning_amber_outlined,
          children: user.allergies.isEmpty
              ? [const _InfoRow(label: '', value: 'No allergies recorded')]
              : user.allergies.map((a) => _InfoRow(label: '', value: a)).toList(),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Medications',
          icon: Icons.medication_outlined,
          children: user.medications.isEmpty
              ? [const _InfoRow(label: '', value: 'No medications recorded')]
              : user.medications.map((m) => _MedicationRow(med: m)).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ─── Reusable sub-widgets ──────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
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
              Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  )),
            ]),
          ),
          Divider(height: 1, color: Theme.of(context).colorScheme.outline),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (label.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Text(value,
            style: TextStyle(
              fontSize: 14, color: colorScheme.onSurfaceVariant,
            )),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(
                  fontSize: 13, color: colorScheme.onSurfaceVariant,
                )),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                )),
          ),
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final String label;
  final String value;
  final TextEditingController? controller;
  final bool editMode;
  final bool readOnly;
  final TextInputType keyboardType;
  final int maxLines;

  const _FieldRow({
    required this.label,
    required this.value,
    this.controller,
    this.editMode = false,
    this.readOnly = false,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    if (editMode && controller != null && !readOnly) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
          style: const TextStyle(fontSize: 14),
        ),
      );
    }
    return _InfoRow(label: label, value: value);
  }
}

class _DatePickerRow extends StatelessWidget {
  final String label;
  final DateTime? date;
  final ValueChanged<DateTime?> onChanged;

  const _DatePickerRow({required this.label, this.date, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today_outlined, size: 16),
              label: Text(
                date != null ? '${date!.day}/${date!.month}/${date!.year}' : 'Select date',
                style: const TextStyle(fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                foregroundColor: colorScheme.onSurface,
                side: BorderSide(color: colorScheme.outline),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date ?? DateTime(2000),
                  firstDate: DateTime(1940),
                  lastDate: DateTime.now(),
                );
                if (picked != null) onChanged(picked);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GenderRow extends StatelessWidget {
  final Gender? gender;
  final ValueChanged<Gender?> onChanged;

  const _GenderRow({this.gender, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          const SizedBox(
            width: 120,
            child: Text('Gender',
                style: TextStyle(fontSize: 13)),
          ),
          Expanded(
            child: DropdownButtonFormField<Gender>(
              initialValue: gender,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              dropdownColor: colorScheme.surface,
              items: Gender.values.map((g) => DropdownMenuItem(
                    value: g,
                    child: Text(g.label, style: const TextStyle(fontSize: 14)),
                  )).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipListRow extends StatelessWidget {
  final String label;
  final List<String> items;

  const _ChipListRow({required this.label, required this.items});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          items.isEmpty
              ? Text('—', style: TextStyle(color: colorScheme.onSurfaceVariant))
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: items
                      .map((e) => Chip(
                            label: Text(e, style: const TextStyle(fontSize: 12)),
                            backgroundColor: colorScheme.surfaceContainerHighest,
                            side: BorderSide(color: colorScheme.outline),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ))
                      .toList(),
                ),
        ],
      ),
    );
  }
}

class _MedicationRow extends StatelessWidget {
  final Medication med;
  const _MedicationRow({required this.med});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(med.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: colorScheme.onSurface,
                )),
            const SizedBox(height: 2),
            Text('Dosage: ${med.dosage}',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
            if (med.frequency != null)
              Text('Frequency: ${med.frequency}',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
            if (med.notes != null)
              Text('Notes: ${med.notes}',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
