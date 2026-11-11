/// Cloudinary configuration — replace with your actual values.
///
/// How to find them:
///  - Cloud name  → Cloudinary Console → Settings → Account
///  - Upload preset → Cloudinary Console → Settings → Upload → Unsigned presets
///    Create an **unsigned** preset for each folder (or one shared preset).
///
/// ⚠️  Never commit secrets here.  For production, load these from
///     --dart-define or a gitignored .env file.
class CloudinaryConfig {
  CloudinaryConfig._();

  /// Your Cloudinary cloud name (e.g. "my-cloud").
  static const String cloudName = 'drj5ri6fn';

  /// An **unsigned** upload preset configured in your Cloudinary account.
  /// One preset is enough; folders are controlled per-upload.
  static const String uploadPreset = 'Hope_academy';

  /// Base URL for the Cloudinary Upload API.
  
  static String get uploadUrl =>
      'https://api.cloudinary.com/v1_1/drj5ri6fn/auto/upload';
}
