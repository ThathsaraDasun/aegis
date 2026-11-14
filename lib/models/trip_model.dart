import 'package:cloud_firestore/cloud_firestore.dart';

extension TripLocationExt on Map<String, double> {
  double get latitude => this['lat'] ?? 0.0;
  double get longitude => this['lng'] ?? 0.0;
  GeoPoint get geoPoint => GeoPoint(latitude, longitude);
}

class TripModel {
  final String tripId;
  final String userId;
  final String status; // active | completed | alerted
  final Map<String, double> startLocation;
  final Map<String, double> currentLocation;
  final Map<String, double> destination;
  final DateTime startedAt;
  final DateTime? endedAt;

  TripModel({
    required this.tripId,
    required this.userId,
    this.status = 'active',
    required dynamic startLocation,
    required dynamic currentLocation,
    required dynamic destination,
    required this.startedAt,
    this.endedAt,
  })  : startLocation = _normalizeLocation(startLocation),
        currentLocation = _normalizeLocation(currentLocation),
        destination = _normalizeLocation(destination);

  static Map<String, double> _normalizeLocation(dynamic loc) {
    if (loc is GeoPoint) {
      return {'lat': loc.latitude, 'lng': loc.longitude};
    }
    if (loc is Map) {
      return {
        'lat': (loc['lat'] as num?)?.toDouble() ?? 0.0,
        'lng': (loc['lng'] as num?)?.toDouble() ?? 0.0,
      };
    }
    return {'lat': 0.0, 'lng': 0.0};
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tripId': tripId,
      'userId': userId,
      'status': status,
      'startLocation': startLocation,
      'currentLocation': currentLocation,
      'destination': destination,
      'startedAt': startedAt,
      'endedAt': endedAt,
    };
  }

  factory TripModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return TripModel(
      tripId: doc.id.isNotEmpty ? doc.id : (data['tripId'] ?? ''),
      userId: data['userId'] ?? '',
      status: data['status'] ?? 'active',
      startLocation: data['startLocation'],
      currentLocation: data['currentLocation'],
      destination: data['destination'],
      startedAt: (data['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endedAt: (data['endedAt'] as Timestamp?)?.toDate(),
    );
  }
}
