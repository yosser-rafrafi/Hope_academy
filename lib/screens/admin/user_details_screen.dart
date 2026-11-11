import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_colors.dart';
import '../../models/user_model.dart';
import '../../models/absence_model.dart';
import '../../models/activity_model.dart';
import '../../models/class_model.dart';
import '../../services/absence_service.dart';
import '../../services/activity_service.dart';
import '../../services/class_service.dart';
import '../../services/storage_service.dart';
import '../../services/user_service.dart';
import '../../widgets/kid_ui.dart';
import '../../widgets/profile_photo_picker.dart';
import '../../widgets/user_avatar.dart';
import '../../l10n/app_strings.dart';
import '../pei/pei_screen.dart';
import '../finance/student_finance_screen.dart';
import '../../core/permissions.dart';
import '../shared/portfolio_screen.dart';
import '../shared/student_detail_absence_screen.dart';

class UserDetailsScreen extends StatefulWidget {
  final UserModel user;
  final UserModel currentUser;
  const UserDetailsScreen(
      {super.key, required this.user, required this.currentUser});

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  final _absenceService = AbsenceService();
  final _activityService = ActivityService();
  final _classService = ClassService();
  final _storage = StorageService();
  final _userService = UserService();

  // Photo upload state
  UserModel? _updated;
  XFile? _localPhoto;
  bool _uploading = false;
  double _progress = 0;

  UserModel get _user => _updated ?? widget.user;

  bool get _canEditPhoto =>
      widget.currentUser.role != UserRole.student ||
      widget.currentUser.uid == widget.user.uid;

  Future<void> _pickPhoto({required bool camera}) async {
    final file = await _storage.pickImage(fromCamera: camera);
    if (file == null) return;
    setState(() {
      _localPhoto = file;
      _uploading = true;
      _progress = 0;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await _storage.uploadProfilePhoto(
        uid: widget.user.uid,
        file: file,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      await _userService
          .updateUserFields(widget.user.uid, {'profileImageUrl': url});
      if (!mounted) return;
      setState(() {
        _updated = _user.copyWith(profileImageUrl: url);
        _localPhoto = null;
        _uploading = false;
      });
      messenger.showSnackBar(const SnackBar(
          content: Text('Photo updated ✨'), backgroundColor: AppColors.success));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _localPhoto = null;
        _uploading = false;
      });
      messenger.showSnackBar(SnackBar(
          content: Text('Upload failed: $e'), backgroundColor: AppColors.error));
    }
  }

  Future<void> _removePhoto() async {
    try {
      await _storage.deleteProfilePhoto(widget.user.uid);
      await _userService
          .updateUserFields(widget.user.uid, {'profileImageUrl': ''});
      if (mounted) {
        setState(() => _updated = _user.copyWith(profileImageUrl: ''));
      }
    } catch (_) {}
  }

