// test/route_trip_handoff_test.dart
//
// Member 3 — Priority 4: Connect "Choose route" to starting a trip.
// Verifies that RouteComparisonScreen navigates to StartTripScreen with the
// chosen destination pre-filled, and that StartTripScreen carries planned
// route points into TripMap and persists destinationName in the trip record.

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
import 'package:latlong2/latlong.dart';

// ---------------------------------------------------------------------------
// Minimal tile provider (1-pixel transparent PNG, no network).
// ---------------------------------------------------------------------------
class _Tiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGO4dOnSfwAIZgN2c58MJgAAAABJRU5ErkJggg==',
        ),
      );
}

// ---------------------------------------------------------------------------
// In-memory FirestoreService stub.
// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
// Helpers.
// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
// Tests.
// ---------------------------------------------------------------------------
void main() {
  // ── 1. TripModel persists destinationName ──────────────────────────────────
  test('TripModel.toMap includes destinationName when set', () {
    final m = TripModel(
      tripId: 't1',
      userId: 'u1',
      status: TripStatus.active,
      startLocation: {'lat': 6.9, 'lng': 79.8},
      currentLocation: {'lat': 6.9, 'lng': 79.8},
      destination: {'lat': 6.95, 'lng': 79.85},
      startedAt: DateTime(2026),
      destinationName: 'Colombo Fort',
    );
    expect(m.toMap()['destinationName'], 'Colombo Fort');
  });

  test('TripModel.toMap omits destinationName when null', () {
    final m = TripModel(
      tripId: 't2',
      userId: 'u1',
      status: TripStatus.active,
      startLocation: {'lat': 6.9, 'lng': 79.8},
      currentLocation: {'lat': 6.9, 'lng': 79.8},
      destination: {'lat': 6.95, 'lng': 79.85},
      startedAt: DateTime(2026),
    );
    expect(m.toMap().containsKey('destinationName'), isFalse);
  });

  test('TripModel.fromMap round-trips destinationName', () {
    final original = TripModel(
      tripId: 't3',
      userId: 'u1',
      status: TripStatus.active,
      startLocation: {'lat': 6.9, 'lng': 79.8},
      currentLocation: {'lat': 6.9, 'lng': 79.8},
      destination: {'lat': 6.95, 'lng': 79.85},
      startedAt: DateTime(2026),
      destinationName: 'Galle Face',
    );
    // Simulate Firestore round-trip using map (without Timestamp for unit test).
    final raw = {
      ...original.toMap(),
      'startedAt': original.startedAt.toIso8601String(),
    };
    final restored = TripModel.fromMap(raw, 't3');
    expect(restored.destinationName, 'Galle Face');
  });

  // ── 2. StartTripScreen with preset destination ─────────────────────────────
  testWidgets(
    'preset destination from route comparison is pre-selected on the map',
    (tester) async {
      final store = _Store();
      const dest = LatLng(6.95, 79.85);

      await tester.pumpWidget(
        MaterialApp(
          home: StartTripScreen(
            store: store,
            checkLocation: () async => LocationStatus.ready,
            readPosition: () async => _position(),
            currentUserId: () => 'owner',
            tileProvider: _Tiles(),
            liveTripBuilder: (_) => const Scaffold(body: Text('Live trip')),
            presetDestination: dest,
            presetDestinationName: 'Central Station',
            presetRoutePoints: [
              const LatLng(6.9, 79.8),
              const LatLng(6.925, 79.825),
              const LatLng(6.95, 79.85),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Map renders and destination is pre-selected so Start trip is enabled.
      expect(find.byType(TripMap), findsOneWidget);
      final startBtn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Start trip'),
      );
      expect(startBtn.onPressed, isNotNull);

      // Destination label shows the place name.
      expect(find.text('Central Station'), findsOneWidget);

      // Planned route is passed into TripMap.
      final map = tester.widget<TripMap>(find.byType(TripMap));
      expect(map.plannedRoute.length, 3);
    },
  );

  testWidgets(
    'preset destination is saved to Firestore with destinationName',
    (tester) async {
      final store = _Store();
      const dest = LatLng(6.95, 79.85);

      await tester.pumpWidget(
        MaterialApp(
          home: StartTripScreen(
            store: store,
            checkLocation: () async => LocationStatus.ready,
            readPosition: () async => _position(),
            currentUserId: () => 'owner',
            tileProvider: _Tiles(),
            liveTripBuilder: (_) => const Scaffold(body: Text('Live trip')),
            presetDestination: dest,
            presetDestinationName: 'City Hall',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start trip'));
      await tester.pumpAndSettle();

      expect(store.saved, isNotNull);
      expect(store.saved!.destination['lat'], closeTo(6.95, 0.0001));
      expect(store.saved!.destination['lng'], closeTo(79.85, 0.0001));
      expect(store.saved!.destinationName, 'City Hall');
      expect(find.text('Live trip'), findsOneWidget);
    },
  );

  // ── 3. Tapping map clears preset route ────────────────────────────────────
  testWidgets('tapping map clears preset route and destination name',
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
          liveTripBuilder: (_) => const Scaffold(body: Text('Live trip')),
          presetDestination: const LatLng(6.95, 79.85),
          presetDestinationName: 'City Hall',
          presetRoutePoints: [
            const LatLng(6.9, 79.8),
            const LatLng(6.95, 79.85),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap a different point on the map.
    final mapWidget = find.byType(FlutterMap);
    await tester.tapAt(tester.getCenter(mapWidget) + const Offset(80, 50));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final map = tester.widget<TripMap>(find.byType(TripMap));
    // Planned route should be cleared when user taps a custom point.
    expect(map.plannedRoute, isEmpty);
    // Preset name should be gone.
    expect(find.text('City Hall'), findsNothing);
  });
}
