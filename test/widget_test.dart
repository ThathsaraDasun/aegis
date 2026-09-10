import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aegis/main.dart';
import 'package:aegis/core/models/trip_model.dart';
import 'package:aegis/services/trip_service/trip_service_interface.dart';

void main() {
  testWidgets('LoginScreen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginScreen(),
      ),
    );

    expect(find.text('Safe Walk Login'), findsOneWidget);
    expect(find.text('Login Screen stub'), findsOneWidget);
  });

  test('MockTripService startTrip test', () async {
    final service = MockTripService();
    final tripId = await service.startTrip(
      ownerId: 'user123',
      destination: const Destination(lat: 37.7749, lng: -122.4194, label: 'Home'),
      contactIds: ['contact1'],
      routeChosen: 'Main St',
    );

    expect(tripId, equals('mock_trip_id_123'));
  });
}
