/// Single place for the academy currency and money/year helpers.
///
/// NOTE: the existing code mixes "EGP" (create-user form) and "TND"
/// (user details/profile). Change [kCurrencyCode] here to switch the whole
/// finance module at once.
const String kCurrencyCode = 'EGP';

/// 1234567.5 → "1 234 567.50 EGP" (non-breaking spaces, Latin digits in all
/// languages so PDFs and screens always agree).
String formatMoney(num value, {String? currency, bool withCode = true}) {
  final neg = value < 0;
  final abs = value.abs();
  final isWhole = (abs * 100).round() % 100 == 0;
  final fixed = abs.toStringAsFixed(isWhole ? 0 : 2);
  final parts = fixed.split('.');
  final grouped = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '\u00A0');
  final dec = parts.length > 1 ? '.${parts[1]}' : '';
  final code = withCode ? '\u00A0${currency ?? kCurrencyCode}' : '';
  return '${neg ? '-' : ''}$grouped$dec$code';
}

/// "2026/2027" from September, "2025/2026" before.
String currentAcademicYear([DateTime? now]) {
  final n = now ?? DateTime.now();
  final y = n.month >= 9 ? n.year : n.year - 1;
  return '$y/${y + 1}';
}

/// "2026-10" — key of a payroll month.
String monthKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';

double roundMoney(double v) => (v * 100).round() / 100;
