import 'package:cloud_firestore/cloud_firestore.dart';

class AlertType {
  static const String fallDetected = 'fall_detected';
  static const String manualSos = 'manual_sos';

  static const List<String> all = [fallDetected, manualSos];
}

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

  Map<String, dynamic> toMap() {
    return {
      'alertId': alertId,
      'tripId': tripId,
      'userId': userId,
      'type': type,
      'location': location,
      'triggeredAt': Timestamp.fromDate(triggeredAt),
      'resolved': resolved,
    };
  }

  Map<String, dynamic> toFirestore() => toMap();

  factory AlertModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    return AlertModel(
      alertId: (map['alertId'] as String?) ?? docId ?? '',
      tripId: (map['tripId'] as String?) ?? '',
      userId: (map['userId'] as String?) ?? '',
      type: (map['type'] as String?) ?? AlertType.manualSos,
      location: _parseLocationMap(map['location']),
      triggeredAt: _parseDate(map['triggeredAt']),
      resolved: (map['resolved'] as bool?) ?? false,
    );
  }

  factory AlertModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return AlertModel.fromMap(data, doc.id);
  }

  static Map<String, double> _parseLocationMap(dynamic locData) {
    if (locData is Map) {
      return {
        'lat': (locData['lat'] as num?)?.toDouble() ?? 0.0,
        'lng': (locData['lng'] as num?)?.toDouble() ?? 0.0,
      };
    }
    return {'lat': 0.0, 'lng': 0.0};
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
