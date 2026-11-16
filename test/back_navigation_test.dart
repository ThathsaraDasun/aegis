import 'dart:async';

import 'package:aegis/screens/safety/safety_shell.dart';
import 'package:aegis/services/alert_service.dart';
import 'package:aegis/services/safety/fall_detector.dart';
import 'package:aegis/services/safety/motion_feed.dart';
import 'package:aegis/services/safety/safety_controller.dart';
import 'package:aegis/services/safety/sos_gateway.dart';
import 'package:aegis/widgets/nested_back_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Motion implements MotionFeed {
  final source = StreamController<MotionSample>.broadcast();
  @override
  Stream<MotionSample> samples() => source.stream;
}

class _Gateway implements SosGateway {
  final ids = <String>[];
  @override
  Future<AlertTriggerResult> trigger(String type, String requestId) async {
    ids.add(requestId);
    return AlertTriggerResult(
      alertId: requestId,
      contactCount: 1,
      smsOpened: true,
      dialerOpened: false,
    );
  }

  @override
  Future<void> resolve(String id) async {}
}

void main() {
  late int exits;
  setUp(() {
    exits = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.pop') exits++;
      return null;
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  /// Android back button.
  Future<void> pressBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  Widget home(BuildContext context) => Scaffold(
    body: TextButton(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('Trip history')),
        ),
      ),
      child: const Text('Open page'),
    ),
  );

  /// Same layout as the app: a signed-in navigator (AuthGate) holding the
  /// SafetyShell, which holds its own navigator for the app's pages.
  Future<SafetyController> pumpApp(WidgetTester tester) async {
    final motion = _Motion();
    final controller = SafetyController(
      motion: motion,
      gateway: _Gateway(),
      countdownSeconds: 3,
    );
    addTearDown(() async {
      controller.dispose();
      await motion.source.close();
    });
    final signedInKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        home: NestedBackScope(
          navigatorKey: signedInKey,
          child: Navigator(
            key: signedInKey,
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (_) =>
                  SafetyShell(controller: controller, homeBuilder: home),
            ),
          ),
        ),
      ),
    );
    return controller;
  }

  testWidgets('back closes an opened page instead of leaving the app', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Open page'));
    await tester.pumpAndSettle();
    expect(find.text('Trip history'), findsOneWidget);

    await pressBack(tester);
    expect(find.text('Trip history'), findsNothing);
    expect(find.text('Open page'), findsOneWidget);
    expect(exits, 0);
  });

  testWidgets('back on the home screen leaves the app', (tester) async {
    await pumpApp(tester);
    await pressBack(tester);
    expect(exits, 1);
  });

  testWidgets('back during the fall countdown cancels it and stays', (
    tester,
  ) async {
    final controller = await pumpApp(tester);
    controller.startCountdown(simulation: true);
    await tester.pump();
    expect(controller.phase, SafetyPhase.countdown);

    await pressBack(tester);
    expect(controller.phase, SafetyPhase.idle);
    expect(exits, 0);
  });

  testWidgets('a page that blocks back keeps its own handling', (
    tester,
  ) async {
    var blocked = 0;
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        home: NestedBackScope(
          navigatorKey: key,
          child: Navigator(
            key: key,
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (_) => PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, _) => blocked++,
                child: const Text('Other tab'),
              ),
            ),
          ),
        ),
      ),
    );
    await pressBack(tester);
    expect(blocked, 1);
    expect(exits, 0);
  });
}
