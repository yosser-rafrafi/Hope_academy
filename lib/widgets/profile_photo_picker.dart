import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/app_colors.dart';
import '../models/user_model.dart';

/// A circular photo picker that shows the current photo (network or local file)
/// with an edit overlay. Tapping opens a bottom sheet to choose gallery/camera.
class ProfilePhotoPicker extends StatelessWidget {
  final String? currentUrl;   // existing network URL (from UserModel)
  final XFile? localFile;     // newly picked but not yet uploaded
  final UserRole role;
  final double radius;
  final bool uploading;
  final double uploadProgress; // 0.0 – 1.0
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;
  final VoidCallback? onRemove;

  const ProfilePhotoPicker({
    super.key,
    this.currentUrl,
    this.localFile,
    required this.role,
    this.radius = 48,
    this.uploading = false,
    this.uploadProgress = 0,
    required this.onPickGallery,
    required this.onPickCamera,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          // ── Avatar ────────────────────────────────────────────────────────
          Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _roleColor(role),
                width: 2.5,
              ),
            ),
            child: ClipOval(child: _buildImage()),
          ),

          // ── Upload progress ring ──────────────────────────────────────────
          if (uploading)
            SizedBox(
              width: radius * 2,
              height: radius * 2,
              child: CircularProgressIndicator(
                value: uploadProgress > 0 ? uploadProgress : null,
                strokeWidth: 3,
                color: _roleColor(role),
              ),
            ),

          // ── Edit badge ────────────────────────────────────────────────────
          if (!uploading)
            Container(
              width: radius * 0.7,
              height: radius * 0.7,
              decoration: BoxDecoration(
                color: _roleColor(role),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                Icons.camera_alt,
                size: radius * 0.35,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    // Priority: local picked file > existing network URL > initials placeholder
    if (localFile != null) {
      // On Web, Image.file doesn't work — use Image.network with object URL
      // On Mobile, use Image.file for local file access
      if (kIsWeb) {
        return FutureBuilder<List<int>>(
          future: localFile!.readAsBytes().then((b) => b),
          builder: (_, snap) {
            if (!snap.hasData) return _placeholder();
            return Image.memory(
              Uint8List.fromList(snap.data!),
              fit: BoxFit.cover,
              width: radius * 2,
              height: radius * 2,
            );
          },
        );
      }
      return Image.file(
        File(localFile!.path),
        fit: BoxFit.cover,
        width: radius * 2,
        height: radius * 2,
      );
    }
    if (currentUrl != null && currentUrl!.isNotEmpty) {
      return Image.network(
        currentUrl!,
        fit: BoxFit.cover,
        width: radius * 2,
        height: radius * 2,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      color: _roleColor(role).withAlpha(30),
      child: Icon(
        Icons.person_outline,
        size: radius * 0.9,
        color: _roleColor(role),
      ),
    );
  }

  Color _roleColor(UserRole r) {
    switch (r) {
      case UserRole.admin:
        return AppColors.primary;
      case UserRole.subAdmin:
        return const Color(0xFF6A0DAD);
      case UserRole.teacher:
        return AppColors.success;
      case UserRole.student:
        return AppColors.accent;
    }
  }

  void _showPicker(BuildContext context) {
    final hasPhoto = localFile != null ||
        (currentUrl != null && currentUrl!.isNotEmpty);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: context.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Profile Photo',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,color: context.textPrimary),
              ),
              const SizedBox(height: 16),
              _PickerOption(
                icon: Icons.photo_library_outlined,
                label: 'Choose from Gallery',
                onTap: () {
                  Navigator.pop(context);
                  onPickGallery();
                },
              ),
              // Camera option only on mobile — not available on Web
              if (!kIsWeb) ...[
                const SizedBox(height: 10),
                _PickerOption(
                  icon: Icons.camera_alt_outlined,
                  label: 'Take a Photo',
                  onTap: () {
                    Navigator.pop(context);
                    onPickCamera();
                  },
                ),
              ],
              if (hasPhoto && onRemove != null) ...[
                const SizedBox(height: 10),
                _PickerOption(
                  icon: Icons.delete_outline,
                  label: 'Remove Photo',
                  color: AppColors.error,
                  onTap: () {
                    Navigator.pop(context);
                    onRemove!();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PickerOption({
    required this.icon,
    required this.label,
    this.color = AppColors.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
