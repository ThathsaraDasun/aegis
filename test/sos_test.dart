import 'dart:async';
import 'package:aegis/models/alert_model.dart';
import 'package:aegis/models/contact_model.dart';
import 'package:aegis/models/user_model.dart';
import 'package:aegis/screens/safety/safety_shell.dart';
import 'package:aegis/services/alert_service.dart';
import 'package:aegis/services/firestore_service.dart';
import 'package:aegis/services/safety/fall_detector.dart';
import 'package:aegis/services/safety/motion_feed.dart';
import 'package:aegis/services/safety/safety_controller.dart';
import 'package:aegis/services/safety/sos_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeMotion implements MotionFeed {
  final source = StreamController<MotionSample>.broadcast();
  @override
  Stream<MotionSample> samples() => source.stream;
}

class FakeGateway implements SosGateway {
  final ids = <String>[];
  final types = <String>[];
  int resolutions = 0;
  bool fail = false;
  Completer<AlertTriggerResult>? pending;
  @override
  Future<AlertTriggerResult> trigger(String type, String requestId) async {
    ids.add(requestId);
    types.add(type);
    if (fail) throw const SafetyException('Network unavailable');
    if (pending != null) return pending!.future;
    return AlertTriggerResult(
      alertId: requestId,
      contactCount: 1,
      smsOpened: true,
      dialerOpened: false,
    );
  }

  @override
  Future<void> resolve(String id) async {
    resolutions++;
  }
}

class FakeStore implements FirestoreService {
  final alerts = <String, AlertModel>{};
  bool failWrite = false;
  List<ContactModel> contacts = [];
  @override
  Future<UserModel?> getUserProfile(String uid) async =>
      UserModel(userId: uid, name: 'Test Walker', phone: '');
  @override
  Future<List<ContactModel>> getContacts(String uid) async => contacts;
  @override
  Future<String> createAlert(AlertModel alert) async {
    if (failWrite) throw StateError('permission denied');
    alerts[alert.alertId] = alert;
    return alert.alertId;
  }

