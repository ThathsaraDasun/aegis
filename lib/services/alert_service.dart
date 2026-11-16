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

/// Guardian message prepared when a trip starts.
///
/// Nothing is sent unless the user opted in to automatic SMS
/// ([automaticSmsMessage] is then set). Otherwise the UI offers [smsUri] and
/// [whatsAppLinks], and the user decides whether to send.
class TripStartShare {
  final String message;
  final int contactCount;
  final Uri? smsUri;
  final List<GuardianWhatsAppLink> whatsAppLinks;
  final String? automaticSmsMessage;
  const TripStartShare({
    required this.message,
    required this.contactCount,
    this.smsUri,
    this.whatsAppLinks = const [],
    this.automaticSmsMessage,
  });

  bool get sentAutomatically => automaticSmsMessage != null;
}

typedef AutomaticSmsSender =
    Future<Map<dynamic, dynamic>> Function({
      required String id,
      required String uid,
      required List<String> phones,
      required String message,
    });

/// Member 4's public API, hardened for Member 1's foreground SOS integration.
/// An opened composer/dialer is never treated as confirmed remote delivery.
class AlertService {
  final FirestoreService _firestoreService;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final Future<bool> Function(Uri) _launch;
  final String? Function() _currentUserId;
  final Future<void> Function(String, String)? _notificationOverride;

  /// Sends trip start/end messages automatically from the SIM.
  final AutomaticSmsSender _sendTripSms;
  static final AlertService instance = AlertService();

  AlertService({
    FirestoreService? firestoreService,
    FlutterLocalNotificationsPlugin? localNotifications,
    Future<bool> Function(Uri)? launchExternal,
    String? Function()? currentUserId,
    Future<void> Function(String, String)? showNotification,
    AutomaticSmsSender? sendTripSms,
  }) : _sendTripSms = sendTripSms ?? AutomaticSmsService.sendTripMessage,
       _firestoreService = firestoreService ?? FirestoreService.instance,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin(),
       _launch =
           launchExternal ??
           ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication)),
       _currentUserId =
           currentUserId ?? (() => FirebaseAuth.instance.currentUser?.uid),
       _notificationOverride = showNotification;

  /// Trip-start text with [liveLocationUrl] when an https live link is
  /// available, otherwise a Google Maps link to [lat],[lng].
  static String buildTripStartMessage({
    required double lat,
    required double lng,
    String? liveLocationUrl,
  }) {
    final live = Uri.tryParse(liveLocationUrl ?? '');
    final link = live != null && live.isScheme('https') && live.host.isNotEmpty
        ? liveLocationUrl!
        : 'https://maps.google.com/?q=$lat,$lng';
    return 'I started a Safe Walk. Follow my live location: $link';
  }

  /// Trip-end text for guardians. When the walker confirmed arrival it says
  /// so; when the trip ended without confirmation (timeout) it asks them to
  /// check on the walker and includes the last known location if available.
  static String buildTripEndMessage({
    required bool arrivedSafely,
    double? lat,
    double? lng,
  }) {
    if (arrivedSafely) {
      return 'I have arrived safely. My Safe Walk has ended and live location sharing has stopped.';
    }
    final valid =
        lat != null &&
        lng != null &&
        lat.isFinite &&
        lng.isFinite &&
        lat.abs() <= 90 &&
        lng.abs() <= 180;
    final where = valid
        ? ' Last known location: https://maps.google.com/?q=$lat,$lng'
        : '';
    return 'My Safe Walk ended without me confirming that I arrived safely. Please check on me.$where';
  }

  /// Prepares the trip-start message for the selected guardians
  /// ([contactIds] are trusted-contact IDs under `users/{uid}/contacts`).
  ///
  /// Sends automatically only when automatic SMS is enabled; otherwise it
  /// launches nothing and returns SMS/WhatsApp links for the user to tap.
  Future<TripStartShare> prepareTripStartShare({
    required String userId,
    required List<String> contactIds,
    required double lat,
    required double lng,
    required String tripId,
    String? liveLocationUrl,
  }) => _prepareGuardianShare(
    userId: userId,
    contactIds: contactIds,
    smsId: 'trip-start-$tripId',
    message: buildTripStartMessage(
      lat: lat,
      lng: lng,
      liveLocationUrl: liveLocationUrl,
    ),
  );

  /// Prepares the trip-end message for all saved guardians. Like the start
  /// message, it is sent automatically only when automatic SMS is enabled.
  Future<TripStartShare> prepareTripEndShare({
    required String userId,
    required String tripId,
    required bool arrivedSafely,
    double? lat,
    double? lng,
  }) => _prepareGuardianShare(
    userId: userId,
    contactIds: null,
    smsId: 'trip-end-$tripId',
    message: buildTripEndMessage(
      arrivedSafely: arrivedSafely,
      lat: lat,
      lng: lng,
    ),
  );

  /// Shared guardian-message logic for trip start and end. [contactIds] null
  /// means all saved guardians.
  Future<TripStartShare> _prepareGuardianShare({
    required String userId,
    required List<String>? contactIds,
    required String smsId,
    required String message,
  }) async {
    _checkUser(userId);
    final selected = contactIds?.toSet();
    final contacts =
        (await _databaseStep(
              'reading your guardian contacts',
              () => _firestoreService
                  .getContacts(userId)
                  .timeout(const Duration(seconds: 8)),
            ))
            .where(
              (c) =>
                  (selected == null || selected.contains(c.id)) &&
                  !c.id.startsWith('demo_') &&
                  _phone(c).isNotEmpty,
            )
            .toList();
    final phones = contacts.map(_phone).toSet().toList();
    // Trip start/end messages always go out automatically from the SIM
    // (independent of the SOS "Automatic guardian SMS" opt-in). If that is
    // not possible (no permission / no SIM / error), fall back to the manual
    // SMS and WhatsApp buttons.
    String? automaticSmsMessage;
    if (phones.isNotEmpty) {
      _checkUser(userId);
      try {
        final status = await _sendTripSms(
          id: smsId,
          uid: userId,
          phones: phones,
          message: message,
        );
        if (status['state'] != 'blocked') {
          automaticSmsMessage = '${status['message']}';
        }
      } catch (_) {
        // Not sent automatically: the user can still send it manually.
      }
    }
    return TripStartShare(
      message: message,
      contactCount: phones.length,
      automaticSmsMessage: automaticSmsMessage,
      smsUri: phones.isEmpty
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

  /// Opens the SMS composer for a prepared trip-start message when the user
  /// taps to notify guardians. Returns whether the composer opened.
  Future<bool> openTripStartSms(TripStartShare share) async {
    final uri = share.smsUri;
    if (uri == null) return false;
    try {
      return await _launch(uri);
    } catch (_) {
      return false;
    }
  }

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
