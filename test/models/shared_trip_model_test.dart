import 'package:aegis/models/shared_trip_model.dart';
import 'package:aegis/models/trip_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

TripModel _trip({
  String status = TripStatus.active,
  DateTime? endedAt,
  String shareToken = '',
}) => TripModel(
  tripId: 't1',
  userId: 'u1',
  status: status,
  startLocation: {'lat': 6.9, 'lng': 79.8},
  currentLocation: {'lat': 6.91, 'lng': 79.81},
  destination: {'lat': 6.93, 'lng': 79.86},
  startedAt: DateTime(2026, 11, 16, 9),
  endedAt: endedAt,
  shareToken: shareToken,
);

void main() {
  group('TripModel.shareToken', () {
    test('round-trips through toMap/fromMap', () {
      final map = _trip(shareToken: 'abc').toMap();
      expect(map['shareToken'], 'abc');
      expect(TripModel.fromMap(map).shareToken, 'abc');
    });

    test('defaults to empty for trips saved before sharing existed', () {
      final map = _trip().toMap()..remove('shareToken');
      expect(TripModel.fromMap(map).shareToken, '');
    });
  });

  group('SharedTripModel', () {
    test('mirror holds only the guardian fields', () {
      final map = SharedTripModel.fromTrip(_trip(shareToken: 'secret')).toMap();
      expect(map.keys.toSet(), {
        'userId',
        'currentLocation',
        'destination',
        'status',
        'alerted',
      });
      expect(map['status'], SharedTripStatus.active);
      expect(map.values, isNot(contains('secret')));
      expect(map.values, isNot(contains('t1')));
    });

    test('alerted trips stay live; finished trips end', () {
      final alerted = SharedTripModel.fromTrip(_trip(status: TripStatus.alerted));
      expect(alerted.isLive, isTrue);
      expect(alerted.alerted, isTrue);

      final completed = SharedTripModel.fromTrip(
        _trip(status: TripStatus.completed, endedAt: DateTime(2026, 11, 16, 10)),
      );
      expect(completed.isLive, isFalse);

      final timedOut = SharedTripModel.fromTrip(
        _trip(status: TripStatus.alerted, endedAt: DateTime(2026, 11, 16, 10)),
      );
      expect(timedOut.isLive, isFalse);
    });

    test('fromMap reads Firestore data and fails closed', () {
      final model = SharedTripModel.fromMap({
        'userId': 'u1',
        'currentLocation': {'lat': 6.91, 'lng': 79.81},
        'destination': {'lat': 6.93, 'lng': 79.86},
        'status': 'active',
        'alerted': true,
        'updatedAt': Timestamp.fromDate(DateTime(2026, 11, 16, 9, 5)),
      });
      expect(model.isLive, isTrue);
      expect(model.alerted, isTrue);
      expect(model.currentLocation, {'lat': 6.91, 'lng': 79.81});
      expect(model.updatedAt, DateTime(2026, 11, 16, 9, 5));

      final empty = SharedTripModel.fromMap({});
      expect(empty.isLive, isFalse);
      expect(empty.alerted, isFalse);
    });
  });
}
