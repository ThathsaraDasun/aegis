import 'package:cloud_firestore/cloud_firestore.dart';

class AlertModel {
  final String alertId;
  final String tripId;
  final String userId;
  final String type; // fall_detected | manual_sos
  final Map<String, double> location;
  final DateTime triggeredAt;
  final bool resolved;

  AlertModel({
    required this.alertId,
    required this.tripId,
    required this.userId,
    required this.type,
    required this.location,
    required this.triggeredAt,
    this.resolved = false,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'alertId': alertId,
      'tripId': tripId,
      'userId': userId,
      'type': type,
      'location': location,
      'triggeredAt': triggeredAt,
      'resolved': resolved,
    };
  }

  factory AlertModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AlertModel(
      alertId: data['alertId'] ?? '',
      tripId: data['tripId'] ?? '',
      userId: data['userId'] ?? '',
      type: data['type'] ?? '',
      location: Map<String, double>.from(data['location'] ?? {}),
      triggeredAt: (data['triggeredAt'] as Timestamp).toDate(),
      resolved: data['resolved'] ?? false,
    );
  }
}
