import 'package:cloud_firestore/cloud_firestore.dart';

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
      tripId: (data['tripId'] as String?)?.isNotEmpty == true ? data['tripId'] : doc.id,
      userId: data['userId'] ?? '',
      status: data['status'] ?? 'active',
      startLocation: parseLatLng(data['startLocation']),
      currentLocation: parseLatLng(data['currentLocation']),
      destination: parseLatLng(data['destination']),
      startedAt: parseDate(data['startedAt']) ?? DateTime.now(),
      endedAt: parseDate(data['endedAt']),
    );
  }
}

/// Reads a {lat, lng} map from Firestore, accepting ints, doubles or GeoPoints.
Map<String, double> parseLatLng(dynamic value) {
  if (value is GeoPoint) {
    return {'lat': value.latitude, 'lng': value.longitude};
  }
  if (value is Map) {
    final result = <String, double>{};
    value.forEach((key, v) {
      if (v is num) result[key.toString()] = v.toDouble();
    });
    return result;
  }
  return {};
}

/// Reads a date from Firestore, accepting a Timestamp, DateTime or ISO string.
DateTime? parseDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
