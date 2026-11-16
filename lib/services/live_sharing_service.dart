import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android owns the location stream so sharing can continue with the screen locked.
class LiveSharingService {
  static const _channel = MethodChannel('aegis/live_sharing');
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<String?> start(
    String alertId,
    double lat,
    double lng, {
    DateTime? fixTime,
    double? accuracy,
  }) async {
    if (!supported) return null;
    try {
      return await _channel
          .invokeMethod<String>('start', {
            'alertId': alertId,
            'lat': lat,
            'lng': lng,
            'fixTime': fixTime?.millisecondsSinceEpoch,
            'accuracy': accuracy,
          })
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      // A sharing failure must not prevent the original SOS with its static location.
      return null;
    }
  }

  static Future<void> stop() async {
    if (!supported) return;
    final confirmed = await _channel
        .invokeMethod<bool>('stop')
        .timeout(const Duration(seconds: 10));
    if (confirmed != true) {
      throw PlatformException(
        code: 'sharing_stop_pending',
        message:
            'Location updates stopped, but the link could not be revoked online. '
            'It may show the last location until its one-hour expiry. Reconnect and retry.',
      );
    }
  }
}
