import 'package:aegis/models/trip_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('location coordinates round-trip through the shared backend model', () {
    final when = DateTime(2026, 11, 14);
    final trip = TripModel.fromMap({
      'userId': 'owner',
      'status': TripStatus.active,
      'startLocation': const GeoPoint(6.9, 79.8),
      'currentLocation': {'lat': 7, 'lng': 80},
      'destination': {'lat': 7.1, 'lng': 80.1},
      'startedAt': Timestamp.fromDate(when),
    }, 'trip-id');
    expect(trip.startLocation, {'lat': 6.9, 'lng': 79.8});
    expect(trip.currentLocation, {'lat': 7.0, 'lng': 80.0});
    final restored = TripModel.fromMap(trip.toFirestore());
    expect(restored.tripId, 'trip-id');
    expect(restored.startedAt, when);
    expect(restored.destination, trip.destination);
    expect(restored.endedAt, isNull);
  });
}
