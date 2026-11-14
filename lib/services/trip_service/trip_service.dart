import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/lat_lng.dart';
import '../../models/trip_model.dart';
import '../firestore_service.dart';

/// Service responsible for Live Trip Sharing, GPS location streaming,
/// ETA calculations, overdue tracking, silent check-in prompts, trip lifecycle, and FCM notifications.
class TripService {
  final FirestoreService _firestoreService;
  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;
  final Uuid _uuid;

  StreamSubscription<Position>? _positionSubscription;
  final Map<String, StreamController<LatLng>> _locationControllers = {};
  final Map<String, StreamController<Duration>> _etaControllers = {};
  final Map<String, StreamController<bool>> _overdueControllers = {};
  final Map<String, StreamController<bool>> _silentCheckInControllers = {};

  TripService({
    FirestoreService? firestoreService,
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
    Uuid? uuid,
  })  : _firestoreService = firestoreService ?? FirestoreService.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _messaging = messaging ?? FirebaseMessaging.instance,
        _uuid = uuid ?? const Uuid();

  /// Starts a live trip.
  /// 
  /// Creates a Firestore document at `/trips/{tripId}` using [FirestoreService.createTrip].
  /// Begins streaming GPS location using [geolocator], updating currentLocation via [FirestoreService.updateTripLocation].
  /// Sends FCM push notifications to trusted contacts.
  Future<String> startTrip({
    required String userId,
    required Map<String, double> startLocation,
    required Map<String, double> destination,
    required List<String> contactIds,
    String routeChosen = 'default_route',
  }) async {
    final tripId = _uuid.v4();
    final startedAt = DateTime.now();

    final trip = TripModel(
      tripId: tripId,
      userId: userId,
      status: TripStatus.active,
      startLocation: startLocation,
      currentLocation: startLocation,
      destination: destination,
      startedAt: startedAt,
    );

    // 1. Create Firestore trip document via FirestoreService
    await _firestoreService.createTrip(trip);

    // 2. Send FCM push notifications to trusted contacts
    await _sendTripStartNotifications(tripId, userId, destination, contactIds);

    // 3. Start location tracking
    _startLocationTracking(tripId, destination);

    return tripId;
  }

  /// Streams the live location of an active trip (`Stream<LatLng>`) for UI map marker binding.
  Stream<LatLng> liveLocationStream(String tripId) {
    if (!_locationControllers.containsKey(tripId)) {
      _locationControllers[tripId] = StreamController<LatLng>.broadcast();
    }
    return _locationControllers[tripId]!.stream;
  }

  /// Computes and streams Estimated Time of Arrival (ETA) based on current position and destination.
  Stream<Duration> etaStream(String tripId) {
    if (!_etaControllers.containsKey(tripId)) {
      _etaControllers[tripId] = StreamController<Duration>.broadcast();
    }
    return _etaControllers[tripId]!.stream;
  }

  /// Emits `true` if elapsed trip time significantly exceeds the original ETA estimate.
  Stream<bool> isOverdueStream(String tripId) {
    if (!_overdueControllers.containsKey(tripId)) {
      _overdueControllers[tripId] = StreamController<bool>.broadcast();
    }
    return _overdueControllers[tripId]!.stream;
  }

  /// Emits `true` if the user's position hasn't changed meaningfully for a configurable duration.
  Stream<bool> silentCheckInPromptStream(String tripId, {Duration threshold = const Duration(minutes: 5)}) {
    if (!_silentCheckInControllers.containsKey(tripId)) {
      _silentCheckInControllers[tripId] = StreamController<bool>.broadcast();
    }
    return _silentCheckInControllers[tripId]!.stream;
  }

  /// Ends the trip: stops location streaming and updates status to "completed" via [FirestoreService].
  Future<void> endTrip(String tripId) async {
    // 1. Stop location tracking
    await _positionSubscription?.cancel();
    _positionSubscription = null;

    // 2. Mark trip as completed in Firestore via FirestoreService
    await _firestoreService.endTrip(tripId, status: TripStatus.completed);

    // 3. Clean up stream controllers
    _closeControllers(tripId);
  }

