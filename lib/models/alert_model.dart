import 'package:cloud_firestore/cloud_firestore.dart';
import 'trip_model.dart' show parseLatLng, parseDate;

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

  /// Outcome shown in the alert log.
  ///
  /// An alert is only written once the SOS pipeline fires, so an alert the
  /// user has not marked as resolved is treated as escalated to contacts.
  String get outcome => resolved ? 'resolved' : 'escalated';

  /// Human-readable alert type.
  String get typeLabel => type.toLowerCase() == 'manual_sos' ? 'Manual SOS' : 'Fall Detected';

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
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return AlertModel(
      alertId: (data['alertId'] as String?)?.isNotEmpty == true ? data['alertId'] : doc.id,
      tripId: data['tripId'] ?? '',
      userId: data['userId'] ?? '',
      type: data['type'] ?? '',
      location: parseLatLng(data['location']),
      triggeredAt: parseDate(data['triggeredAt']) ?? DateTime.now(),
      resolved: data['resolved'] ?? false,
    );
  }
}
