import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/activity/activity_feed_screen.dart';
import 'screens/activity/recent_activity_preview.dart';
import 'screens/activity/trip_history_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/contacts/contacts_list_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/route/compass_screen.dart';
import 'screens/route/route_comparison_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'theme/aegis_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization warning: $e');
  }
  runApp(const AegisApp());
}

class AegisApp extends StatelessWidget {
  const AegisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aegis - Safe Walk',
      debugShowCheckedModeBanner: false,
      theme: AegisTheme.dark(),
      home: SplashScreen(nextScreen: const AuthWrapper()),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AegisColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AegisColors.primary),
            ),
          );
        }
        if (snapshot.hasData) {
          return const MainNavigationScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(text: 'user@aegis.safe');
  final _passwordController = TextEditingController(text: 'password123');
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        // Signed in: open the dashboard (also works when this screen was
        // reached via the logout button rather than the AuthWrapper).
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      _showLoginError(_messageFor(e));
    } catch (e) {
      _showLoginError('Sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Human-readable text for common Firebase Auth error codes.
  String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password, or this account does not exist in Firebase Authentication.';
      case 'user-disabled':
        return 'This account has been disabled in Firebase.';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is not enabled. Turn it on in Firebase Console > Authentication > Sign-in method.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a minute and try again.';
      case 'network-request-failed':
        return 'No internet connection. Check your network and try again.';
      default:
        return 'Sign-in failed (${e.code}): ${e.message ?? 'unknown error'}';
    }
  }

  void _showLoginError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AegisColors.primaryContainer,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  void _enterDemoMode() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
    );
  }

  bool _obscurePassword = true;

  // ── Login page palette (security: deep navy + Aegis safety orange) ──
  static const Color _navyDeep = Color(0xFF0B1F3A);
  static const Color _navy = Color(0xFF1A3A5C); // AegisColors.background
  static const Color _navyLight = Color(0xFF24507F);
  static const Color _pageBg = Color(0xFFF4F6FA);
  static const Color _fieldBorder = Color(0xFFDDE3EC);
  static const Color _ink = Color(0xFF14233A);
  static const Color _inkMuted = Color(0xFF6B778A);
  static const Color _orangeLight = Color(0xFFFF7A45);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Sends a Firebase password-reset email to the address typed above.
  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (email.isEmpty || !email.contains('@')) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter your email address above first.')),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      messenger.showSnackBar(
        SnackBar(content: Text('Password reset link sent to $email')),
      );
    } on FirebaseAuthException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message ?? 'Could not send reset email (${e.code}).')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not send reset email: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status-bar icons on the dark header.
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

  /// Navy gradient header with a curved bottom edge.
  Widget _buildHeader(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return ClipPath(
      clipper: _CurvedHeaderClipper(),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          AegisSpacing.xl,
          topInset + AegisSpacing.xl,
          AegisSpacing.xl,
          56,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_navyDeep, _navy, _navyLight],
          ),
        ),
        child: Column(
          children: [
            const _FadingLogo(size: 80),
            const SizedBox(height: AegisSpacing.md),
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
              'Welcome',
              style: GoogleFonts.outfit(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AegisSpacing.xs),
            Text(
              'Sign in to continue',
              style: GoogleFonts.outfit(
                fontSize: 15,
                color: Colors.white.withValues(alpha: 0.8),
              ),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: AegisSpacing.lg, vertical: 18),
      border: const OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: _fieldBorder),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: _fieldBorder),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: _navyLight, width: 1.6),
      ),
    );
  }

  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AegisSpacing.xl,
        AegisSpacing.sm,
        AegisSpacing.xl,
        AegisSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Fields ─────────────────────────────────────────────
          AutofillGroup(
            child: Column(
              children: [
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.email],
                  style: GoogleFonts.outfit(color: _ink, fontSize: 15),
                  cursorColor: _navyLight,
                  decoration: _fieldDecoration(
                    hint: 'Email address',
                    icon: Icons.person_outline_rounded,
                  ),
                ),
                const SizedBox(height: AegisSpacing.md),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) {
                    if (!_isLoading) _handleLogin();
                  },
                  style: GoogleFonts.outfit(color: _ink, fontSize: 15),
                  cursorColor: _navyLight,
                  decoration: _fieldDecoration(
                    hint: 'Password',
                    icon: Icons.lock_outline_rounded,
                    suffix: IconButton(
                      tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: _inkMuted,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Forgot password ────────────────────────────────────
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _resetPassword,
              style: TextButton.styleFrom(
                foregroundColor: _navyLight,
                padding: const EdgeInsets.symmetric(vertical: AegisSpacing.sm),
              ),
              child: Text(
                'Forgot Password?',
                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: AegisSpacing.sm),

          // ── Login (gradient) ───────────────────────────────────
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_orangeLight, AegisColors.primary],
              ),
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
                onPressed: _isLoading ? null : _handleLogin,
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
                        'Sign In',
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
          const SizedBox(height: AegisSpacing.xl),

          // ── "or" divider ───────────────────────────────────────
          Row(
            children: [
              const Expanded(child: Divider(color: _fieldBorder)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AegisSpacing.md),
                child: Text(
                  'or continue with',
                  style: GoogleFonts.outfit(fontSize: 13, color: _inkMuted),
                ),
              ),
              const Expanded(child: Divider(color: _fieldBorder)),
            ],
          ),
          const SizedBox(height: AegisSpacing.lg),

          // ── Demo mode ──────────────────────────────────────────
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _enterDemoMode,
              icon: const Icon(Icons.explore_outlined, size: 20),
              label: Text(
                'Explore App Demo Features',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _navy,
                backgroundColor: Colors.white,
                side: const BorderSide(color: _fieldBorder, width: 1.2),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(AegisRadius.md)),
                ),
              ),
            ),
          ),
          const SizedBox(height: AegisSpacing.md),

          // ── Sign up link ───────────────────────────────────────
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                "Don't have an account?",
                style: GoogleFonts.outfit(fontSize: 14, color: _inkMuted),
              ),
              TextButton(
                onPressed: () => RegisterScreen.open(
                  context,
                  // After sign-up, open the dashboard just like a normal sign-in.
                  onRegistered: () => Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                    (route) => false,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: _navyLight,
                  padding: const EdgeInsets.symmetric(horizontal: AegisSpacing.xs),
                ),
                child: Text(
                  'Sign Up',
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: AegisSpacing.md),

          // ── Footer ─────────────────────────────────────────────
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
    );
  }
}

