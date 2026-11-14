import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/alert_model.dart';
import '../models/contact_model.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';

class AlertTriggerResult {
  final String alertId;
  final int contactCount;
  final bool smsOpened;
  final bool dialerOpened;
  const AlertTriggerResult({
    required this.alertId,
    required this.contactCount,
    required this.smsOpened,
    required this.dialerOpened,
  });
}

/// Member 4's public API, hardened for Member 1's foreground SOS integration.
/// An opened composer/dialer is never treated as confirmed remote delivery.
class AlertService {
  final FirestoreService _firestoreService;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final Future<bool> Function(Uri) _launch;
  final String? Function() _currentUserId;
  final Future<void> Function(String, String)? _notificationOverride;
  static final AlertService instance = AlertService();

  AlertService({
    FirestoreService? firestoreService,
    FlutterLocalNotificationsPlugin? localNotifications,
    Future<bool> Function(Uri)? launchExternal,
    String? Function()? currentUserId,
    Future<void> Function(String, String)? showNotification,
  }) : _firestoreService = firestoreService ?? FirestoreService.instance,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin(),
       _launch =
           launchExternal ??
           ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication)),
       _currentUserId =
           currentUserId ?? (() => FirebaseAuth.instance.currentUser?.uid),
       _notificationOverride = showNotification;

  Future<void> init() async {
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<AlertTriggerResult> triggerAlert({
    required String userId,
    required String type,
    required double lat,
    required double lng,
    String? tripId,
    String? requestId,
  }) async {
    _checkUser(userId);
    if (!AlertType.all.contains(type) ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat.abs() > 90 ||
        lng.abs() > 180) {
      throw ArgumentError('Invalid alert type or coordinates');
    }
    // Fail visibly on denied/network reads; do not silently treat an error as no contacts.
    final user = await _firestoreService
        .getUserProfile(userId)
        .timeout(const Duration(seconds: 8));
    final contacts =
        (await _firestoreService
                .getContacts(userId)
                .timeout(const Duration(seconds: 8)))
            .where((c) => !c.id.startsWith('demo_') && _phone(c).isNotEmpty)
            .toList();
    final phones = contacts.map(_phone).toSet().toList();
    _checkUser(userId);
    final alertId = await _firestoreService
        .createAlert(
          AlertModel(
            alertId: requestId ?? '',
            tripId: tripId ?? '',
            userId: userId,
            type: type,
            location: {'lat': lat, 'lng': lng},
            triggeredAt: DateTime.now(),
          ),
        )
        .timeout(const Duration(seconds: 10));
    if (tripId != null && tripId.isNotEmpty) {
      try {
        await _firestoreService
            .markTripAlerted(tripId)
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        /* The alert remains usable even if the optional trip update fails. */
      }
    }
    _checkUser(userId);
    bool smsOpened = false;
    bool dialerOpened = false;
    if (phones.isNotEmpty) {
      final message = buildMessage(
        user: user,
        type: type,
        lat: lat,
        lng: lng,
        tripId: tripId,
      );
      try {
        smsOpened = await _launch(
          Uri.parse(
            'sms:${phones.join(',')}?body=${Uri.encodeComponent(message)}',
          ),
        );
      } catch (_) {}
      if (!smsOpened && _currentUserId() == userId) {
        try {
          dialerOpened = await _launch(Uri.parse('tel:${phones.first}'));
        } catch (_) {}
      }
    }
    await _showLocalNotification(
      title: 'Safety alert recorded',
      body: phones.isEmpty
          ? 'No usable guardian contacts. Nobody was contacted.'
          : smsOpened
          ? 'SMS composer opened. Tap Send in your messaging app.'
          : dialerOpened
          ? 'Phone dialer opened. Start the call to reach your guardian.'
          : 'Contact options could not open. Reach your guardian directly.',
    );
    return AlertTriggerResult(
      alertId: alertId,
      contactCount: phones.length,
      smsOpened: smsOpened,
      dialerOpened: dialerOpened,
    );
  }

  void _checkUser(String uid) {
    if (uid.isEmpty || _currentUserId() != uid) {
      throw FirebaseAuthException(code: 'user-token-expired');
    }
  }

  static String _phone(ContactModel contact) {
    final phone = contact.phone.replaceAll(RegExp(r'[\s()-]'), '');
    return RegExp(r'^\+?[0-9]{7,15}$').hasMatch(phone) ? phone : '';
  }

  String buildMessage({
    UserModel? user,
    required String type,
    required double lat,
    required double lng,
    String? tripId,
  }) {
    final buffer = StringBuffer('SAFE WALK ALERT\n');
    buffer.writeln(
      type == AlertType.fallDetected
          ? 'Possible fall detected; the in-app countdown was not cancelled.'
          : 'Manual SOS activated. Please contact me.',
    );
    buffer.writeln(
      'User: ${user?.name.isNotEmpty == true ? user!.name : 'Aegis User'}',
    );
    buffer.writeln(
      'Location at alert time: https://maps.google.com/?q=$lat,$lng',
    );
    // Do not advertise a live viewer until a real authorized viewer is deployed.
    if (user != null) {
      if (user.bloodType.isNotEmpty) {
        buffer.writeln('Blood type: ${user.bloodType}');
      }
      if (user.allergies.isNotEmpty) {
        buffer.writeln('Allergies: ${user.allergies}');
      }
      if (user.emergencyNote.isNotEmpty) {
        buffer.writeln('Note: ${user.emergencyNote}');
      }
    }
    return buffer.toString().trim();
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
  }) async {
    try {
      if (_notificationOverride != null) {
        await _notificationOverride(title, body);
        return;
      }
      await _localNotifications.show(
        0,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'aegis_sos_channel',
            'Safety alerts',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (_) {
      /* Optional local notification must not undo the recorded alert. */
    }
  }
}
