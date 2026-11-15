import 'dart:convert';
import 'package:aegis/models/trip_model.dart';
import 'package:aegis/screens/trip/start_trip_screen.dart';
import 'package:aegis/screens/trip/trip_map.dart';
import 'package:aegis/services/firestore_service.dart';
import 'package:aegis/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

class _Tiles extends TileProvider {
  @override
  ImageProvider getImage(
    TileCoordinates coordinates,
    TileLayer options,
  ) => MemoryImage(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGO4dOnSfwAIZgN2c58MJgAAAABJRU5ErkJggg==',
    ),
  );
}

class _Store implements FirestoreService {
  TripModel? saved;
  @override
  Future<String> createTrip(TripModel trip) async {
    saved = trip;
    return trip.tripId;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Position _position() => Position(
  latitude: 6.9,
  longitude: 79.8,
  timestamp: DateTime.now(),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 1,
  heading: 0,
  headingAccuracy: 1,
  speed: 0,
  speedAccuracy: 1,
);

void main() {
  test('map coordinates reject missing and invalid values', () {
    expect(tripCoordinate({}), isNull);
    expect(tripCoordinate({'lat': double.nan, 'lng': 79}), isNull);
    expect(tripCoordinate({'lat': 91, 'lng': 79}), isNull);
    expect(tripCoordinate({'lat': 6.9, 'lng': 79.8})!.latitude, 6.9);
  });
  testWidgets(
    'trip requires a selected pin and saves the selected coordinates',
    (tester) async {
      final store = _Store();
      await tester.pumpWidget(
        MaterialApp(
          home: StartTripScreen(
            store: store,
            checkLocation: () async => LocationStatus.ready,
            readPosition: () async => _position(),
            currentUserId: () => 'owner',
            tileProvider: _Tiles(),
            liveTripBuilder: (_) =>
                const Scaffold(body: Text('Live test trip')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Start trip'),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget);
      final map = find.byType(FlutterMap);
      await tester.tapAt(tester.getCenter(map) + const Offset(60, 30));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      final selected = tester
          .widget<TripMap>(find.byType(TripMap))
          .destination!;
      await tester.tap(find.text('Start trip'));
      await tester.pumpAndSettle();
      expect(store.saved!.destination, {
        'lat': selected.latitude,
        'lng': selected.longitude,
      });
      expect(store.saved!.startLocation, {'lat': 6.9, 'lng': 79.8});
      expect(store.saved!.userId, 'owner');
      expect(find.text('Live test trip'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('denied permission does not open a map or create a trip', (
    tester,
  ) async {
    final store = _Store();
    await tester.pumpWidget(
      MaterialApp(
        home: StartTripScreen(
          store: store,
          checkLocation: () async => LocationStatus.permissionDenied,
          readPosition: () async => throw StateError('GPS must not be called'),
          tileProvider: _Tiles(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TripMap), findsNothing);
    expect(store.saved, isNull);
    expect(tester.takeException(), isNull);
  });
}
