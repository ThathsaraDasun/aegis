import 'package:aegis/models/alert_model.dart';
import 'package:aegis/models/trip_model.dart';
import 'package:aegis/screens/activity/trip_detail_screen.dart';
import 'package:aegis/services/activity_service.dart';
import 'package:aegis/services/compass_service.dart';
import 'package:aegis/widgets/contact_card.dart';
import 'package:aegis/widgets/trip_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TripModel _trip({String status = 'completed', DateTime? start, DateTime? end}) {
  final s = start ?? DateTime(2026, 11, 1, 9);
  return TripModel(
    tripId: 't1',
    userId: 'u1',
    status: status,
    startLocation: const {'lat': 6.9271, 'lng': 79.8612},
    currentLocation: const {'lat': 6.9280, 'lng': 79.8620},
    destination: const {'lat': 6.9310, 'lng': 79.8650},
    startedAt: s,
    endedAt: end,
  );
}

void main() {
  group('CompassService.headingFromMagnetometer', () {
    // Field along +y = phone top facing north.
    test('facing north is 0', () {
      expect(CompassService.headingFromMagnetometer(0, 30), closeTo(0, 1e-9));
    });
    // North is to the left of the phone (field along -x) = facing east.
    test('facing east is 90', () {
      expect(CompassService.headingFromMagnetometer(-30, 0), closeTo(90, 1e-9));
    });
    test('facing south is 180', () {
      expect(
        CompassService.headingFromMagnetometer(0, -30),
        closeTo(180, 1e-9),
      );
    });
    test('facing west is 270', () {
      expect(CompassService.headingFromMagnetometer(30, 0), closeTo(270, 1e-9));
    });
  });

  group('CompassService angle helpers', () {
    test('shortest delta wraps across north', () {
      expect(CompassService.shortestAngleDelta(350, 10), closeTo(20, 1e-9));
      expect(CompassService.shortestAngleDelta(10, 350), closeTo(-20, 1e-9));
    });
    test('smoothing moves through 0 not the long way round', () {
      final v = CompassService.smoothHeading(350, 10, 0.5);
      expect(v, closeTo(0, 1e-9));
    });
    test('bearing due east is about 90', () {
      final b = CompassService.calculateBearing(
        startLat: 0,
        startLng: 0,
        endLat: 0,
        endLng: 1,
      );
      expect(b, closeTo(90, 1e-6));
    });
    test('arrow rotation is bearing minus heading', () {
      expect(
        CompassService.calculateArrowRotation(
          deviceHeading: 90,
          destinationBearing: 45,
        ),
        closeTo(315, 1e-9),
      );
    });
  });

  group('Model parsing helpers', () {
    test('parseLatLng accepts ints and GeoPoints', () {
      expect(parseLatLng({'lat': 7, 'lng': 80.5}), {'lat': 7.0, 'lng': 80.5});
      expect(parseLatLng(const GeoPoint(6.9, 79.8)), {'lat': 6.9, 'lng': 79.8});
      expect(parseLatLng(null), isEmpty);
    });
    test('parseDate accepts Timestamp, ISO string and null', () {
      final d = DateTime(2026, 1, 2, 3, 4);
      expect(parseDate(Timestamp.fromDate(d)), d);
      expect(parseDate(d.toIso8601String()), d);
      expect(parseDate(null), isNull);
    });
  });

  group('Alert outcome', () {
    AlertModel alert(bool resolved) => AlertModel(
      alertId: 'a',
      tripId: 't',
      userId: 'u',
      type: 'fall_detected',
      location: const {},
      triggeredAt: DateTime(2026),
      resolved: resolved,
    );
    test('resolved vs unresolved', () {
      expect(alert(true).outcome, 'resolved');
      expect(alert(false).outcome, 'unresolved');
      expect(alert(false).typeLabel, 'Fall Detected');
    });
  });

  group('ActivityItem ordering', () {
    test('uses trip start or alert trigger time', () {
      final trip = _trip(start: DateTime(2026, 1, 1));
      final alert = AlertModel(
        alertId: 'a',
        tripId: 't',
        userId: 'u',
        type: 'manual_sos',
        location: const {},
        triggeredAt: DateTime(2026, 1, 2),
      );
      final items = [ActivityItem.trip(trip), ActivityItem.alert(alert)]
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      expect(items.first.alert, isNotNull);
    });
  });

  group('TripCard helpers', () {
    test('duration label', () {
      final start = DateTime(2026, 1, 1, 9);
      expect(
        TripCard.durationLabel(
          _trip(start: start, end: start.add(const Duration(minutes: 45))),
        ),
        '45m',
      );
      expect(
        TripCard.durationLabel(
          _trip(start: start, end: start.add(const Duration(minutes: 80))),
        ),
        '1h 20m',
      );
      expect(TripCard.durationLabel(_trip()), isNull);
    });
    test('initials', () {
      expect(ContactCard.initialsFor('Jane  Doe'), 'JD');
      expect(ContactCard.initialsFor('  '), '?');
    });
  });

  testWidgets('RouteSketchPainter paints a trip without errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 300,
          height: 200,
          child: CustomPaint(painter: RouteSketchPainter(_trip())),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
