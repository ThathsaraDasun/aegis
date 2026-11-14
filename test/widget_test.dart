import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aegis/screens/auth/login_screen.dart';
import 'auth_test.dart' show FakeAuthService;
import 'package:aegis/services/trip_service/trip_service_interface.dart';

void main() {
  testWidgets('LoginScreen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(service: FakeAuthService())),
    );

    expect(find.text('AEGIS SAFE WALK'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
  });

  test('MockTripService startTrip test', () async {
    final service = MockTripService();
    final tripId = await service.startTrip(
      userId: 'user123',
      startLocation: const {'lat': 37.77, 'lng': -122.42},
      destination: const {'lat': 37.7749, 'lng': -122.4194},
      contactIds: ['contact1'],
      routeChosen: 'Main St',
    );

    expect(tripId, equals('mock_trip_id_123'));
  });
}