/// Clips the header into a gentle downward curve at the bottom.
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

/// The Aegis logo, fading in when the page opens and then gently fading
/// out and back in. Stays still when the system "reduce motion" setting is on.
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
        // Glides between 35% and 100% opacity and back each cycle.
        final breath = 0.5 + 0.5 * math.cos(2 * math.pi * _pulse.value);
        return Opacity(opacity: intro * (0.35 + 0.65 * breath), child: child);
      },
      child: logo,
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const ActiveWalkDashboardScreen(),
    const ActivityFeedScreen(),
    const TrustedContactsListScreen(),
    const ProfileScreen(),
    const RouteComparisonScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AegisColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AegisColors.surfaceContainerLow,
          border: Border(
            top: BorderSide(color: AegisColors.surfaceContainerHighest, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: AegisColors.surfaceContainerLow,
          selectedItemColor: AegisColors.primary,
          unselectedItemColor: AegisColors.textSecondary,
          selectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: GoogleFonts.outfit(fontSize: 12),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.directions_walk),
              activeIcon: Icon(Icons.directions_walk_rounded),
              label: 'Walk',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_none_outlined),
              activeIcon: Icon(Icons.notifications_active),
              label: 'Activity',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Guardians',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.alt_route_outlined),
              activeIcon: Icon(Icons.alt_route),
              label: 'Routes',
            ),
          ],
        ),
      ),
    );
  }
}

class ActiveWalkDashboardScreen extends StatefulWidget {
  const ActiveWalkDashboardScreen({super.key});

  @override
  State<ActiveWalkDashboardScreen> createState() => _ActiveWalkDashboardScreenState();
}

class _ActiveWalkDashboardScreenState extends State<ActiveWalkDashboardScreen> {
  bool _isTripActive = false;

