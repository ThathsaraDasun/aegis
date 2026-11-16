/// Phone number checks used by every phone field in the app.
///
/// Accepts Sri Lankan numbers written locally (`0771234567`, `077 123 4567`)
/// or internationally (`+94771234567`, `0094…`, `94771234567`), and other
/// countries in international form (`+44…`). [normalize] turns them into the
/// international form used for SMS, e.g. `+94771234567`.
class PhoneValidation {
  PhoneValidation._();

  static final RegExp _separators = RegExp(r'[\s\-().]');

  /// International form (`+…`), or the cleaned input if it cannot be
  /// normalised (validation then explains why).
  static String normalize(String raw) {
    var p = raw.trim().replaceAll(_separators, '');
    if (p.startsWith('00')) p = '+${p.substring(2)}';
    if (RegExp(r'^0\d{9}$').hasMatch(p)) return '+94${p.substring(1)}';
    if (RegExp(r'^94\d{9}$').hasMatch(p)) return '+$p';
    // A Sri Lankan mobile typed without its leading 0 (e.g. 771234567).
    if (RegExp(r'^7\d{8}$').hasMatch(p)) return '+94$p';
    return p;
  }

  /// An error message, or null when [raw] is acceptable.
  ///
  /// [required] – an empty value is an error. [mobileOnly] – Sri Lankan
  /// numbers must be mobiles (07…), needed for guardians who receive SMS.
  static String? validate(
    String? raw, {
    bool required = true,
    bool mobileOnly = false,
  }) {
    final cleaned = (raw ?? '').trim().replaceAll(_separators, '');
    if (cleaned.isEmpty) return required ? 'Enter a phone number.' : null;
    if (!RegExp(r'^\+?\d+$').hasMatch(cleaned)) {
      return 'Use digits only (you can start with +).';
    }
    if (cleaned.startsWith('0') && !cleaned.startsWith('00')) {
      if (cleaned.length != 10) {
        return 'Sri Lankan numbers have 10 digits, e.g. 0771234567.';
      }
    }
    final p = normalize(cleaned);
    if (!p.startsWith('+')) {
      return 'Start with 0 (e.g. 0771234567) or a country code (e.g. +94771234567).';
    }
    if (p.startsWith('+94')) {
      if (!RegExp(r'^\+94[1-9]\d{8}$').hasMatch(p)) {
        return 'A Sri Lankan number needs 9 digits after +94, e.g. +94771234567.';
      }
      if (mobileOnly && !p.startsWith('+947')) {
        return 'Use a mobile number (07…) so SMS alerts can be delivered.';
      }
      return null;
    }
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(p)) {
      return 'Enter a valid international number, e.g. +447911123456.';
    }
    return null;
  }
}
