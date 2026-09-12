import 'package:cloud_firestore/cloud_firestore.dart';

class TripModel {
  final String tripId;
  final String userId;
  final String status; // "active" | "completed" | "alerted"
  final GeoPoint startLocation;
  final GeoPoint currentLocation;
  final GeoPoint destination;
  final DateTime startedAt;
  final DateTime? endedAt;

  TripModel({
    required this.tripId,
    required this.userId,
    required this.status,
    required this.startLocation,
    required this.currentLocation,
    required this.destination,
    required this.startedAt,
    this.endedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'tripId': tripId,
      'userId': userId,
      'status': status,
      'startLocation': {
        'lat': startLocation.latitude,
        'lng': startLocation.longitude,
      },
      'currentLocation': {
        'lat': currentLocation.latitude,
        'lng': currentLocation.longitude,
      },
      'destination': {
        'lat': destination.latitude,
        'lng': destination.longitude,
      },
      'startedAt': startedAt,
      'endedAt': endedAt,
    };
  }

  factory TripModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    GeoPoint _toGeoPoint(dynamic loc) {
      if (loc is GeoPoint) return loc;
      if (loc is Map) {
        return GeoPoint(
          (loc['lat'] as num).toDouble(),
          (loc['lng'] as num).toDouble(),
        );
      }
      return const GeoPoint(0, 0);
    }

    return TripModel(
      tripId: doc.id,
      userId: data['userId'] ?? '',
      status: data['status'] ?? 'active',
      startLocation: _toGeoPoint(data['startLocation']),
      currentLocation: _toGeoPoint(data['currentLocation']),
      destination: _toGeoPoint(data['destination']),
      startedAt: (data['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endedAt: (data['endedAt'] as Timestamp?)?.toDate(),
    );
  }
}
