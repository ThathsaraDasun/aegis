import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/trip_model.dart';
import '../../services/location_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/location_permission_prompt.dart';
import '../../theme/aegis_theme.dart';
import 'live_map_screen.dart';

class StartTripScreen extends StatefulWidget {
  const StartTripScreen({super.key});

  @override
  State<StartTripScreen> createState() => _StartTripScreenState();
}

class _StartTripScreenState extends State<StartTripScreen> {
  final _destinationController = TextEditingController();
  final _locationService = LocationService();
  final _firestoreService = FirestoreService();
  
  LocationStatus _locationStatus = LocationStatus.ready;
  bool _isCheckingStatus = true;
  bool _isStartingTrip = false;

  @override
  void initState() {
    super.initState();
    _initLocationStatus();
  }

  Future<void> _initLocationStatus() async {
    setState(() => _isCheckingStatus = true);
    final status = await _locationService.checkLocationStatus();
    if (mounted) {
      setState(() {
        _locationStatus = status;
        _isCheckingStatus = false;
      });
    }
  }

  Future<void> _handleStartTrip() async {
    // 1. Final check for location readiness
    final status = await _locationService.checkLocationStatus();
    if (status != LocationStatus.ready) {
      if (mounted) setState(() => _locationStatus = status);
      return;
    }

    setState(() => _isStartingTrip = true);

    try {
      // 2. Get current position for startLocation
      final position = await Geolocator.getCurrentPosition();
      final startGeoPoint = GeoPoint(position.latitude, position.longitude);

      // 3. Define destination
      // ASSUMPTION: For MVP, we use a simple dummy destination 0.01 degrees away (~1.1km)
      // since full places-autocomplete is out of scope.
      final destinationGeoPoint = GeoPoint(
        position.latitude + 0.01, 
        position.longitude + 0.01
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not authenticated");

      // 4. Create TripModel
      final newTrip = TripModel(
        tripId: '', // Set by Firestore
        userId: user.uid,
        status: 'active',
        startLocation: startGeoPoint,
        currentLocation: startGeoPoint,
        destination: destinationGeoPoint,
        startedAt: DateTime.now(),
      );

      // 5. Save to Firestore
      final tripId = await _firestoreService.createTrip(newTrip);

      // 6. Navigate to Live Map
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => LiveMapScreen(tripId: tripId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting trip: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isStartingTrip = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Start New Trip'),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isCheckingStatus) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_locationStatus != LocationStatus.ready) {
      return LocationPermissionPrompt(
        status: _locationStatus,
        onRetry: _initLocationStatus,
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.map_outlined, size: 80, color: AegisColors.primary),
          const SizedBox(height: 24),
          const Text(
            'Ready to start your walk?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Enter your destination to begin live sharing with your guardians.',
            style: TextStyle(color: AegisColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          TextField(
            controller: _destinationController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Destination Name',
              hintText: 'e.g. Home, Library, Station',
              prefixIcon: const Icon(Icons.place, color: AegisColors.secondary),
              filled: true,
              fillColor: AegisColors.surfaceContainerHigh,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Note: MVP uses a dummy destination based on current location.',
            style: TextStyle(fontSize: 12, color: AegisColors.textSecondary, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _isStartingTrip ? null : _handleStartTrip,
              style: ElevatedButton.styleFrom(
                backgroundColor: AegisColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isStartingTrip
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'START TRIP',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
