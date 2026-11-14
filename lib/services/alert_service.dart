import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/alert_model.dart';
import '../models/contact_model.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';

/// Result object returned by [AlertService.triggerAlert].
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

/// Service responsible for handling emergency SOS alerts and fall detection dispatches.
/// 
/// Integrates [FirestoreService] for database creation, [FlutterLocalNotificationsPlugin]
/// for local user notifications, and [url_launcher] for dispatching SMS alerts and dialer fallbacks.
class AlertService {
  final FirestoreService _firestoreService;
  final FlutterLocalNotificationsPlugin _localNotifications;

  /// Configurable static base URL for live trip tracking links.
  static String liveViewerBaseUrl = 'https://safewalk.app/trip/';

  /// Singleton instance of [AlertService].
  static final AlertService instance = AlertService();

  /// Creates an [AlertService] instance, optionally receiving custom dependency instances.
  AlertService({
    FirestoreService? firestoreService,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _firestoreService = firestoreService ?? FirestoreService.instance,
        _localNotifications = localNotifications ?? FlutterLocalNotificationsPlugin();

  /// Initializes local notifications and requests notification permissions (Android 13+).
  /// Must be called from `main()` after `Firebase.initializeApp()`.
  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(initSettings);

    // Request Android 13+ notification permissions
    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
  }

  /// Triggers an emergency alert (manual SOS or fall detected).
  /// 
  /// 1. Fetches user profile and emergency contacts via [FirestoreService].
  /// 2. Creates the alert document in Firestore.
  /// 3. Marks the trip as alerted if [tripId] is provided.
  /// 4. Shows a local notification summarizing the dispatch.
  /// 5. Opens SMS composer with location and medical details to all trusted contacts.
  /// 6. Falls back to calling the primary guardian via dialer if SMS fails.
  Future<AlertTriggerResult> triggerAlert({
    required String userId,
    required String type,
    required double lat,
    required double lng,
    String? tripId,
  }) async {
    // 1. Fetch User Profile and Emergency Contacts
    UserModel? user;
    List<ContactModel> contacts = [];
    try {
      user = await _firestoreService.getUserProfile(userId);
      contacts = await _firestoreService.getContacts(userId);
    } catch (e) {
      debugPrint('AlertService: Error fetching profile/contacts: $e');
    }

    // 2. Create Alert Document in Firestore
    final alert = AlertModel(
      alertId: '',
      tripId: tripId ?? '',
      userId: userId,
      type: type,
      location: {'lat': lat, 'lng': lng},
      triggeredAt: DateTime.now(),
      resolved: false,
    );
    final alertId = await _firestoreService.createAlert(alert);

    // 3. Mark active trip as alerted if tripId is provided
    if (tripId != null && tripId.isNotEmpty) {
      try {
        await _firestoreService.markTripAlerted(tripId);
      } catch (e) {
        debugPrint('AlertService: Error marking trip as alerted: $e');
      }
    }

    // 4. Trigger Local Push Notification
    final bool isFall = (type == AlertType.fallDetected);
    final String notifTitle = isFall ? 'Fall Alert Dispatched!' : 'SOS Emergency Alert Dispatched!';
    final String notifBody = contacts.isNotEmpty
        ? 'Alert sent to ${contacts.length} trusted guardian(s).'
        : 'Alert recorded! No emergency contacts saved in your profile.';
    
    await _showLocalNotification(title: notifTitle, body: notifBody);

    // 5. Compose Emergency SMS Message
    final message = buildMessage(
      user: user,
      type: type,
      lat: lat,
      lng: lng,
      tripId: tripId,
    );

    bool smsOpened = false;
    bool dialerOpened = false;

    // 6. Launch SMS Composer if contacts exist
    if (contacts.isNotEmpty) {
      final phoneNumbers = contacts.map((c) => c.phone).where((p) => p.isNotEmpty).join(',');
      if (phoneNumbers.isNotEmpty) {
        final smsUri = Uri.parse('sms:$phoneNumbers?body=${Uri.encodeComponent(message)}');
        try {
          smsOpened = await launchUrl(smsUri, mode: LaunchMode.externalApplication);
        } catch (e) {
          debugPrint('AlertService: Could not launch SMS composer: $e');
          smsOpened = false;
        }
      }

      // 7. Fallback to Dialer if SMS fails
      if (!smsOpened && contacts.first.phone.isNotEmpty) {
        final telUri = Uri.parse('tel:${contacts.first.phone}');
        try {
          dialerOpened = await launchUrl(telUri, mode: LaunchMode.externalApplication);
        } catch (e) {
          debugPrint('AlertService: Could not launch phone dialer fallback: $e');
          dialerOpened = false;
        }
      }
    }

    return AlertTriggerResult(
      alertId: alertId,
      contactCount: contacts.length,
      smsOpened: smsOpened,
      dialerOpened: dialerOpened,
    );
  }

  /// Builds a formatted emergency text message containing user identity, reason,
  /// Google Maps coordinates, live tracking link, and medical emergency details.
  String buildMessage({
    UserModel? user,
    required String type,
    required double lat,
    required double lng,
    String? tripId,
  }) {
    final name = (user != null && user.name.isNotEmpty) ? user.name : 'Aegis User';
    final reason = (type == AlertType.fallDetected)
        ? 'EMERGENCY: Fall detected and user is unresponsive!'
        : 'EMERGENCY: Panic SOS button pressed!';

    final buffer = StringBuffer();
    buffer.writeln('🚨 SAFE WALK ALERT 🚨');
    buffer.writeln('$reason');
    buffer.writeln('User: $name');
    buffer.writeln('Location: https://maps.google.com/?q=$lat,$lng');

    if (tripId != null && tripId.isNotEmpty) {
      buffer.writeln('Live Track: $liveViewerBaseUrl$tripId');
    }

    if (user != null) {
      final medInfo = <String>[];
      if (user.bloodType.isNotEmpty) medInfo.add('Blood: ${user.bloodType}');
      if (user.allergies.isNotEmpty) medInfo.add('Allergies: ${user.allergies}');
      if (user.emergencyNote.isNotEmpty) medInfo.add('Note: ${user.emergencyNote}');

      if (medInfo.isNotEmpty) {
        buffer.writeln('Medical Info: ${medInfo.join(' | ')}');
      }
    }

    return buffer.toString().trim();
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'aegis_sos_channel',
      'Emergency SOS Alerts',
      channelDescription: 'Notifications for emergency SOS alerts and fall detection',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(android: androidDetails);
    try {
      await _localNotifications.show(0, title, body, details);
    } catch (e) {
      debugPrint('AlertService: Error showing local notification: $e');
    }
  }
}
