import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/alert_model.dart';
import '../models/contact_model.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';
import 'contacts_service.dart';
import 'automatic_sms_service.dart';
import 'live_sharing_service.dart';

class GuardianWhatsAppLink {
  final String name;
  final Uri uri;
  const GuardianWhatsAppLink(this.name, this.uri);
}

/// Identifies the failed SOS operation without exposing profile/contact data.
class AlertOperationException implements Exception {
  final String operation;
  final String code;
  const AlertOperationException(this.operation, this.code);
  String get message => code == 'permission-denied'
      ? 'Database access denied while $operation (permission-denied). Contact the team with this message.'
      : code == 'timeout'
      ? 'Timed out while $operation. Check your connection and retry.'
      : 'Could not complete $operation ($code). Please retry.';
}

class AlertTriggerResult {
  final String alertId;
  final int contactCount;
  final bool smsOpened;
  final bool dialerOpened;
  final List<GuardianWhatsAppLink> whatsAppLinks;
  final String? automaticSmsMessage;
  final bool recorded;
  final Uri? manualSmsUri;
  final String? liveLocationUrl;
  const AlertTriggerResult({
    required this.alertId,
    required this.contactCount,
    required this.smsOpened,
    required this.dialerOpened,
    this.whatsAppLinks = const [],
    this.automaticSmsMessage,
    this.recorded = true,
    this.manualSmsUri,
    this.liveLocationUrl,
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
    DateTime? fixTime,
    double? accuracy,
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
    final user = await _databaseStep(
      'reading your profile',
      () => _firestoreService
          .getUserProfile(userId)
          .timeout(const Duration(seconds: 8)),
    );
    final contacts = (await _databaseStep(
      'reading your guardian contacts',
      () => _firestoreService
          .getContacts(userId)
          .timeout(const Duration(seconds: 8)),
    )).where((c) => !c.id.startsWith('demo_') && _phone(c).isNotEmpty).toList();
    final phones = contacts.map(_phone).toSet().toList();
    _checkUser(userId);
    final alertId = await _databaseStep(
      'saving your SOS alert',
      () => _firestoreService
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
          .timeout(const Duration(seconds: 10)),
    );
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
    final liveLocationUrl = phones.isEmpty
        ? null
        : await LiveSharingService.start(
            alertId,
            lat,
            lng,
            fixTime: fixTime,
            accuracy: accuracy,
          );
    _checkUser(userId);
    final message = buildMessage(
      user: user,
      type: type,
      lat: lat,
      lng: lng,
      tripId: tripId,
      liveLocationUrl: liveLocationUrl,
    );
    String? automaticSmsMessage;
    if (phones.isNotEmpty && AutomaticSmsService.enabled) {
      try {
        final status = await AutomaticSmsService.send(
          id: alertId,
          uid: userId,
          phones: phones,
          message: message,
        );
        automaticSmsMessage = '${status['message']}';
      } catch (_) {
        automaticSmsMessage =
            'Automatic SMS result unknown. Check your Messages app before sending again; delivery is not confirmed.';
      }
    }
    if (phones.isNotEmpty && automaticSmsMessage == null) {
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
      body:
          automaticSmsMessage ??
          (phones.isEmpty
              ? 'No usable guardian contacts. Nobody was contacted.'
              : smsOpened
              ? 'SMS composer opened. Tap Send in your messaging app.'
              : dialerOpened
              ? 'Phone dialer opened. Start the call to reach your guardian.'
              : 'Contact options could not open. Reach your guardian directly.'),
    );
    return AlertTriggerResult(
      alertId: alertId,
      contactCount: phones.length,
      smsOpened: smsOpened,
      dialerOpened: dialerOpened,
      automaticSmsMessage: automaticSmsMessage,
      liveLocationUrl: liveLocationUrl,
      manualSmsUri: phones.isEmpty
          ? null
          : Uri.parse(
              'sms:${phones.join(',')}?body=${Uri.encodeComponent(message)}',
            ),
      whatsAppLinks: List.unmodifiable([
        for (final phone in phones)
          if (whatsAppUri(phone, message) case final Uri uri)
            GuardianWhatsAppLink(
              contacts.firstWhere((c) => _phone(c) == phone).name,
              uri,
            ),
      ]),
    );
  }

  Future<T> _databaseStep<T>(
    String operation,
    Future<T> Function() action,
  ) async {
    try {
      return await action();
    } on FirebaseException catch (e) {
      throw AlertOperationException(operation, e.code);
    } on TimeoutException {
      throw AlertOperationException(operation, 'timeout');
    }
  }

  void _checkUser(String uid) {
    if (uid.isEmpty || _currentUserId() != uid) {
      throw FirebaseAuthException(code: 'user-token-expired');
    }
  }

  static String _phone(ContactModel contact) {
    final phone = ContactsService.normalizePhone(contact.phone);
    return RegExp(r'^\+?[0-9]{7,15}$').hasMatch(phone) ? phone : '';
  }

  /// WhatsApp takes one international number, not an SMS recipient list.
  static Uri? whatsAppUri(String rawPhone, String message) {
    final phone = ContactsService.normalizePhone(rawPhone);
    if (!RegExp(r'^\+[1-9][0-9]{6,14}$').hasMatch(phone)) return null;
    return Uri.parse(
      'https://wa.me/${phone.substring(1)}?text=${Uri.encodeComponent(message)}',
    );
  }

  String buildMessage({
    UserModel? user,
    required String type,
    required double lat,
    required double lng,
    String? tripId,
    String? liveLocationUrl,
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
    if (liveLocationUrl != null) {
      buffer.writeln(
        'Live location (private link, up to 1 hour): $liveLocationUrl',
      );
      buffer.writeln(
        'Do not forward this link. Check the location update time.',
      );
    }
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
