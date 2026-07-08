import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  // ─── Pick image (Web + Mobile compatible) ────────────────────────────────
  // On Web:    opens the native file input dialog (gallery only — no camera channel)
  // On Mobile: opens gallery or camera as requested

  Future<XFile?> pickImage({bool fromCamera = false}) async {
    if (kIsWeb) {
      // Web: ImageSource.camera falls back to gallery on most browsers.
      // Use gallery explicitly to avoid MissingPluginException on web.
      return _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
    }
    return _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
  }

  // ─── Upload profile photo → returns download URL ─────────────────────────
  // Uses putData (bytes) on Web, putFile on Mobile — both go through Firebase Storage.

  Future<String> uploadProfilePhoto({
    required String uid,
    required XFile file,
    void Function(double progress)? onProgress,
  }) async {
    final ref = _storage
        .ref()
        .child('profile_photos')
        .child('$uid.jpg');

    UploadTask uploadTask;

    // Web requires reading bytes; Mobile can use the file path.
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      uploadTask = ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
    } else {
      // ignore: avoid_slow_async_io
      uploadTask = ref.putData(
        await file.readAsBytes(),
        SettableMetadata(contentType: 'image/jpeg'),
      );
    }

    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((snap) {
        final total = snap.totalBytes == 0 ? 1 : snap.totalBytes;
        onProgress(snap.bytesTransferred / total);
      });
    }

    await uploadTask;
    return ref.getDownloadURL();
  }

  // ─── Delete profile photo from storage ───────────────────────────────────

  Future<void> deleteProfilePhoto(String uid) async {
    try {
      await _storage
          .ref()
          .child('profile_photos')
          .child('$uid.jpg')
          .delete();
    } catch (_) {
      // File may not exist — ignore
    }
  }
}
