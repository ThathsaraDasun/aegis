import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/contacts/contacts_list_screen.dart';
import 'screens/route/route_comparison_screen.dart';
import 'screens/trip/start_trip_screen.dart';
import 'screens/splash/splash_screen.dart';

import 'screens/route/compass_screen.dart';
import 'screens/activity/trip_history_screen.dart';
import 'screens/activity/activity_feed_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'widgets/alert_banner.dart';
import 'widgets/trip_card.dart';
import 'models/alert_model.dart';
import 'models/trip_model.dart';
import 'theme/aegis_theme.dart';
import 'services/alert_service.dart';
import 'services/firestore_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'services/auth_service.dart';
import 'screens/auth/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
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
  // Notification permission failure must not block authentication.
  try {
    await AlertService.instance.init();
  } catch (_) {}
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
      home: SplashScreen(
        nextScreen: AuthGate(
          service: FirebaseAuthService(),
          signedInBuilder: (_) => const MainNavigationScreen(),
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
    const ActivityFeedScreen(),
    const TrustedContactsListScreen(),
    const ProfileScreen(),
    const RouteComparisonScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AegisColors.background,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AegisColors.surfaceContainerLow,
          border: Border(
            top: BorderSide(
              color: AegisColors.surfaceContainerHighest,
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: AegisColors.surfaceContainerLow,
          selectedItemColor: AegisColors.primary,
          unselectedItemColor: AegisColors.textSecondary,
          selectedLabelStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
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
  State<ActiveWalkDashboardScreen> createState() =>
      _ActiveWalkDashboardScreenState();
}

class _ActiveWalkDashboardScreenState extends State<ActiveWalkDashboardScreen> {
  final bool _isTripActive = false;

  bool _sendingAlert = false;
  String? _pendingAlertId;
  String? _pendingType;

  Future<void> _triggerAlertHelper(String type) async {
    if (_sendingAlert) return;
    setState(() => _sendingAlert = true);
    void message(String text) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(text)));
      }
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        message('Sign in before triggering SOS.');
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        message('Turn on location services before retrying SOS.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        message('Enable location permission in Settings before retrying SOS.');
        return;
      }
      final Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
      } catch (_) {
        message(
          'A fresh GPS fix is unavailable. Please retry with a clear GPS signal.',
        );
        return;
      }
      if (DateTime.now().difference(position.timestamp).abs() >
              const Duration(seconds: 30) ||
          !position.accuracy.isFinite ||
          position.accuracy > 100) {
        message('GPS is too old or inaccurate for SOS. Please retry.');
        return;
      }
      String? tripId;
      try {
        tripId =
            (await FirestoreService.instance
                    .streamActiveTrip(user.uid)
                    .first
                    .timeout(const Duration(seconds: 3)))
                ?.tripId;
      } catch (_) {}
      if (_pendingType != type || _pendingAlertId == null) {
        _pendingType = type;
        _pendingAlertId = const Uuid().v4();
      }
      final result = await AlertService.instance.triggerAlert(
        userId: user.uid,
        type: type,
        lat: position.latitude,
        lng: position.longitude,
        tripId: tripId,
        requestId: _pendingAlertId,
      );
      _pendingAlertId = null;
      message(
        result.smsOpened
            ? 'Alert recorded. SMS composer opened; tap Send to send the message.'
            : result.dialerOpened
            ? 'Alert recorded. Phone dialer opened; start the call yourself.'
            : result.contactCount == 0
            ? 'Alert recorded, but no usable guardian contacts were found. Nobody was contacted.'
            : 'Alert recorded, but contact apps could not open. Contact your guardian directly.',
      );
    } catch (e) {
      message('SOS could not complete. ${authErrorMessage(e)}');
    } finally {
      if (mounted) setState(() => _sendingAlert = false);
    }
  }

  void _triggerCheckIn() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AegisColors.surfaceContainerHigh,
        title: Text(
          'Aegis Silent Check-in',
          style: GoogleFonts.outfit(
            color: AegisColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you safe? Confirming resets safety timer for your active guardians.',
          style: GoogleFonts.outfit(color: AegisColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _triggerAlertHelper(AlertType.fallDetected);
            },
            child: Text(
              'Escalate SOS',
              style: GoogleFonts.outfit(color: AegisColors.secondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Check-in acknowledged on this device. No message was sent.',
                    style: GoogleFonts.outfit(),
                  ),
                  backgroundColor: AegisColors.tertiary,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AegisColors.tertiary,
            ),
            child: Text(
              'I am Safe',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
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
        title: Text(
          'Aegis Live Walk',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
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
                  color: _isTripActive
                      ? AegisColors.tertiary
                      : AegisColors.surfaceContainerHighest,
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
                          color: _isTripActive
                              ? AegisColors.tertiary
                              : AegisColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _isTripActive ? 'LIVE TRIP ACTIVE' : 'INACTIVE',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: _isTripActive
                              ? AegisColors.tertiary
                              : AegisColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isTripActive
                        ? 'Sharing GPS & ETA with Guardians'
                        : 'Ready to Start Walk',
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
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const StartTripScreen(),
                          ),
                        );
                      },
                      icon: Icon(_isTripActive ? Icons.stop : Icons.play_arrow),
                      label: Text(
                        _isTripActive
                            ? 'End Live Sharing'
                            : 'Start Live Safe Walk',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isTripActive
                            ? AegisColors.secondary
                            : AegisColors.primary,
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
                const SnackBar(
                  content: Text("Trip history details coming soon!"),
                ),
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
                        MaterialPageRoute(
                          builder: (context) => const CompassScreen(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AegisColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AegisColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.explore_outlined,
                            color: AegisColors.primary,
                            size: 28,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Find My Spot',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: AegisColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Open Compass',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AegisColors.textSecondary,
                            ),
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
                          const Icon(
                            Icons.timer_outlined,
                            color: AegisColors.tertiary,
                            size: 28,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Silent Check-in',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: AegisColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Simulate prompt',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AegisColors.textSecondary,
                            ),
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
                    onTap: () => _triggerAlertHelper(AlertType.manualSos),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AegisColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AegisColors.secondary.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.sos_rounded,
                            color: AegisColors.secondary,
                            size: 28,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Panic SOS',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: AegisColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Broadcast emergency',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AegisColors.textSecondary,
                            ),
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
                        MaterialPageRoute(
                          builder: (context) => const TripHistoryScreen(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AegisColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AegisColors.tertiary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.history_outlined,
                            color: AegisColors.tertiary,
                            size: 28,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Trip History',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: AegisColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Past walks',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AegisColors.textSecondary,
                            ),
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
