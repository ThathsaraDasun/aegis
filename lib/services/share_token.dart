import 'dart:math';

/// Unguessable tokens that let a guardian open one live trip without an account.
///
/// A token is 32 bytes from a cryptographically secure RNG, hex encoded
/// (64 characters, 256 bits). It is the document ID of `shared_trips/{token}`,
/// so knowing it is the only way to read that mirror; the rules forbid listing.
class ShareToken {
  ShareToken._();

  /// Number of random bytes in a token.
  static const int byteLength = 32;

  /// Length of the hex-encoded token.
  static const int length = byteLength * 2;

  static final RegExp _pattern = RegExp(r'^[0-9a-f]{64}$');

  /// Generates a new token. [random] is only for tests; production code must
  /// use the default [Random.secure].
  static String generate([Random? random]) {
    final rng = random ?? Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < byteLength; i++) {
      buffer.write(rng.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  /// Whether [token] has the exact shape produced by [generate].
  static bool isValid(String? token) =>
      token != null && _pattern.hasMatch(token);
}
