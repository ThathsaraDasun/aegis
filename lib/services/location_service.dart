import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'firestore_service.dart';

/// Enum to represent the state of location readiness
enum LocationStatus {
  ready,
  serviceDisabled,
  permissionDenied,
  permissionPermanentlyDenied,
}

class LocationService {
  final FirestoreService _firestoreService = FirestoreService();

  /// Expose a single [Stream] of positions live location updates
  /// Sensible accuracy/distanceFilter settings suited to walking speed (~1.4 m/s)
  Stream<Position> livePositionStream() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter:
          10, // 10 meters helps balance accuracy vs battery/write-spam
    );
    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }

  /// Request/check location permissions and handle states gracefully
  Future<LocationStatus> checkLocationStatus() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationStatus.serviceDisabled;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationStatus.permissionDenied;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationStatus.permissionPermanentlyDenied;
    }

    return LocationStatus.ready;
  }

  /// Pushes a new position into the trip's currentLocation field in Firestore
  /// via firestore_service.dart
  Future<void> updateFirestoreLocation(String tripId, Position position) async {
    await _firestoreService.updateTripLocation(
      tripId,
      position.latitude,
      position.longitude,
    );
  }
}
