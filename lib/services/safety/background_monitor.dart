import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/alert_model.dart';
import '../firestore_service.dart';
import '../alert_service.dart';

class BackgroundMonitor {
  Future<AlertTriggerResult> recordSmsResult(
    Map<dynamic, dynamic> state,
  ) async {
    final id = state['eventId'] as String;
    final sms = state['sms'] as Map;
    final uid = state['uid'] as String;
    bool recorded = false;
    if (FirebaseAuth.instance.currentUser?.uid == uid) {
      try {
        await FirestoreService.instance
            .createAlert(
              AlertModel(
                alertId: id,
                tripId: '',
                userId: uid,
                type: AlertType.fallDetected,
                location: state['lat'] is num && state['lng'] is num
                    ? {
                        'lat': (state['lat'] as num).toDouble(),
                        'lng': (state['lng'] as num).toDouble(),
                      }
                    : {},
                triggeredAt: DateTime.fromMillisecondsSinceEpoch(
                  (state['time'] as num).toInt(),
                ),
              ),
            )
            .timeout(const Duration(seconds: 10));
        recorded = true;
      } catch (_) {
        /* Sending does not depend on the database connection. */
      }
    }
    return AlertTriggerResult(
      alertId: id,
      contactCount: (sms['count'] as num? ?? 0).toInt(),
      smsOpened: false,
      dialerOpened: false,
      automaticSmsMessage: '${sms['message']}',
      recorded: recorded,
      liveLocationUrl: (state['liveUrl'] as String?)?.isNotEmpty == true
          ? state['liveUrl'] as String
          : null,
    );
  }

  Future<bool> claim() async =>
      await _channel.invokeMethod<bool>('claim') == true;
  static const _channel = MethodChannel('aegis/fall_monitor');
  Future<void> start(bool demo) async {
    if (await _channel.invokeMethod<bool>('permission') != true) {
      throw PlatformException(
        code: 'notifications',
        message:
            'Allow notifications in Android Settings to enable fall protection.',
      );
    }
    await _channel.invokeMethod('start', {'demo': demo});
  }

  Future<Map<dynamic, dynamic>> state() async =>
      await _channel.invokeMapMethod('state') ?? {};
  Future<void> stop() => _channel.invokeMethod('stop');
  Future<void> cancel() => _channel.invokeMethod('cancel');
  Future<void> setDemo(bool demo) =>
      _channel.invokeMethod('demo', {'demo': demo});
}
