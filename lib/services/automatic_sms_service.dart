import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'contacts_service.dart';
import 'firestore_service.dart';

class AutomaticSmsService {
  static const _channel = MethodChannel('aegis/fall_monitor');
  static bool enabled = false;
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Enables automatic SMS for every guardian with a valid number. Returns how
  /// many numbers will receive SMS and the names of guardians skipped because
  /// their number is invalid (they should fix it in the Guardians tab).
  static Future<({int count, List<String> skipped})> enable() async {
    if (!supported) throw StateError('Automatic SIM SMS requires Android.');
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Sign in first.');
    final store = FirestoreService.instance;
    final contacts = await store
        .getContacts(uid)
        .timeout(const Duration(seconds: 10));
    final profile = await store
        .getUserProfile(uid)
        .timeout(const Duration(seconds: 10));
    final valid = RegExp(r'^\+[1-9][0-9]{6,14}$');
    final phones = <String>{};
    final skipped = <String>[];
    for (final c in contacts.where((c) => !c.id.startsWith('demo_'))) {
      final phone = ContactsService.normalizePhone(c.phone);
      if (valid.hasMatch(phone)) {
        phones.add(phone);
      } else {
        skipped.add(c.name.isEmpty ? c.phone : c.name);
      }
    }
    if (phones.isEmpty) {
      throw StateError(
        skipped.isEmpty
            ? 'Add a guardian with a mobile number first (Guardians tab).'
            : 'Fix the phone number of ${skipped.join(', ')} in the Guardians tab (e.g. 0771234567), then try again.',
      );
    }
    if (phones.length > 10) {
      throw StateError('Automatic SMS supports up to 10 guardians.');
    }
    if (await _channel.invokeMethod<bool>('smsPermission') != true) {
      throw StateError(
        'SMS permission was not granted. Manual messaging remains available.',
      );
    }
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      throw StateError('Your account changed. Please retry.');
    }
    await _channel.invokeMethod('smsConfigure', {
      'uid': uid,
      'phones': phones.toList(),
      'name': profile?.name ?? 'Aegis user',
    });
    enabled = true;
    return (count: phones.length, skipped: skipped);
  }

  static Future<void> disable() async {
    enabled = false;
    if (supported) await _channel.invokeMethod('smsDisable');
  }

  /// Sends a trip start/end message to guardians from the SIM, automatically.
  ///
  /// Unlike [send] (SOS), this does not need the "Automatic guardian SMS"
  /// opt-in and does not change it; it asks for SMS permission once. Returns
  /// a `blocked` state (so the app offers manual SMS/WhatsApp instead) when
  /// permission is denied or the phone has no SMS SIM.
  static Future<Map<dynamic, dynamic>> sendTripMessage({
    required String id,
    required String uid,
    required List<String> phones,
    required String message,
  }) async {
    if (!supported) {
      return {'state': 'blocked', 'message': 'Automatic SMS needs Android.'};
    }
    if (await _channel.invokeMethod<bool>('smsPermission') != true) {
      return {'state': 'blocked', 'message': 'SMS permission was not granted.'};
    }
    return await _channel
            .invokeMapMethod('smsSendTrip', {
              'id': id,
              'phones': phones,
              'message': message,
            })
            .timeout(const Duration(seconds: 25)) ??
        {
          'state': 'uncertain',
          'message': 'SMS result unknown. Check Messages before trying again.',
        };
  }

  static Future<Map<dynamic, dynamic>> send({
    required String id,
    required String uid,
    required List<String> phones,
    required String message,
  }) async {
    if (!enabled) {
      return {'state': 'blocked', 'message': 'Automatic SMS is off.'};
    }
    return await _channel
            .invokeMapMethod('smsSend', {
              'id': id,
              'uid': uid,
              'phones': phones,
              'message': message,
            })
            .timeout(const Duration(seconds: 25)) ??
        {
          'state': 'uncertain',
          'message': 'SMS result unknown. Check Messages before trying again.',
        };
  }
}
