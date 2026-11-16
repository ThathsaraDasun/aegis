import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'screens/auth/auth_gate.dart';
import 'screens/safety/safety_shell.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/activity/activity_feed_screen.dart';
import 'screens/activity/trip_history_screen.dart';
import 'screens/contacts/contacts_list_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/route/compass_screen.dart';
import 'screens/route/route_comparison_screen.dart';
import 'services/auth_service.dart';
import 'services/alert_service.dart';
import 'theme/aegis_theme.dart';
import 'widgets/aegis_nav_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Unable to initialize Firebase. Check the app configuration and restart.',
            ),
          ),
        ),
      ),
    );
    return;
  }
  // Local notification permission is optional; denial must not block sign-in/SOS.
  try {
    await AlertService.instance.init();
  } catch (_) {}
  runApp(const AegisApp());
}

class AegisApp extends StatelessWidget {
  const AegisApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Aegis - Safe Walk',
    debugShowCheckedModeBanner: false,
    theme: AegisTheme.light(),
    home: SplashScreen(
      nextScreen: AuthGate(
        service: FirebaseAuthService(),
        signedInBuilder: (_) =>
            SafetyShell(homeBuilder: (_) => const MainNavigationScreen()),
      ),
    ),
  );
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _index = 0;
  final _screens = const [
    SafetyDashboard(),
    ActivityFeedScreen(),
    TrustedContactsListScreen(),
    ProfileScreen(),
    RouteComparisonScreen(),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: const Color(0xFF007FFF),
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: const Text('Aegis Safe Walk'),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: FilledButton.icon(
            key: const Key('appbar-real-sos'),
            onPressed: () => SafetyScope.of(context).manualSos(),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 2,
            ),
            icon: const Icon(Icons.sos, size: 20, color: Colors.white),
            label: const Text(
              'Real SOS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.5,
                color: Colors.white,
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Compass',
          icon: const Icon(Icons.explore_outlined),
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const CompassScreen())),
        ),
        IconButton(
          tooltip: 'Trip history',
          icon: const Icon(Icons.history),
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const TripHistoryScreen())),
        ),
        IconButton(
          tooltip: 'Sign out',
          icon: const Icon(Icons.logout),
          onPressed: () async {
            try {
              await FirebaseAuth.instance.signOut();
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
              }
            }
          },
        ),
      ],
    ),
    body: IndexedStack(index: _index, children: _screens),
    bottomNavigationBar: AegisNavBar(
      currentIndex: _index,
      onTap: (value) => setState(() => _index = value),
      centerItem: const AegisNavItem(
        icon: Icons.shield_outlined,
        activeIcon: Icons.shield,
        label: 'Safety',
        index: 0,
      ),
      leftItems: const [
        AegisNavItem(
          icon: Icons.notifications_outlined,
          activeIcon: Icons.notifications,
          label: 'Activity',
          index: 1,
        ),
        AegisNavItem(
          icon: Icons.people_outline,
          activeIcon: Icons.people,
          label: 'Guardians',
          index: 2,
        ),
      ],
      rightItems: const [
        AegisNavItem(
          icon: Icons.alt_route,
          activeIcon: Icons.alt_route,
          label: 'Routes',
          index: 4,
        ),
        AegisNavItem(
          icon: Icons.person_outline,
          activeIcon: Icons.person,
          label: 'Profile',
          index: 3,
        ),
      ],
    ),
  );
}
