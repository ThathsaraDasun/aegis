import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../alert_service.dart';
import '../firestore_service.dart';
import '../live_sharing_service.dart';

abstract class SosGateway {
  Future<AlertTriggerResult> trigger(String type, String requestId);
  Future<void> resolve(String alertId);
}

class SafetyException implements Exception {
  final String message;
  const SafetyException(this.message);
}

/// Adapter to Member 4's API. No demo coordinates or unverified last-known fix.
class BackendSosGateway implements SosGateway {
  @override
  Future<AlertTriggerResult> trigger(String type, String requestId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const SafetyException('Sign in before triggering SOS.');
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const SafetyException(
        'Turn on location services and retry. No alert was sent.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const SafetyException(
        'Location permission is needed. Enable it in Settings and retry.',
      );
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
      throw const SafetyException(
        'A fresh GPS position is unavailable. Move to an open area and retry.',
      );
    }
    if (DateTime.now().difference(position.timestamp).abs() >
            const Duration(seconds: 30) ||
        !position.accuracy.isFinite ||
        position.accuracy > 100) {
      throw const SafetyException(
        'GPS is too old or inaccurate for SOS. Try again with a clear GPS signal.',
      );
    }
    // A trip is optional: inability to load it must not block a standalone SOS.
    String? tripId;
    try {
      tripId =
          (await FirestoreService.instance
                  .streamActiveTrip(user.uid)
                  .first
                  .timeout(const Duration(seconds: 3)))
              ?.tripId;
    } catch (_) {}
    if (FirebaseAuth.instance.currentUser?.uid != user.uid) {
      throw const SafetyException(
        'Your account changed. Sign in and try again.',
      );
    }
    return AlertService.instance.triggerAlert(
      userId: user.uid,
      type: type,
      lat: position.latitude,
      lng: position.longitude,
      tripId: tripId,
      requestId: requestId,
      fixTime: position.timestamp,
      accuracy: position.accuracy,
    );
  }

  @override
  Future<void> resolve(String alertId) async {
    await LiveSharingService.stop();
    await FirestoreService.instance
        .resolveAlert(alertId)
        .timeout(const Duration(seconds: 10));
  }
}
