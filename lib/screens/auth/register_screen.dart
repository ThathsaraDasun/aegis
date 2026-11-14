import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/user_model.dart';
import '../../services/activity_service.dart';
import '../../theme/aegis_theme.dart';

/// Registration (Sign Up) page.
///
/// Visually matches the Sign In page: curved navy header with the fading Aegis
/// logo, light form area, white fields and the orange gradient action button.
/// Creates a Firebase Auth account, sets the display name and saves the
/// profile document (users/{uid}) via [ActivityService.saveUser].
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.onRegistered});

  /// Called after the account is created and signed in. The Sign In page uses
  /// this to open the dashboard, following the same flow as a normal sign-in.
  final VoidCallback? onRegistered;

  static Future<void> open(BuildContext context, {VoidCallback? onRegistered}) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RegisterScreen(onRegistered: onRegistered)),
    );
  }

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Same palette as the Sign In page (deep navy + Aegis safety orange).
  static const Color _navyDeep = Color(0xFF0B1F3A);
  static const Color _navy = Color(0xFF1A3A5C); // AegisColors.background
  static const Color _navyLight = Color(0xFF24507F);
  static const Color _pageBg = Color(0xFFF4F6FA);
  static const Color _fieldBorder = Color(0xFFDDE3EC);
  static const Color _ink = Color(0xFF14233A);
  static const Color _inkMuted = Color(0xFF6B778A);
  static const Color _orangeLight = Color(0xFFFF7A45);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Rebuild so the password-strength meter follows what is typed.
    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ── Validation ────────────────────────────────────────────────

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Please enter your full name';
    if (name.length < 2) return 'Name is too short';
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Please enter your email address';
    if (!_emailPattern.hasMatch(email)) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Please create a password';
    if (password.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(password) || !RegExp(r'\d').hasMatch(password)) {
      return 'Include at least one letter and one number';
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    if ((value ?? '').isEmpty) return 'Please confirm your password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  /// 0 = empty, 1 = weak, 2 = fair, 3 = strong.
  int get _strength {
    final p = _passwordController.text;
    if (p.isEmpty) return 0;
    var score = 0;
    if (p.length >= 8) score++;
    if (RegExp(r'[A-Za-z]').hasMatch(p) && RegExp(r'\d').hasMatch(p)) score++;
    if (p.length >= 12 || RegExp(r'[^A-Za-z0-9]').hasMatch(p)) score++;
    return score.clamp(1, 3);
  }

  // ── Actions ───────────────────────────────────────────────────

  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final name = _nameController.text.trim();

    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final user = credential.user;
      if (user != null) {
        await user.updateDisplayName(name);
        try {
          // Reuse the existing profile service so the Profile tab shows the name.
          await ActivityService().saveUser(UserModel(userId: user.uid, name: name, phone: ''));
        } catch (e) {
          debugPrint('Profile save after sign-up failed: $e');
        }
      }

      messenger.showSnackBar(
        SnackBar(content: Text('Welcome to Aegis, $name! Your account is ready.')),
      );
      if (widget.onRegistered != null) {
        widget.onRegistered!();
      } else {
        navigator.pop();
      }
    } on FirebaseAuthException catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(_messageFor(e)),
        backgroundColor: AegisColors.primaryContainer,
        duration: const Duration(seconds: 6),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Sign-up failed: $e'),
        backgroundColor: AegisColors.primaryContainer,
      ));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists for this email. Try signing in instead.';
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'weak-password':
        return 'That password is too weak. Choose a stronger one.';
      case 'operation-not-allowed':
        return 'Email/Password sign-up is not enabled. Turn it on in Firebase Console > Authentication > Sign-in method.';
      case 'network-request-failed':
        return 'No internet connection. Check your network and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a minute and try again.';
      default:
        return 'Sign-up failed (${e.code}): ${e.message ?? 'unknown error'}';
    }
  }

  // ── UI ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _pageBg,
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            children: [
              _buildHeader(context),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, child) => Opacity(
                      opacity: t,
                      child: Transform.translate(offset: Offset(0, 20 * (1 - t)), child: child),
                    ),
                    child: _buildForm(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return ClipPath(
      clipper: _CurvedHeaderClipper(),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(AegisSpacing.sm, topInset + AegisSpacing.sm, AegisSpacing.sm, 56),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_navyDeep, _navy, _navyLight],
          ),
        ),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Back to Sign In',
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            const _FadingLogo(size: 64),
            const SizedBox(height: AegisSpacing.sm),
            Text(
              'AEGIS SAFE WALK',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: AegisSpacing.md),
            Text(
              'Create Account',
              style: GoogleFonts.outfit(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: AegisSpacing.xs),
            Text(
              'Join your personal safety network',
              style: GoogleFonts.outfit(fontSize: 15, color: Colors.white.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    const radius = BorderRadius.all(Radius.circular(AegisRadius.md));
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.outfit(color: _inkMuted, fontSize: 15),
      prefixIcon: Icon(icon, color: _navyLight, size: 22),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      errorStyle: GoogleFonts.outfit(color: AegisColors.danger, fontSize: 12),
      errorMaxLines: 2,
      contentPadding: const EdgeInsets.symmetric(horizontal: AegisSpacing.lg, vertical: 18),
      border: const OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: _fieldBorder)),
      enabledBorder:
          const OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: _fieldBorder)),
      focusedBorder: const OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: _navyLight, width: 1.6),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: AegisColors.danger, width: 1.2),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: AegisColors.danger, width: 1.6),
      ),
    );
  }

  Widget _visibilityToggle(bool obscured, VoidCallback onPressed) {
    return IconButton(
      tooltip: obscured ? 'Show password' : 'Hide password',
      icon: Icon(
        obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: _inkMuted,
      ),
      onPressed: onPressed,
    );
  }

  Widget _buildForm() {
    final fieldStyle = GoogleFonts.outfit(color: _ink, fontSize: 15);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AegisSpacing.xl, AegisSpacing.sm, AegisSpacing.xl, AegisSpacing.xl),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('register_name'),
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                style: fieldStyle,
                cursorColor: _navyLight,
                validator: _validateName,
                decoration: _fieldDecoration(hint: 'Full name', icon: Icons.badge_outlined),
              ),
              const SizedBox(height: AegisSpacing.md),
              TextFormField(
                key: const Key('register_email'),
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                style: fieldStyle,
                cursorColor: _navyLight,
                validator: _validateEmail,
                decoration: _fieldDecoration(hint: 'Email address', icon: Icons.person_outline_rounded),
              ),
              const SizedBox(height: AegisSpacing.md),
              TextFormField(
                key: const Key('register_password'),
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                style: fieldStyle,
                cursorColor: _navyLight,
                validator: _validatePassword,
                decoration: _fieldDecoration(
                  hint: 'Password',
                  icon: Icons.lock_outline_rounded,
                  suffix: _visibilityToggle(
                    _obscurePassword,
                    () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              _PasswordStrength(strength: _strength, mutedColor: _inkMuted, trackColor: _fieldBorder),
              const SizedBox(height: AegisSpacing.md),
              TextFormField(
                key: const Key('register_confirm'),
                controller: _confirmController,
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                style: fieldStyle,
                cursorColor: _navyLight,
                validator: _validateConfirm,
                onFieldSubmitted: (_) {
                  if (!_isLoading) _register();
                },
                decoration: _fieldDecoration(
                  hint: 'Confirm password',
                  icon: Icons.lock_reset_rounded,
                  suffix: _visibilityToggle(
                    _obscureConfirm,
                    () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),
              const SizedBox(height: AegisSpacing.xl),

              // ── Create account (same gradient button as Sign In) ──
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_orangeLight, AegisColors.primary]),
                  borderRadius: const BorderRadius.all(Radius.circular(AegisRadius.md)),
                  boxShadow: [
                    BoxShadow(
                      color: AegisColors.primary.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    key: const Key('register_submit'),
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(AegisRadius.md)),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Text(
                            'Create Account',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: AegisSpacing.lg),

              // ── Back to Sign In ────────────────────────────────
              // Wrap (not Row) so it never overflows on narrow screens or
              // with large system text.
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Already have an account?',
                    style: GoogleFonts.outfit(fontSize: 14, color: _inkMuted),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: TextButton.styleFrom(
                      foregroundColor: _navyLight,
                      padding: const EdgeInsets.symmetric(horizontal: AegisSpacing.xs),
                    ),
                    child: Text(
                      'Sign In',
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AegisSpacing.md),

              // ── Footer ─────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.verified_user_outlined, size: 14, color: _inkMuted),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Your location is shared only with your trusted guardians.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(fontSize: 12, color: _inkMuted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three-segment password strength bar shown under the password field.
class _PasswordStrength extends StatelessWidget {
  const _PasswordStrength({
    required this.strength,
    required this.mutedColor,
    required this.trackColor,
  });

  final int strength;
  final Color mutedColor;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    if (strength == 0) return const SizedBox.shrink();
    const labels = ['', 'Weak', 'Fair', 'Strong'];
    const colors = [Colors.transparent, AegisColors.danger, AegisColors.warning, AegisColors.tertiary];
    final color = colors[strength];

    return Padding(
      padding: const EdgeInsets.only(top: AegisSpacing.sm, left: AegisSpacing.xs, right: AegisSpacing.xs),
      child: Row(
        children: [
          for (var i = 1; i <= 3; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 4,
                decoration: BoxDecoration(
                  color: i <= strength ? color : trackColor,
                  borderRadius: const BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ),
            if (i < 3) const SizedBox(width: AegisSpacing.xs),
          ],
          const SizedBox(width: AegisSpacing.sm),
          Text(
            labels[strength],
            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

/// Same curved header shape as the Sign In page.
class _CurvedHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(0, size.height - 40)
      ..quadraticBezierTo(size.width / 2, size.height + 10, size.width, size.height - 40)
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Same fading Aegis logo as the Sign In page.
class _FadingLogo extends StatefulWidget {
  const _FadingLogo({required this.size});

  final double size;

  @override
  State<_FadingLogo> createState() => _FadingLogoState();
}

class _FadingLogoState extends State<_FadingLogo> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat();

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logo = Image.asset(
      'assets/logo/aegis_logo.png',
      width: widget.size,
      height: widget.size,
      semanticLabel: 'Aegis logo',
    );

    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return logo;

    return AnimatedBuilder(
      animation: Listenable.merge([_intro, _pulse]),
      builder: (context, child) {
        final intro = Curves.easeOut.transform(_intro.value);
        final breath = 0.5 + 0.5 * math.cos(2 * math.pi * _pulse.value);
        return Opacity(opacity: intro * (0.35 + 0.65 * breath), child: child);
      },
      child: logo,
    );
  }
}
