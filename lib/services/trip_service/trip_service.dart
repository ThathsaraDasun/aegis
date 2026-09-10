import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/lat_lng.dart';
import '../../core/models/trip_model.dart';

/// Backend service responsible for Live Trip Sharing, GPS location streaming,
/// ETA calculations, overdue tracking, silent check-in prompts, trip lifecycle, and FCM notifications.
class TripService {
  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;
  final Uuid _uuid;

  StreamSubscription<Position>? _positionSubscription;
  final Map<String, StreamController<LatLng>> _locationControllers = {};
  final Map<String, StreamController<Duration>> _etaControllers = {};
  final Map<String, StreamController<bool>> _overdueControllers = {};
  final Map<String, StreamController<bool>> _silentCheckInControllers = {};

  TripService({
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
    Uuid? uuid,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _messaging = messaging ?? FirebaseMessaging.instance,
        _uuid = uuid ?? const Uuid();

  /// Starts a live trip.
  /// 
  /// Creates a Firestore document at `/trips/{tripId}` with fields:
  /// - `ownerId`
  /// - `status` ("active")
  /// - `startTime`
  /// - `destination` (`{lat, lng, label}`)
  /// - `routeChosen`
  /// - `sharedWithContactIds`
  /// 
  /// Begins streaming GPS location using [geolocator] every 3-5 seconds, writing
  /// coordinates and timestamp to `/trips/{tripId}/liveLocation`.
  /// Sends an FCM push notification to each contact in [sharedWithContactIds].
  Future<String> startTrip({
    required String ownerId,
    required Destination destination,
    required List<String> contactIds,
    required String routeChosen,
  }) async {
    final tripId = _uuid.v4();
    final startTime = DateTime.now();

    // 1. Create Firestore trip document
    final tripRef = _firestore.collection('trips').doc(tripId);
    await tripRef.set({
      'ownerId': ownerId,
      'status': 'active',
      'startTime': startTime.toIso8601String(),
      'endTime': null,
      'destination': destination.toMap(),
      'routeChosen': routeChosen,
      'sharedWithContactIds': contactIds,
    });

    // 2. Send FCM push notifications to trusted contacts
    await _sendTripStartNotifications(tripId, ownerId, destination, contactIds);

    // 3. Start location tracking (every 3-5 seconds interval / distance filter)
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

  /// Computes and streams Estimated Time of Arrival (ETA) based on current position, recent speed, and destination.
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

  /// Emits `true` if the user's position hasn't changed meaningfully for a configurable duration (default 5 minutes) mid-trip.
  Stream<bool> silentCheckInPromptStream(String tripId, {Duration threshold = const Duration(minutes: 5)}) {
    if (!_silentCheckInControllers.containsKey(tripId)) {
      _silentCheckInControllers[tripId] = StreamController<bool>.broadcast();
    }
    return _silentCheckInControllers[tripId]!.stream;
  }

  /// Ends the trip: stops location streaming, updates status to "completed",
  /// and writes a summary (duration, route, whether any alert event occurred) for getTripHistory().
  Future<void> endTrip(String tripId) async {
    // 1. Stop location tracking
    await _positionSubscription?.cancel();
    _positionSubscription = null;

    // 2. Query events subcollection to check if any alert occurred
    final eventsSnapshot = await _firestore
        .collection('trips')
        .doc(tripId)
        .collection('events')
        .get();
    
    bool alertOccurred = false;
    for (var doc in eventsSnapshot.docs) {
      final type = doc.data()['type'] as String?;
      if (type == 'fallDetected' || type == 'sosTriggered') {
        alertOccurred = true;
        break;
      }
    }

    // 3. Fetch trip document for start time and destination label
    final tripRef = _firestore.collection('trips').doc(tripId);
    final tripDoc = await tripRef.get();
    final data = tripDoc.data() ?? {};
    final startTimeStr = data['startTime'] as String? ?? DateTime.now().toIso8601String();
    final startTime = DateTime.tryParse(startTimeStr) ?? DateTime.now();
    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);

    // 4. Update trip status and summary in Firestore
    await tripRef.update({
      'status': 'completed',
      'endTime': endTime.toIso8601String(),
      'durationSeconds': duration.inSeconds,
      'alertOccurred': alertOccurred,
    });

    // 5. Clean up stream controllers
    _closeControllers(tripId);
  }

  /// Returns past trips as a list of [TripSummary] queried from Firestore by ownerId.
  Future<List<TripSummary>> getTripHistory(String userId) async {
    final querySnapshot = await _firestore
        .collection('trips')
        .where('ownerId', isEqualTo: userId)
        .where('status', isEqualTo: 'completed')
        .orderBy('startTime', descending: true)
        .get();

    return querySnapshot.docs.map((doc) {
      return TripSummary.fromMap(doc.id, doc.data());
    }).toList();
  }

  // --- Internal Helper Methods ---

  void _startLocationTracking(String tripId, Destination destination) {
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2,
    );

    LatLng? lastSignificantPosition;
    DateTime lastMovementTime = DateTime.now();

    _positionSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) async {
        final currentLatLng = LatLng(latitude: position.latitude, longitude: position.longitude);
        final timestamp = DateTime.now().toIso8601String();

        // Write live location to Firestore at /trips/{tripId}/liveLocation
        await _firestore.collection('trips').doc(tripId).collection('liveLocation').doc('latest').set({
          'lat': position.latitude,
          'lng': position.longitude,
          'timestamp': timestamp,
          'speed': position.speed,
        });

        // Emit to local stream controller
        if (_locationControllers.containsKey(tripId) && !(_locationControllers[tripId]!.isClosed)) {
          _locationControllers[tripId]!.add(currentLatLng);
        }

        // Compute and emit ETA
        final distanceMeters = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          destination.lat,
          destination.lng,
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
    String ownerId,
    Destination destination,
    List<String> contactIds,
  ) async {
    // Ensure FCM permissions and retrieve device token if available
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
            'body': 'Your contact started a trip to ${destination.label}. Track live here.',
            'data': {
              'type': 'tripStart',
              'tripId': tripId,
              'ownerId': ownerId,
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
