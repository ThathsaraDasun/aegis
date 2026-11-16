/// Password rules for new Aegis accounts.
///
/// Applied when creating an account (and anywhere a new password is chosen).
/// Signing in with an existing password is not checked against these rules.
class PasswordPolicy {
  PasswordPolicy._();

  static const int minLength = 8;
  static const int maxLength = 64;

  /// Every rule, in the order shown to the user.
  static const List<PasswordRule> rules = [
    PasswordRule('At least $minLength characters', _longEnough),
    PasswordRule('An uppercase letter (A–Z)', _hasUpper),
    PasswordRule('A lowercase letter (a–z)', _hasLower),
    PasswordRule('A number (0–9)', _hasDigit),
    PasswordRule('A symbol, e.g. ! @ # \$ %', _hasSymbol),
    PasswordRule('No spaces', _noSpaces),
  ];

  static bool _longEnough(String p) => p.length >= minLength;
  static bool _hasUpper(String p) => RegExp(r'[A-Z]').hasMatch(p);
  static bool _hasLower(String p) => RegExp(r'[a-z]').hasMatch(p);
  static bool _hasDigit(String p) => RegExp(r'[0-9]').hasMatch(p);
  static bool _hasSymbol(String p) => RegExp(r'[^A-Za-z0-9\s]').hasMatch(p);
  static bool _noSpaces(String p) => p.isNotEmpty && !RegExp(r'\s').hasMatch(p);

  /// The first problem with [password], or null if it is acceptable.
  /// [email] is used to reject passwords that contain the email name.
  static String? validate(String password, {String email = ''}) {
    if (password.isEmpty) return 'Enter a password.';
    if (password.length > maxLength) {
      return 'Use at most $maxLength characters.';
    }
    for (final rule in rules) {
      if (!rule.check(password)) return 'Password needs: ${rule.label}.';
    }
    final name = email.trim().split('@').first.toLowerCase();
    if (name.length >= 3 && password.toLowerCase().contains(name)) {
      return 'Do not use your email name in the password.';
    }
    if (_common.contains(password.toLowerCase())) {
      return 'This password is too common. Choose another.';
    }
    return null;
  }

  /// Passwords that pass the character rules but are well known.
  static const Set<String> _common = {
    'password1!',
    'password@1',
    'password123!',
    'p@ssw0rd',
    'p@ssw0rd1',
    'qwerty123!',
    'welcome1!',
    'welcome@123',
    'admin@123',
    'abcd@1234',
    'aegis@123',
  };
}

/// One password requirement and its check.
class PasswordRule {
  final String label;
  final bool Function(String) check;
  const PasswordRule(this.label, this.check);
}