  @override
  Future<void> markTripAlerted(String tripId) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MotionSample sample(MotionKind kind, double magnitude, int ms) => MotionSample(
  kind,
  magnitude,
  0,
  0,
  DateTime(2026).add(Duration(milliseconds: ms)),
);

void main() {
  group('Fall detector', () {
    test('ordinary gravity and walking motion do not trigger', () {
      final d = FallDetector();
      for (var ms = 0; ms < 10000; ms += 100) {
        d.add(sample(MotionKind.rotation, 0.3, ms));
        expect(
          d.add(sample(MotionKind.acceleration, ms % 200 == 0 ? 9.8 : 13, ms)),
          false,
        );
      }
    });
    test('normal impact needs rotation and sustained stillness', () {
      final d = FallDetector();
      d.add(sample(MotionKind.rotation, 3, 0));
      expect(d.add(sample(MotionKind.acceleration, 30, 0)), false);
      for (var ms = 100; ms < 1100; ms += 100) {
        d.add(sample(MotionKind.rotation, 0.1, ms));
        expect(d.add(sample(MotionKind.acceleration, 9.8, ms)), false);
      }
      d.add(sample(MotionKind.rotation, 0.1, 1100));
      expect(d.add(sample(MotionKind.acceleration, 9.8, 1100)), true);
      d.demo = true;
      d.add(sample(MotionKind.rotation, 2, 1200));
      expect(d.add(sample(MotionKind.acceleration, 16, 1200)), false);
    });
    test('stale gyro and impact without rotation do not trigger', () {
      final d = FallDetector()..demo = true;
      d.add(sample(MotionKind.rotation, 3, 0));
      expect(d.add(sample(MotionKind.acceleration, 30, 1000)), false);
      d.add(sample(MotionKind.rotation, 0.1, 1100));
      expect(d.add(sample(MotionKind.acceleration, 30, 1100)), false);
    });
    test('continued movement expires a candidate; demo lowers thresholds', () {
      final d = FallDetector();
      d.add(sample(MotionKind.rotation, 3, 0));
      d.add(sample(MotionKind.acceleration, 30, 0));
      for (var ms = 100; ms <= 5000; ms += 100) {
        d.add(sample(MotionKind.rotation, 1, ms));
        expect(d.add(sample(MotionKind.acceleration, 15, ms)), false);
      }
      d.demo = true;
      d.add(sample(MotionKind.rotation, 0.8, 5100));
      expect(d.add(sample(MotionKind.acceleration, 14, 5100)), true);
    });
    test('reset drops an impact candidate', () {
      final d = FallDetector();
      d.add(sample(MotionKind.rotation, 3, 0));
      d.add(sample(MotionKind.acceleration, 30, 0));
      d.reset();
      for (var ms = 100; ms < 2000; ms += 100) {
        d.add(sample(MotionKind.rotation, 0.1, ms));
        expect(d.add(sample(MotionKind.acceleration, 9.8, ms)), false);
      }
    });
  });

  group('Safety state machine', () {
    late FakeMotion motion;
    late FakeGateway gateway;
    late SafetyController c;
    setUp(() {
      motion = FakeMotion();
      gateway = FakeGateway();
      c = SafetyController(
        motion: motion,
        gateway: gateway,
        countdownSeconds: 3,
      );
    });
    tearDown(() async {
      c.dispose();
      await motion.source.close();
    });

    testWidgets('cancel prevents escalation after timer expires', (
      tester,
    ) async {
      c.setMonitoring(true);
      c.startCountdown();
      await tester.pump(const Duration(seconds: 1));
      c.cancelCountdown();
      await tester.pump(const Duration(seconds: 5));
      expect(c.phase, SafetyPhase.idle);
      expect(gateway.ids, isEmpty);
    });
    testWidgets('timeout escalates once; repeated triggers are ignored', (
      tester,
    ) async {
      c.setMonitoring(true);
      c.startCountdown();
      c.startCountdown();
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(gateway.types, [AlertType.fallDetected]);
      expect(c.phase, SafetyPhase.finished);
      await c.escalate();
      await c.manualSos();
      expect(gateway.ids.length, 1);
    });
    testWidgets('demo timeout never calls backend', (tester) async {
      c.setDemo(true);
      c.setMonitoring(true);
      c.startCountdown();
      await tester.pump(const Duration(seconds: 3));
      expect(c.phase, SafetyPhase.finished);
      expect(c.eventIsDemo, true);
      expect(gateway.ids, isEmpty);
    });
    testWidgets('lifecycle pause cancels countdown and stops monitoring', (
      tester,
    ) async {
      c.setMonitoring(true);
      c.startCountdown();
      c.setForeground(false);
      await tester.pump(const Duration(seconds: 5));
      expect(gateway.ids, isEmpty);
      expect(c.monitoring, false);
      c.setForeground(true);
      expect(c.monitoring, false);
    });
    testWidgets('sensor errors stop monitoring without dispatch', (
      tester,
    ) async {
      c.setMonitoring(true);
      motion.source.addError(StateError('sensor unavailable'));
      await tester.pump();
      expect(c.monitoring, false);
      expect(c.notice, contains('unavailable'));
      expect(gateway.ids, isEmpty);
    });
    testWidgets('manual SOS stays real in demo mode and guards double taps', (
      tester,
    ) async {
      c.setDemo(true);
      gateway.pending = Completer<AlertTriggerResult>();
      final work = c.manualSos();
      await c.manualSos();
      expect(gateway.ids.length, 1);
      expect(c.eventIsDemo, false);
      gateway.pending!.complete(
        AlertTriggerResult(
          alertId: gateway.ids.first,
          contactCount: 1,
          smsOpened: true,
          dialerOpened: false,
        ),
      );
      await work;
      expect(gateway.types.single, AlertType.manualSos);
    });
    testWidgets('retry reuses ID and resolution is explicit', (tester) async {
      gateway.fail = true;
      await c.manualSos();
      expect(c.phase, SafetyPhase.failed);
      gateway.fail = false;
      await c.retry();
      expect(gateway.ids[0], gateway.ids[1]);
      await c.resolve();
      await c.resolve();
      expect(gateway.resolutions, 1);
      expect(c.resolved, true);
    });
    testWidgets('sensor demo drives countdown without external effects', (
      tester,
    ) async {
      c.setDemo(true);
      c.setMonitoring(true);
      motion.source.add(sample(MotionKind.rotation, 1, 0));
      motion.source.add(sample(MotionKind.acceleration, 14, 0));
      await tester.pump();
      expect(c.phase, SafetyPhase.countdown);
      await tester.pump(const Duration(seconds: 3));
      expect(c.phase, SafetyPhase.finished);
      expect(gateway.ids, isEmpty);
    });
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

  testWidgets(
    'countdown covers pushed pages and cancel returns without alert',
    (tester) async {
      final motion = FakeMotion();
      final gateway = FakeGateway();
      final c = SafetyController(
        motion: motion,
        gateway: gateway,
        countdownSeconds: 3,
      );
      addTearDown(() async {
        c.dispose();
        await motion.source.close();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: SafetyShell(
            controller: c,
            showFloatingSos: true,
            homeBuilder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const Scaffold(body: Text('Secondary screen')),
                  ),
                ),
                child: const Text('Open screen'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open screen'));
      await tester.pumpAndSettle();
      expect(find.text('SOS'), findsOneWidget);
      c.startCountdown(simulation: true);
      await tester.pump();
      expect(find.text('Demo: Are you OK?'), findsOneWidget);
      await tester.tap(find.text('I am OK - cancel'));
      await tester.pumpAndSettle();
      expect(gateway.ids, isEmpty);
      expect(find.text('Secondary screen'), findsOneWidget);
    },
  );
}