  LinearGradient _roleGradient(UserRole r) {
    switch (r) {
      case UserRole.admin:
        return const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF354463), Color(0xFF4A6FA5)]);
      case UserRole.subAdmin:
        return AppColors.grapeGradient;
      case UserRole.teacher:
        return AppColors.mintGradient;
      case UserRole.student:
        return AppColors.skyGradient;
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _fmtDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final u = _user;
    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHero(u)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: FadeSlideIn(
                child: isWide
                    ? _buildWideLayout(u)
                    : _buildNarrowLayout(u),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Hero banner ──────────────────────────────────────────────────────────

  Widget _buildHero(UserModel u) {
    final hasPhoto = u.profileImageUrl != null && u.profileImageUrl!.isNotEmpty;
    return PlayfulHeader(
      gradient: _roleGradient(u.role),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),
            FadeSlideIn(
              offset: const Offset(0, 12),
              child: _canEditPhoto
                  ? ProfilePhotoPicker(
                      currentUrl: u.profileImageUrl,
                      localFile: _localPhoto,
                      role: u.role,
                      radius: 52,
                      uploading: _uploading,
                      uploadProgress: _progress,
                      onPickGallery: () => _pickPhoto(camera: false),
                      onPickCamera: () => _pickPhoto(camera: true),
                      onRemove: hasPhoto ? _removePhoto : null,
                    )
                  : UserAvatar(user: u, radius: 52),
            ),
            const SizedBox(height: 14),
            Text(
              u.fullName,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_roleIcon(u.role), size: 14, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(u.role.label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
                if (!u.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Deactivated',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            if (u.role == UserRole.student) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF2B5FD9),
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                ),
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: const Text('Student portfolio',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PortfolioScreen(student: u, viewer: widget.currentUser),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white, width: 1.5),
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                ),
                icon: const Icon(Icons.flag_rounded, size: 18),
                label: Text(context.tr('pei.button'),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PeiScreen(student: u, viewer: widget.currentUser),
                  ),
                ),
              ),
              if (Permissions.canManageFees(widget.currentUser)) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 1.5),
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  ),
                  icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
                  label: Text(context.tr('fin.button'),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          StudentFinanceScreen(student: u, viewer: widget.currentUser),
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  IconData _roleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.subAdmin:
        return Icons.manage_accounts;
      case UserRole.teacher:
        return Icons.school;
      case UserRole.student:
        return Icons.face;
    }
  }

  // ─── Layouts ──────────────────────────────────────────────────────────────

  Widget _buildWideLayout(UserModel u) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column — main info
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _personalInfoCard(u),
              const SizedBox(height: 16),
              _academicCard(u),
              if (u.motherName != null || u.fatherName != null) ...[
                const SizedBox(height: 16),
                _familyCard(u),
              ],
              if (u.diagnoses.isNotEmpty ||
                  u.allergies.isNotEmpty ||
                  u.medications.isNotEmpty) ...[
                const SizedBox(height: 16),
                _medicalCard(u),
              ],
              if (u.role == UserRole.student) ...[
                const SizedBox(height: 16),
                _absenceSection(u),
                const SizedBox(height: 16),
                _activitySection(u),
              ],
              if (u.role == UserRole.teacher) ...[
                const SizedBox(height: 16),
                _teacherActivitySection(u),
              ],
            ],
          ),
        ),

        const SizedBox(width: 16),

        // Right column — account + employment + classes
        SizedBox(
          width: 260,
          child: Column(
            children: [
              _accountCard(u),
              const SizedBox(height: 16),
              if (u.salary != null &&
                  widget.currentUser.role == UserRole.admin) ...[
                _employmentCard(u),
                const SizedBox(height: 16),
              ],
              _classSection(u),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(UserModel u) {
    return Column(
      children: [
        _personalInfoCard(u),
        const SizedBox(height: 16),
        _accountCard(u),
        const SizedBox(height: 16),
        _academicCard(u),
        if (u.salary != null && widget.currentUser.role == UserRole.admin) ...[
          const SizedBox(height: 16),
          _employmentCard(u),
        ],
        if (u.motherName != null || u.fatherName != null) ...[
          const SizedBox(height: 16),
          _familyCard(u),
        ],
        if (u.diagnoses.isNotEmpty ||
            u.allergies.isNotEmpty ||
            u.medications.isNotEmpty) ...[
          const SizedBox(height: 16),
          _medicalCard(u),
        ],
        const SizedBox(height: 16),
        _classSection(u),
        if (u.role == UserRole.student) ...[
          const SizedBox(height: 16),
          _absenceSection(u),
          const SizedBox(height: 16),
          _activitySection(u),
        ],
        if (u.role == UserRole.teacher) ...[
          const SizedBox(height: 16),
          _teacherActivitySection(u),
        ],
      ],
    );
  }

  // ─── Cards ─────────────────────────────────────────────────────────────────

  Widget _personalInfoCard(UserModel u) {
    return _card(
      title: 'Personal Information',
      icon: Icons.person_2_outlined,
      child: Column(
        children: [
          _fieldGrid([
            _FieldItem('Email', u.email),
            _FieldItem('Phone', u.phoneNumber),
            _FieldItem('Birthday',
                u.birthday != null ? _fmtDate(u.birthday!) : null),
            _FieldItem('Gender', u.gender?.label),
            _FieldItem('CIN', u.cin),
            _FieldItem('Nationality', u.nationality),
          ]),
          if (u.address != null && u.address!.isNotEmpty) ...[
            const SizedBox(height: 4),
            _singleField('Address', u.address!),
          ],
          if (u.additionalInfo != null && u.additionalInfo!.isNotEmpty) ...[
            const SizedBox(height: 4),
            _singleField('Additional Info', u.additionalInfo!),
          ],
        ],
      ),
    );
  }

  Widget _accountCard(UserModel u) {
    return _card(
      title: 'Account Details',
      icon: Icons.manage_accounts_outlined,
      child: Column(
        children: [
          _accountRow('Status', u.status.label, _statusColor(u.status),
              isChip: true),
          _divider(),
          _accountRow('Created', _fmtDate(u.createdAt), null),
          if (u.lastLoginAt != null) ...[
            _divider(),
            _accountRow('Last Login', _fmtDate(u.lastLoginAt!), null),
          ],
          if (u.enrollmentDate != null) ...[
            _divider(),
            _accountRow('Enrollment', _fmtDate(u.enrollmentDate!), null),
          ],
          if (u.language != null && u.language!.isNotEmpty) ...[
            _divider(),
            _accountRow('Language', u.language!, null),
          ],
        ],
      ),
    );
  }

  Widget _employmentCard(UserModel u) {
    return _card(
      title: 'Employment',
      icon: Icons.cases_outlined,
      child: _accountRow(
          'Salary', '${u.salary!.toStringAsFixed(2)} TND', AppColors.primary,
          valueBold: true),
    );
  }

  Widget _academicCard(UserModel u) {
    final hasContent = u.speciality != null ||
        u.group != null ||
        u.diplomas.isNotEmpty ||
        u.languages.isNotEmpty;
    if (!hasContent) return const SizedBox.shrink();

    return _card(
      title: 'Academic',
      icon: Icons.school_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldGrid([
            _FieldItem('Speciality', u.speciality),
            _FieldItem('Group', u.group),
          ]),
          if (u.diplomas.isNotEmpty) ...[
            const SizedBox(height: 8),
            _labelText('Diplomas'),
            const SizedBox(height: 6),
            _chipWrap(u.diplomas, AppColors.primary),
          ],
          if (u.languages.isNotEmpty) ...[
            const SizedBox(height: 10),
            _labelText('Languages'),
            const SizedBox(height: 6),
            _chipWrap(u.languages, const Color(0xFF3D7A9A)),
          ],
        ],
      ),
    );
  }

  Widget _familyCard(UserModel u) {
    return _card(
      title: 'Family',
      icon: Icons.family_restroom_outlined,
      child: _fieldGrid([
        _FieldItem('Father', u.fatherName),
        _FieldItem('Father Phone', u.fatherPhone),
        _FieldItem('Mother', u.motherName),
        _FieldItem('Mother Phone', u.motherPhone),
      ]),
    );
  }

  Widget _medicalCard(UserModel u) {
    return _card(
      title: 'Medical Information',
      icon: Icons.medical_services_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (u.diagnoses.isNotEmpty) ...[
            _labelText('Diagnoses'),
            const SizedBox(height: 6),
            _chipWrap(u.diagnoses, AppColors.error),
            const SizedBox(height: 10),
          ],
          if (u.allergies.isNotEmpty) ...[
            _labelText('Allergies'),
            const SizedBox(height: 6),
            _chipWrap(u.allergies, AppColors.warning),
            const SizedBox(height: 10),
          ],
          if (u.medications.isNotEmpty) ...[
            _labelText('Medications'),
            const SizedBox(height: 6),
            ...u.medications.map((m) => Builder(
                  builder: (context) {
                    final cs = Theme.of(context).colorScheme;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cs.outline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${m.name} — ${m.dosage}',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface)),
                          if (m.frequency != null)
                            Text('Frequency: ${m.frequency}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant)),
                          if (m.notes != null)
                            Text('Note: ${m.notes}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant)),
                        ],
                      ),
                    );
                  },
                )),
          ],
        ],
      ),
    );
  }

  // ─── Classes ──────────────────────────────────────────────────────────────

  Widget _classSection(UserModel u) {
    final isStudent = u.role == UserRole.student;
    final isTeacher = u.role == UserRole.teacher;
    if (!isStudent && !isTeacher) return const SizedBox.shrink();

    return StreamBuilder<List<ClassModel>>(
      stream: _classService.streamAll(),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return _card(
            title: isTeacher ? 'Assigned Classes' : 'Class Enrollment',
            icon: Icons.class_outlined,
            child: _errorLabel('Erreur: ${snap.error}'),
          );
        }
        final classes = (snap.data ?? [])
            .where((c) => isStudent
                ? c.studentIds.contains(u.uid)
                : c.teacherIds.contains(u.uid))
            .toList();

        return _card(
          title: isTeacher ? 'Assigned Classes' : 'Class Enrollment',
          icon: Icons.class_outlined,
          badge: classes.length.toString(),
          badgeColor: AppColors.primary,
          child: snap.connectionState == ConnectionState.waiting
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: context.brand),
                  ),
                )
              : classes.isEmpty
                  ? _emptyLabel('No classes assigned')
                  : Column(
                      children: classes
                          .map((c) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                                ),
                                child: Row(children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                        color: AppColors.primary.withAlpha(18),
                                        borderRadius: BorderRadius.circular(10)),
                                    child: Icon(Icons.class_,
                                        size: 18, color: context.brand),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(c.name,
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,color: context.textPrimary)),
                                      Text(
                                          '${c.level.label} • ${c.schedule.display}',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: context.textSecondary,)),
                                    ],
                                  )),
                                  Text('${c.studentCount}/${c.capacity}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: context.textSecondary,)),
                                ]),
                              ))
                          .toList(),
                    ),
        );
      },
    );
  }

  // ─── Absences ─────────────────────────────────────────────────────────────

  Widget _absenceSection(UserModel u) {
    final canRecord = widget.currentUser.role == UserRole.admin ||
        widget.currentUser.role == UserRole.subAdmin ||
        widget.currentUser.role == UserRole.teacher;

    return StreamBuilder<List<AbsenceModel>>(
      stream: _absenceService.streamAbsencesByStudent(u.uid),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return _card(
            title: 'Absences',
            icon: Icons.event_busy_outlined,
            child: _errorLabel('Erreur: ${snap.error}'),
          );
        }
        final absences = snap.data ?? [];
        return _card(
          title: 'Absences',
          icon: Icons.event_busy_outlined,
          badge: absences.length.toString(),
          badgeColor: AppColors.error,
          // ── Bouton "Voir / Enregistrer" → StudentDetailAbsenceScreen ──────
          action: canRecord
              ? TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          StudentDetailAbsenceScreen(student: u),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Détail',
                      style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 28),
                  ),
                )
              : null,
          child: snap.connectionState == ConnectionState.waiting
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: context.brand),
                  ))
              : absences.isEmpty
                  ? _emptyLabel('Aucune absence enregistrée')
                  : Column(
                      children: [
                        ...absences.take(5).map((a) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline),
                              ),
                              child: Row(children: [
                                Text(a.type.emoji,
                                    style: const TextStyle(fontSize: 20)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(_fmtDate(a.date),
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface)),
                                      Text(a.type.label,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant)),
                                      if (a.reason != null &&
                                          a.reason!.isNotEmpty)
                                        Text(a.reason!,
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontStyle: FontStyle.italic,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant)),
                                    ],
                                  ),
                                ),
                              ]),
                            )),
                        if (absences.length > 5) ...[
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: canRecord
                                ? () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            StudentDetailAbsenceScreen(
                                                student: u),
                                      ),
                                    )
                                : null,
                            child: Text(
                              'Voir les ${absences.length - 5} autres absences →',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: context.brand,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ],
                    ),
        );
      },
    );
  }

  // ─── Activities ───────────────────────────────────────────────────────────

  Widget _activitySection(UserModel u) {
    return StreamBuilder<List<ActivityModel>>(
      stream: _activityService.streamByStudent(u.uid),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return _card(
            title: 'Activities',
            icon: Icons.assignment_outlined,
            child: _errorLabel('Erreur: ${snap.error}'),
          );
        }
        return _activityCard(
            'Activities', snap.data ?? [], snap.connectionState);
      },
    );
  }

  Widget _teacherActivitySection(UserModel u) {
    return StreamBuilder<List<ActivityModel>>(
      stream: _activityService.streamByTeacher(u.uid),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return _card(
            title: 'Created Activities',
            icon: Icons.assignment_outlined,
            child: _errorLabel('Erreur: ${snap.error}'),
          );
        }
        return _activityCard(
            'Created Activities', snap.data ?? [], snap.connectionState);
      },
    );
  }

  Widget _errorLabel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.error,
                fontFamily: 'Georgia',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _activityCard(
      String title, List<ActivityModel> activities, ConnectionState state) {
    return _card(
      title: title,
      icon: Icons.assignment_outlined,
      badge: activities.length.toString(),
      badgeColor: AppColors.success,
      child: state == ConnectionState.waiting
          ? Center(
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: context.brand)))
          : activities.isEmpty
              ? _emptyLabel('No activities found')
              : Column(
                  children: [
                    ...activities.take(10).map((a) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.softFill,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: context.divider),
                          ),
                          child: Row(children: [
                            Text(a.category.emoji,
                                style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(a.title,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,color: context.textPrimary)),
                                  Text(
                                      '${a.category.label} • ${_fmtDate(a.date)}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: context.textSecondary,)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: a.status == ActivityStatus.completed
                                    ? AppColors.success.withAlpha(20)
                                    : AppColors.warning.withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(a.status.label,
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: a.status ==
                                              ActivityStatus.completed
                                          ? AppColors.success
                                          : AppColors.warning,)),
                            ),
                          ]),
                        )),
                    if (activities.length > 10)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '+ ${activities.length - 10} more activities',
                          style: TextStyle(
                              fontSize: 12,
                              color: context.brand,
                              fontWeight: FontWeight.w600,),
                        ),
                      ),
                  ],
                ),
    );
  }

  // ─── Base card widget ─────────────────────────────────────────────────────

  Widget _card({
    required String title,
    required IconData icon,
    required Widget child,
    String? badge,
    Color? badgeColor,
    /// Optional action widget shown at the right of the header (e.g. a button)
    Widget? action,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Row(children: [
            Icon(icon, size: 19, color: colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            if (badge != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: (badgeColor ?? colorScheme.primary).withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: badgeColor ?? colorScheme.primary,
                  ),
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(width: 8),
              action,
            ],
          ]),

          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  // ─── Field grid (2 columns) ───────────────────────────────────────────────

  Widget _fieldGrid(List<_FieldItem> items) {
    final visible = items.where((i) => i.value != null && i.value!.isNotEmpty).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    // Build rows of 2
    final rows = <Widget>[];
    for (int i = 0; i < visible.length; i += 2) {
      final left = visible[i];
      final right = i + 1 < visible.length ? visible[i + 1] : null;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _fieldCell(left.label, left.value!)),
              if (right != null) ...[
                const SizedBox(width: 16),
                Expanded(child: _fieldCell(right.label, right.value!)),
              ] else
                const Expanded(child: SizedBox()),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _fieldCell(String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface)),
      ],
    );
  }

  Widget _singleField(String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface)),
        ],
      ),
    );
  }

  // ─── Account row ──────────────────────────────────────────────────────────

  Widget _accountRow(String label, String value, Color? color,
      {bool isChip = false, bool valueBold = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Text(label,
            style: TextStyle(
                fontSize: 13, color: colorScheme.onSurfaceVariant)),
        const Spacer(),
        if (isChip && color != null)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(value,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color)),
          )
        else
          Text(value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: valueBold ? FontWeight.bold : FontWeight.w600,
                color: color ?? colorScheme.onSurface,
              )),
      ]),
    );
  }

  Widget _divider() {
    return Divider(height: 1, color: Theme.of(context).colorScheme.outline);
  }

  // ─── Chips ────────────────────────────────────────────────────────────────

  Widget _chipWrap(List<String> items, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items
          .map((e) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withAlpha(60)),
                ),
                child: Text(e,
                    style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w600)),
              ))
          .toList(),
    );
  }

  Widget _labelText(String text) {
    return Text(text,
        style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant));
  }

  Widget _emptyLabel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text,
          style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }

  Color _statusColor(UserStatus status) {
    switch (status) {
      case UserStatus.newUser:
        return AppColors.info;
      case UserStatus.inProgress:
        return AppColors.success;
      case UserStatus.completed:
        return const Color(0xFF2E7D32);
      case UserStatus.blocked:
        return AppColors.error;
      case UserStatus.holding:
        return AppColors.warning;
      case UserStatus.notStarted:
        return context.textSecondary;
    }
  }
}

// ─── Data class for grid fields ───────────────────────────────────────────────

class _FieldItem {
  final String label;
  final String? value;
  const _FieldItem(this.label, this.value);
}
