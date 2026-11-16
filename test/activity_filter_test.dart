import 'package:aegis/models/alert_model.dart';
import 'package:aegis/models/trip_model.dart';
import 'package:aegis/screens/activity/activity_feed_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 16, 18);

  AlertModel alert(String id, {required bool resolved}) => AlertModel(
    alertId: id,
    tripId: 'trip',
    userId: 'user',
    type: 'manual_sos',
    location: const {'lat': 6.9, 'lng': 79.8},
    triggeredAt: now,
    resolved: resolved,
  );

  TripModel trip(String id, String status) => TripModel(
    tripId: id,
    userId: 'user',
    status: status,
    startLocation: const {'lat': 6.9, 'lng': 79.8},
    currentLocation: const {'lat': 6.9, 'lng': 79.8},
    destination: const {'lat': 6.9, 'lng': 79.8},
    startedAt: now,
  );

  final openAlert = alert('a1', resolved: false);
  final resolvedAlert = alert('a2', resolved: true);
  final activeTrip = trip('t1', 'active');
  final doneTrip = trip('t2', 'completed');
  final alertedTrip = trip('t3', 'alerted');
  final items = <dynamic>[
    openAlert,
    activeTrip,
    resolvedAlert,
    doneTrip,
    alertedTrip,
  ];

  test('no filter shows all activity in the same order', () {
    expect(filterActivity(items, null), items);
  });

  test('Active shows only unresolved alerts and in-progress trips', () {
    expect(filterActivity(items, ActivityFilter.active), [
      openAlert,
      activeTrip,
    ]);
  });

  test('Alerts shows only alerts', () {
    expect(filterActivity(items, ActivityFilter.alerts), [
      openAlert,
      resolvedAlert,
    ]);
  });

  test('Trips shows only trips', () {
    expect(filterActivity(items, ActivityFilter.trips), [
      activeTrip,
      doneTrip,
      alertedTrip,
    ]);
  });
}