  void _toggleWalk() {
    setState(() => _isTripActive = !_isTripActive);
    final msg = _isTripActive
        ? 'Live GPS trip sharing active! Guardians notified.'
        : 'Trip ended safely. Arrival broadcasted to guardians.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.outfit()),
        backgroundColor: _isTripActive ? AegisColors.tertiary : AegisColors.primary,
      ),
    );
  }

  void _triggerCheckIn() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AegisColors.surfaceContainerHigh,
        title: Text('Aegis Silent Check-in', style: GoogleFonts.outfit(color: AegisColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Text('Are you safe? Confirming resets safety timer for your active guardians.', style: GoogleFonts.outfit(color: AegisColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('SOS Alert Escalated! Emergency contacts dispatched.', style: GoogleFonts.outfit()),
                  backgroundColor: AegisColors.secondary,
                ),
              );
            },
            child: Text('Escalate SOS', style: GoogleFonts.outfit(color: AegisColors.secondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Silent Check-in Confirmed. Guardians updated.', style: GoogleFonts.outfit()),
                  backgroundColor: AegisColors.tertiary,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AegisColors.tertiary),
            child: Text('I am Safe', style: GoogleFonts.outfit(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AegisColors.background,
      appBar: AppBar(
        title: Text('Aegis Live Walk', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: AegisColors.primary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AegisColors.textSecondary),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AegisSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Container(
              padding: const EdgeInsets.all(AegisSpacing.xl),
              decoration: BoxDecoration(
                color: AegisColors.surfaceContainerHigh,
                borderRadius: AegisRadius.xxlAll,
                border: Border.all(
                  color: _isTripActive ? AegisColors.tertiary : AegisColors.surfaceContainerHighest,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isTripActive ? AegisColors.tertiary : AegisColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: AegisSpacing.md),
                      Text(
                        _isTripActive ? 'LIVE TRIP ACTIVE' : 'INACTIVE',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: _isTripActive ? AegisColors.tertiary : AegisColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AegisSpacing.lg),
                  Text(
                    _isTripActive ? 'Sharing GPS & ETA with Guardians' : 'Ready to Start Walk',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AegisColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AegisSpacing.sm),
                  Text(
                    _isTripActive
                        ? 'Destination: Home (1.2 km away) • ETA: 12 mins'
                        : 'Tap below to enable live location streaming & automated check-ins.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: AegisColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AegisSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _toggleWalk,
                      icon: Icon(_isTripActive ? Icons.stop : Icons.play_arrow),
                      label: Text(
                        _isTripActive ? 'End Live Sharing' : 'Start Live Safe Walk',
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isTripActive ? AegisColors.secondary : AegisColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: AegisRadius.lgAll,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AegisSpacing.xl),
            // Live unresolved alert + most recent trip
            const RecentActivityPreview(),
            const SizedBox(height: AegisSpacing.xl),
            Text(
              'SAFETY SHORTCUTS',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: AegisColors.textSecondary,
              ),
            ),
            const SizedBox(height: AegisSpacing.md),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CompassScreen()),
                      );
                    },
                    borderRadius: AegisRadius.xlAll,
                    child: Container(
                      padding: const EdgeInsets.all(AegisSpacing.lg),
                      decoration: BoxDecoration(
                        color: AegisColors.surfaceContainerHigh,
                        borderRadius: AegisRadius.xlAll,
                        border: Border.all(color: AegisColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.explore_outlined, color: AegisColors.primary, size: 28),
                          const SizedBox(height: AegisSpacing.md),
                          Text(
                            'Find My Spot',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AegisColors.textPrimary),
                          ),
                          const SizedBox(height: AegisSpacing.xs),
                          Text(
                            'Open Compass',
                            style: GoogleFonts.outfit(fontSize: 12, color: AegisColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AegisSpacing.md),
                Expanded(
                  child: InkWell(
                    onTap: _triggerCheckIn,
                    borderRadius: AegisRadius.xlAll,
                    child: Container(
                      padding: const EdgeInsets.all(AegisSpacing.lg),
                      decoration: BoxDecoration(
                        color: AegisColors.surfaceContainerHigh,
                        borderRadius: AegisRadius.xlAll,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.timer_outlined, color: AegisColors.tertiary, size: 28),
                          const SizedBox(height: AegisSpacing.md),
                          Text(
                            'Silent Check-in',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AegisColors.textPrimary),
                          ),
                          const SizedBox(height: AegisSpacing.xs),
                          Text(
                            'Simulate prompt',
                            style: GoogleFonts.outfit(fontSize: 12, color: AegisColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AegisSpacing.md),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('SOS Beacon Triggered! Guardians & emergency services alerted.', style: GoogleFonts.outfit()),
                          backgroundColor: AegisColors.secondary,
                        ),
                      );
                    },
                    borderRadius: AegisRadius.xlAll,
                    child: Container(
                      padding: const EdgeInsets.all(AegisSpacing.lg),
                      decoration: BoxDecoration(
                        color: AegisColors.surfaceContainerHigh,
                        borderRadius: AegisRadius.xlAll,
                        border: Border.all(color: AegisColors.secondary.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.sos_rounded, color: AegisColors.secondary, size: 28),
                          const SizedBox(height: AegisSpacing.md),
                          Text(
                            'Panic SOS',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AegisColors.textPrimary),
                          ),
                          const SizedBox(height: AegisSpacing.xs),
                          Text(
                            'Broadcast emergency',
                            style: GoogleFonts.outfit(fontSize: 12, color: AegisColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AegisSpacing.md),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const TripHistoryScreen()),
                      );
                    },
                    borderRadius: AegisRadius.xlAll,
                    child: Container(
                      padding: const EdgeInsets.all(AegisSpacing.lg),
                      decoration: BoxDecoration(
                        color: AegisColors.surfaceContainerHigh,
                        borderRadius: AegisRadius.xlAll,
                        border: Border.all(color: AegisColors.tertiary.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.history_outlined, color: AegisColors.tertiary, size: 28),
                          const SizedBox(height: AegisSpacing.md),
                          Text(
                            'Trip History',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AegisColors.textPrimary),
                          ),
                          const SizedBox(height: AegisSpacing.xs),
                          Text(
                            'Past walks',
                            style: GoogleFonts.outfit(fontSize: 12, color: AegisColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
