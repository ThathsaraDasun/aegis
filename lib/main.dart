import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/route/compass_screen.dart';

import 'screens/contacts/contacts_list_screen.dart';
import 'screens/route/report_hazard_screen.dart';
import 'screens/route/route_comparison_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/route/compass_screen.dart';
import 'screens/activity/trip_history_screen.dart';
import 'widgets/alert_banner.dart';
import 'widgets/trip_card.dart';
import 'models/alert_model.dart';
import 'models/trip_model.dart';
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
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AegisColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AegisColors.primary,
          primary: AegisColors.primary,
          secondary: AegisColors.secondary,
          surface: AegisColors.surfaceContainerLow,
        ),
        appBarTheme: AppBarTheme(
          centerTitle: true,
          backgroundColor: AegisColors.surfaceContainerLow,
          foregroundColor: AegisColors.textPrimary,
          titleTextStyle: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AegisColors.textPrimary,
          ),
        ),
      ),
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
    } catch (e) {
      if (mounted) {
        // If login fails (e.g. mock environment), bypass to main dashboard for demo
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _enterDemoMode() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AegisColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AegisColors.surfaceContainerHigh,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AegisColors.primary.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      size: 64,
                      color: AegisColors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'AEGIS SAFE WALK',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: AegisColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Smart Safety & Guardian Network',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: AegisColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 36),
                  TextField(
                    controller: _emailController,
                    style: GoogleFonts.outfit(color: AegisColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      labelStyle: GoogleFonts.outfit(color: AegisColors.textSecondary),
                      prefixIcon: const Icon(Icons.email_outlined, color: AegisColors.textSecondary),
                      filled: true,
                      fillColor: AegisColors.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: GoogleFonts.outfit(color: AegisColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: GoogleFonts.outfit(color: AegisColors.textSecondary),
                      prefixIcon: const Icon(Icons.lock_outline, color: AegisColors.textSecondary),
                      filled: true,
                      fillColor: AegisColors.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AegisColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'Sign In',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: _enterDemoMode,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AegisColors.primary, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                    ),
                    child: Text(
                      'Explore App Demo Features',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AegisColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
    const TrustedContactsListScreen(),
    const RouteComparisonScreen(),
    const ReportHazardScreen(),
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
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Guardians',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.alt_route_outlined),
              activeIcon: Icon(Icons.alt_route),
              label: 'Routes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.warning_amber_rounded),
              activeIcon: Icon(Icons.warning),
              label: 'Report',
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
    // Dummy Data for Previewing Widgets
    final dummyAlert = AlertModel(
      alertId: "a1",
      tripId: "t1",
      userId: "u1",
      type: "fall_detected",
      location: {"lat": 6.9271, "lng": 79.8612},
      triggeredAt: DateTime.now(),
      resolved: false,
    );

    final dummyTrip = TripModel(
      tripId: "t1",
      userId: "u1",
      status: "completed",
      startLocation: {"lat": 6.9271, "lng": 79.8612},
      currentLocation: {"lat": 6.9275, "lng": 79.8615},
      destination: {"lat": 6.9344, "lng": 79.8451},
      startedAt: DateTime.now().subtract(const Duration(hours: 1)),
      endedAt: DateTime.now().subtract(const Duration(minutes: 10)),
    );

    return Scaffold(
      backgroundColor: AegisColors.background,
      appBar: AppBar(
        title: Text('Aegis Live Walk', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        actions: [
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
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Alert Banner Preview
            AlertBanner(
              alert: dummyAlert,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Alert details coming soon!")),
              ),
            ),
            const SizedBox(height: 16),

            // Status Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AegisColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(24),
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
                      const SizedBox(width: 12),
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
                  const SizedBox(height: 16),
                  Text(
                    _isTripActive ? 'Sharing GPS & ETA with Guardians' : 'Ready to Start Walk',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AegisColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 20),
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
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'RECENT TRIPS',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: AegisColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TripCard(
              trip: dummyTrip,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Trip history details coming soon!")),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'SAFETY SHORTCUTS',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: AegisColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
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
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AegisColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AegisColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.explore_outlined, color: AegisColors.primary, size: 28),
                          const SizedBox(height: 12),
                          Text(
                            'Find My Spot',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AegisColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Open Compass',
                            style: GoogleFonts.outfit(fontSize: 12, color: AegisColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _triggerCheckIn,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AegisColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.timer_outlined, color: AegisColors.tertiary, size: 28),
                          const SizedBox(height: 12),
                          Text(
                            'Silent Check-in',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AegisColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
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
            const SizedBox(height: 12),
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
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AegisColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AegisColors.secondary.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.sos_rounded, color: AegisColors.secondary, size: 28),
                          const SizedBox(height: 12),
                          Text(
                            'Panic SOS',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AegisColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Broadcast emergency',
                            style: GoogleFonts.outfit(fontSize: 12, color: AegisColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const TripHistoryScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AegisColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AegisColors.tertiary.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.history_outlined, color: AegisColors.tertiary, size: 28),
                          const SizedBox(height: 12),
                          Text(
                            'Trip History',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AegisColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
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
