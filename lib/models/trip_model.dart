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
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TripModel(
      tripId: data['tripId'] ?? '',
      userId: data['userId'] ?? '',
      status: data['status'] ?? 'active',
      startLocation: Map<String, double>.from(data['startLocation'] ?? {}),
      currentLocation: Map<String, double>.from(data['currentLocation'] ?? {}),
      destination: Map<String, double>.from(data['destination'] ?? {}),
      startedAt: (data['startedAt'] as Timestamp).toDate(),
      endedAt: data['endedAt'] != null ? (data['endedAt'] as Timestamp).toDate() : null,
    );
  }
}
