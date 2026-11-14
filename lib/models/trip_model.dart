import 'package:cloud_firestore/cloud_firestore.dart';

class TripStatus {
  static const String active = 'active';
  static const String completed = 'completed';
  static const String alerted = 'alerted';

  static const List<String> all = [active, completed, alerted];
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
    required this.status,
    required this.startLocation,
    required this.currentLocation,
    required this.destination,
    required this.startedAt,
    this.endedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'tripId': tripId,
      'userId': userId,
      'status': status,
      'startLocation': startLocation,
      'currentLocation': currentLocation,
      'destination': destination,
      'startedAt': Timestamp.fromDate(startedAt),
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
    };
  }

  Map<String, dynamic> toFirestore() => toMap();

  factory TripModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    return TripModel(
      tripId: (map['tripId'] as String?) ?? docId ?? '',
      userId: (map['userId'] as String?) ?? (map['ownerId'] as String?) ?? '',
      status: (map['status'] as String?) ?? TripStatus.active,
      startLocation: _parseLocationMap(map['startLocation']),
      currentLocation: _parseLocationMap(map['currentLocation']),
      destination: _parseLocationMap(map['destination']),
      startedAt: _parseDate(map['startedAt'] ?? map['startTime']),
      endedAt: map['endedAt'] != null || map['endTime'] != null
          ? _parseDate(map['endedAt'] ?? map['endTime'])
          : null,
    );
  }

  factory TripModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return TripModel.fromMap(data, doc.id);
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
