import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Result of asking for the device position.
class PositionResult {
  final LatLng position;

  /// True when the real GPS fix was used; false means [fallback] was used.
  final bool isLive;

  /// Why GPS was not used (null when [isLive]).
  final String? reason;

  const PositionResult(this.position, {required this.isLive, this.reason});
}

/// One-shot GPS lookup for the Safe Route screens (hazard pin, route origin).
///
/// Live trip streaming belongs to Member 2's LocationService – this helper only
/// grabs a single fix and never writes to Firestore.
class PositionHelper {
  PositionHelper._();

  /// Colombo Fort – used when GPS is off / denied so the demo still works.
  static final LatLng fallback = LatLng(6.9271, 79.8612);

  /// When [requestPermission] is false and permission hasn't been granted yet,
  /// returns the fallback instead of showing the system dialog.
  static Future<PositionResult> current({bool requestPermission = true}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return PositionResult(fallback, isLive: false, reason: 'Location services are off');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (!requestPermission) {
          return PositionResult(fallback, isLive: false, reason: 'Location permission not granted');
        }
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return PositionResult(fallback, isLive: false, reason: 'Location permission denied');
      }

      final last = await Geolocator.getLastKnownPosition();
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
        return PositionResult(LatLng(pos.latitude, pos.longitude), isLive: true);
      } catch (_) {
        if (last != null) {
          return PositionResult(LatLng(last.latitude, last.longitude), isLive: true);
        }
        rethrow;
      }
    } catch (_) {
      return PositionResult(fallback, isLive: false, reason: 'Could not get a GPS fix');
    }
  }
}