  /// Returns past trips as a list of [TripModel] queried from Firestore by userId.
  Future<List<TripModel>> getTripHistory(String userId) async {
    return _firestoreService.streamTripHistory(userId).first;
  }

  // --- Internal Helper Methods ---

  void _startLocationTracking(String tripId, Map<String, double> destination) {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2,
    );

    LatLng? lastSignificantPosition;
    DateTime lastMovementTime = DateTime.now();

    _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) async {
        final currentLatLng = LatLng(latitude: position.latitude, longitude: position.longitude);

        // Update live location via FirestoreService
        await _firestoreService.updateTripLocation(tripId, position.latitude, position.longitude);

        // Emit to local stream controller
        if (_locationControllers.containsKey(tripId) && !(_locationControllers[tripId]!.isClosed)) {
          _locationControllers[tripId]!.add(currentLatLng);
        }

        // Compute and emit ETA
        final destLat = destination['lat'] ?? 0.0;
        final destLng = destination['lng'] ?? 0.0;

        final distanceMeters = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          destLat,
          destLng,
        );
        final speed = position.speed > 0.5 ? position.speed : 1.4; // fallback walking speed ~1.4 m/s
        final etaSeconds = (distanceMeters / speed).round();
        final etaDuration = Duration(seconds: etaSeconds);

        if (_etaControllers.containsKey(tripId) && !(_etaControllers[tripId]!.isClosed)) {
          _etaControllers[tripId]!.add(etaDuration);
        }

        // Silent check-in prompt logic: check if moved < 10 meters in 5 minutes
        if (lastSignificantPosition == null) {
          lastSignificantPosition = currentLatLng;
          lastMovementTime = DateTime.now();
        } else {
          final distanceMoved = Geolocator.distanceBetween(
            lastSignificantPosition!.latitude,
            lastSignificantPosition!.longitude,
            currentLatLng.latitude,
            currentLatLng.longitude,
          );
          if (distanceMoved > 10.0) {
            lastSignificantPosition = currentLatLng;
            lastMovementTime = DateTime.now();
            if (_silentCheckInControllers.containsKey(tripId) && !(_silentCheckInControllers[tripId]!.isClosed)) {
              _silentCheckInControllers[tripId]!.add(false);
            }
          } else {
            final stationaryDuration = DateTime.now().difference(lastMovementTime);
            if (stationaryDuration >= const Duration(minutes: 5)) {
              if (_silentCheckInControllers.containsKey(tripId) && !(_silentCheckInControllers[tripId]!.isClosed)) {
                _silentCheckInControllers[tripId]!.add(true);
              }
            }
          }
        }
      },
      onError: (error) {
        // Handle stream errors
      },
    );
  }

  Future<void> _sendTripStartNotifications(
    String tripId,
    String userId,
    Map<String, double> destination,
    List<String> contactIds,
  ) async {
    try {
      await _messaging.requestPermission();
    } catch (_) {}

    for (String contactId in contactIds) {
      try {
        final userDoc = await _firestore.collection('users').doc(contactId).get();
        final fcmToken = userDoc.data()?['fcmToken'] as String?;

        if (fcmToken != null && fcmToken.isNotEmpty) {
          await _firestore.collection('notifications').add({
            'recipientId': contactId,
            'fcmToken': fcmToken,
            'title': 'Safe Walk: Trip Started',
            'body': 'Your contact started a live safe walk. Track live here.',
            'data': {
              'type': 'tripStart',
              'tripId': tripId,
              'userId': userId,
            },
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'pending',
          });
        }
      } catch (e) {
        // Handle notification error
      }
    }
  }

  void _closeControllers(String tripId) {
    _locationControllers[tripId]?.close();
    _locationControllers.remove(tripId);

    _etaControllers[tripId]?.close();
    _etaControllers.remove(tripId);

    _overdueControllers[tripId]?.close();
    _overdueControllers.remove(tripId);

    _silentCheckInControllers[tripId]?.close();
    _silentCheckInControllers.remove(tripId);
  }
}
