import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';

import '../config/cloudinary_config.dart';

/// Storage service backed by Cloudinary (replaces Firebase Storage).
///
/// Upload strategy:
///   - Unsigned upload via the Cloudinary Upload API (multipart/form-data).
///   - No server-side secret is required — unsigned presets are used.
///   - The returned URL is a permanent public Cloudinary URL.
///
/// Deletion:
///   - Cloudinary unsigned presets **cannot** delete assets.
///   - Profile photo deletion is skipped gracefully (no-op).
///   - If deletion is required, implement a signed delete via your backend.
class StorageService {
  final ImagePicker _picker = ImagePicker();

  // ─────────────────────────────────────────────────────────────────────────
  // Static helpers (kept identical so callers don't change)
  // ─────────────────────────────────────────────────────────────────────────

  static const int maxVideoBytes = 60 * 1024 * 1024; // 60 MB

  static bool isVideoPath(String path) {
    final p = path.split('?').first.toLowerCase();
    return p.endsWith('.mp4') ||
        p.endsWith('.mov') ||
        p.endsWith('.m4v') ||
        p.endsWith('.webm') ||
        p.endsWith('.3gp') ||
        p.endsWith('.avi');
  }

  static bool isVideoUrl(String url) =>
      isVideoPath(Uri.decodeFull(url.split('?').first));

  // ─────────────────────────────────────────────────────────────────────────
  // Image / video pickers (unchanged — they don't depend on storage provider)
  // ─────────────────────────────────────────────────────────────────────────

  Future<XFile?> pickImage({bool fromCamera = false}) async {
    if (kIsWeb) {
      return _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    }
    return _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
  }

  Future<List<XFile>> pickImages() async {
    try {
      return await _picker.pickMultiImage(
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
      );
    } catch (_) {
      return [];
    }
  }

  Future<XFile?> takePhoto() async {
    if (kIsWeb) return null;
    return _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 82,
    );
  }

  Future<XFile?> pickVideo({bool fromCamera = false}) async {
    return _picker.pickVideo(
      source:
          (fromCamera && !kIsWeb) ? ImageSource.camera : ImageSource.gallery,
      maxDuration: const Duration(minutes: 3),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Core Cloudinary upload
  // ─────────────────────────────────────────────────────────────────────────

  /// Uploads [bytes] to Cloudinary under [folder] with the given [fileName].
  ///
  /// Returns the permanent Cloudinary secure URL.
  /// [onProgress] receives values from 0.0 to 1.0 (best-effort; Cloudinary's
  /// HTTP API doesn't stream progress, so we report 0 → 1 only).
  Future<String> _uploadBytes({
    required Uint8List bytes,
    required String folder,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.0);

    if (isVideoPath(fileName) && bytes.length > maxVideoBytes) {
      throw Exception('Video is too large (max 60 MB).');
    }

    final uri = Uri.parse(CloudinaryConfig.uploadUrl);
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
      ..fields['folder'] = folder
      ..fields['public_id'] = fileName
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
        ),
      );

    final streamedResponse = await request.send();
    final body = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode != 200) {
      throw Exception(
          'Cloudinary upload failed (${streamedResponse.statusCode}): $body');
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    final url = json['secure_url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('Cloudinary response missing secure_url: $body');
    }

    onProgress?.call(1.0);
    return url;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Public API — mirrors the old FirebaseStorage-based StorageService
  // ─────────────────────────────────────────────────────────────────────────

  /// Uploads a profile photo and returns its permanent Cloudinary URL.
  Future<String> uploadProfilePhoto({
    required String uid,
    required XFile file,
    void Function(double progress)? onProgress,
  }) async {
    final bytes = await file.readAsBytes();
    return _uploadBytes(
      bytes: bytes,
      folder: 'profile_photos',
      fileName: '$uid.jpg',
      onProgress: onProgress,
    );
  }

  /// No-op — unsigned Cloudinary uploads cannot be deleted client-side.
  /// Implement a signed delete endpoint on your backend if needed.
  Future<void> deleteProfilePhoto(String uid) async {
    // Not supported with unsigned presets.
    // To enable: call your backend which uses the Cloudinary Admin API.
  }

  /// Uploads one photo/video to [folder] and returns its Cloudinary URL.
  Future<String> uploadMedia({
    required String folder,
    required XFile file,
    void Function(double progress)? onProgress,
  }) async {
    final name = file.name.isNotEmpty ? file.name : file.path.split('/').last;
    final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_$safe';
    final bytes = await file.readAsBytes();
    return _uploadBytes(
      bytes: bytes,
      folder: folder,
      fileName: fileName,
      onProgress: onProgress,
    );
  }

  /// Uploads several files sequentially; reports overall progress 0..1.
  Future<List<String>> uploadAll({
    required String folder,
    required List<XFile> files,
    void Function(double progress)? onProgress,
  }) async {
    final urls = <String>[];
    for (var i = 0; i < files.length; i++) {
      final url = await uploadMedia(
        folder: folder,
        file: files[i],
        onProgress: (p) => onProgress?.call((i + p) / files.length),
      );
      urls.add(url);
    }
    onProgress?.call(1.0);
    return urls;
  }
}
