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
    theme: AegisTheme.dark(),
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
      title: const Text('Aegis Safe Walk'),
      actions: [
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
    bottomNavigationBar: BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: _index,
      onTap: (value) => setState(() => _index = value),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.shield_outlined),
          label: 'Safety',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.notifications_outlined),
          label: 'Activity',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people_outline),
          label: 'Guardians',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.alt_route), label: 'Routes'),
      ],
    ),
  );
}
