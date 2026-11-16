import 'package:cloud_firestore/cloud_firestore.dart';

import 'trip_model.dart';

/// Status values of a `shared_trips` mirror document.
class SharedTripStatus {
  /// The trip is running; the guardian link works.
  static const String active = 'active';

  /// The trip has finished; the rules stop all reads.
  static const String ended = 'ended';
}

/// Public mirror of a live trip at `shared_trips/{shareToken}`.
///
/// It holds only what a guardian needs to follow the walker: no trip ID,
/// no profile data. The owner writes it; anyone with the token may read it
/// while [status] is [SharedTripStatus.active].
class SharedTripModel {
  final String userId;
  final Map<String, double> currentLocation;
  final Map<String, double> destination;
  final String status;

  /// True once an SOS or fall alert has been raised during this trip.
  final bool alerted;
  final DateTime? updatedAt;

  const SharedTripModel({
    required this.userId,
    required this.currentLocation,
    required this.destination,
    required this.status,
    this.alerted = false,
    this.updatedAt,
  });

  bool get isLive => status == SharedTripStatus.active;

  /// Builds the mirror for [trip]; any non-active trip maps to `ended`, except
  /// `alerted`, which stays live so guardians can follow an emergency.
  factory SharedTripModel.fromTrip(TripModel trip) => SharedTripModel(
    userId: trip.userId,
    currentLocation: trip.currentLocation,
    destination: trip.destination,
    status: trip.status == TripStatus.completed || trip.endedAt != null
        ? SharedTripStatus.ended
        : SharedTripStatus.active,
    alerted: trip.status == TripStatus.alerted,
  );

  /// Firestore fields. `updatedAt` is written by the service as a server timestamp.
  Map<String, dynamic> toMap() => {
    'userId': userId,
    'currentLocation': currentLocation,
    'destination': destination,
    'status': status,
    'alerted': alerted,
  };

  factory SharedTripModel.fromMap(Map<String, dynamic> map) => SharedTripModel(
    userId: (map['userId'] as String?) ?? '',
    currentLocation: _location(map['currentLocation']),
    destination: _location(map['destination']),
    status: (map['status'] as String?) ?? SharedTripStatus.ended,
    alerted: map['alerted'] == true,
    updatedAt: map['updatedAt'] is Timestamp
        ? (map['updatedAt'] as Timestamp).toDate()
        : null,
  );

  static Map<String, double> _location(dynamic value) {
    if (value is Map) {
      return {
        'lat': (value['lat'] as num?)?.toDouble() ?? 0.0,
        'lng': (value['lng'] as num?)?.toDouble() ?? 0.0,
      };
    }
    return {'lat': 0.0, 'lng': 0.0};
  }
}
