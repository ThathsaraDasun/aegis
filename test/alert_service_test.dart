import 'package:firebase_core/firebase_core.dart';
import 'package:aegis/models/alert_model.dart';
import 'package:aegis/models/contact_model.dart';
import 'package:aegis/models/user_model.dart';
import 'package:aegis/services/alert_service.dart';
import 'package:aegis/services/firestore_service.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeStore implements FirestoreService {
  final alerts = <String, AlertModel>{};
  bool failWrite = false;
  String? deniedStage;
  List<ContactModel> contacts = [];
  @override
  Future<UserModel?> getUserProfile(String uid) async {
    if (deniedStage == 'profile') {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
    }
    return UserModel(userId: uid, name: 'Test Walker', phone: '');
  }

  @override
  Future<List<ContactModel>> getContacts(String uid) async {
    if (deniedStage == 'contacts') {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
    }
    return contacts;
  }

  @override
  Future<String> createAlert(AlertModel alert) async {
    if (deniedStage == 'alert') {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
    }
    if (failWrite) throw StateError('permission denied');
    alerts[alert.alertId] = alert;
    return alert.alertId;
  }

  @override
  Future<void> markTripAlerted(String tripId) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('WhatsApp uses international digits and preserves the complete message', () {
    const message = 'SOS & help\nLocation: https://maps.google.com/?q=6.9,79.8';
    for (final number in ['0771234567', '+94 (77) 123-4567', '0094771234567']) {
      final uri = AlertService.whatsAppUri(number, message)!;
      expect(uri.host, 'wa.me');
      expect(uri.path, '/94771234567');
      expect(uri.queryParameters['text'], message);
    }
    expect(AlertService.whatsAppUri('+94771234567,+94777654321', message), isNull);
    expect(AlertService.whatsAppUri('1234567', message), isNull);
  });
  group('Backend handoff', () {
    late FakeStore store;
    late List<Uri> launches;
    late List<String> notices;
    late AlertService service;
    setUp(() {
      store = FakeStore();
      launches = [];
      notices = [];
      service = AlertService(
        firestoreService: store,
        currentUserId: () => 'u1',
        launchExternal: (uri) async {
          launches.add(uri);
          return true;
        },
        showNotification: (title, body) async {
          notices.add('$title $body');
        },
      );
    });
    Future<AlertTriggerResult> trigger() => service.triggerAlert(
      userId: 'u1',
      type: AlertType.manualSos,
      lat: 6.9,
      lng: 79.8,
      requestId: 'event-1',
    );
    test('WhatsApp offers separate real guardians without automatically opening chats', () async {
      store.contacts = [
        ContactModel(id: 'one', name: 'One', phone: '0771234567', relation: ''),
        ContactModel(id: 'two', name: 'Two', phone: '+94777654321', relation: ''),
        ContactModel(id: 'duplicate', name: 'Duplicate', phone: '+94771234567', relation: ''),
        ContactModel(id: 'demo_fake', name: 'Demo', phone: '+94770000000', relation: ''),
      ];
      final result = await trigger();
      expect(result.whatsAppLinks.map((link) => link.name), ['One', 'Two']);
      expect(result.whatsAppLinks.map((link) => link.uri.path), ['/94771234567', '/94777654321']);
      expect(result.whatsAppLinks.first.uri.queryParameters['text'], contains('Manual SOS activated'));
      expect(launches.single.scheme, 'sms');
      expect(store.alerts.length, 1);
    });
    for (final entry in {
      'profile': 'reading your profile',
      'contacts': 'reading your guardian contacts',
      'alert': 'saving your SOS alert',
    }.entries) {
      test(
        'permission failure identifies ${entry.key} and never launches contact apps',
        () async {
          store.deniedStage = entry.key;
          await expectLater(
            trigger(),
            throwsA(
              isA<AlertOperationException>()
                  .having((e) => e.operation, 'operation', entry.value)
                  .having((e) => e.code, 'code', 'permission-denied'),
            ),
          );
          expect(launches, isEmpty);
        },
      );
    }
    test('composer opening is not described as sent; ID is stable', () async {
      store.contacts = [
        ContactModel(
          id: 'real',
          name: 'Guardian',
          phone: '+94771234567',
          relation: 'Family',
        ),
      ];
      final result = await trigger();
      await trigger();
      expect(result.smsOpened, true);
      expect(store.alerts.length, 1);
      expect(launches.first.scheme, 'sms');
      expect(notices.first, contains('Tap Send'));
      expect(notices.first, isNot(contains('Alert sent')));
      expect(
        Uri.decodeComponent(launches.first.toString()),
        isNot(contains('safewalk.app')),
      );
    });
    test('no contacts and seeded demo numbers are never launched', () async {
      store.contacts = [
        ContactModel(
          id: 'demo_contact_1',
          name: 'Fake',
          phone: '+94771234567',
          relation: '',
        ),
      ];
      final result = await trigger();
      expect(result.contactCount, 0);
      expect(launches, isEmpty);
      expect(store.alerts.length, 1);
    });
    test('failed write never opens external apps', () async {
      store.failWrite = true;
      await expectLater(trigger(), throwsStateError);
      expect(launches, isEmpty);
    });
    test(
      'SMS failure tries dialer and notification failure is nonfatal',
      () async {
        store.contacts = [
          ContactModel(
            id: 'real',
            name: 'Guardian',
            phone: '+94771234567',
            relation: '',
          ),
        ];
        service = AlertService(
          firestoreService: store,
          currentUserId: () => 'u1',
          launchExternal: (uri) async {
            launches.add(uri);
            return uri.scheme == 'tel';
          },
          showNotification: (_, _) async => throw StateError('denied'),
        );
        final result = await trigger();
        expect(result.smsOpened, false);
        expect(result.dialerOpened, true);
        expect(launches.map((u) => u.scheme), ['sms', 'tel']);
      },
    );
    test('invalid coordinates and other-user requests are rejected', () async {
      await expectLater(
        service.triggerAlert(
          userId: 'u1',
          type: AlertType.manualSos,
          lat: double.nan,
          lng: 0,
        ),
        throwsArgumentError,
      );
      await expectLater(
        service.triggerAlert(
          userId: 'other',
          type: AlertType.manualSos,
          lat: 6.9,
          lng: 79.8,
        ),
        throwsA(isA<Exception>()),
      );
      expect(store.alerts, isEmpty);
      expect(launches, isEmpty);
    });
  });
}
