import 'lat_lng.dart';

/// Destination details for a trip.
class Destination {
  final double lat;
  final double lng;
  final String label;

  const Destination({
    required this.lat,
    required this.lng,
    required this.label,
  });

  /// Helper getter to convert destination coordinates to a [LatLng] instance.
  LatLng get latLng => LatLng(latitude: lat, longitude: lng);

  factory Destination.fromMap(Map<String, dynamic> map) {
    return Destination(
      lat: (map['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (map['lng'] as num?)?.toDouble() ?? 0.0,
      label: map['label'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lat': lat,
      'lng': lng,
      'label': label,
    };
  }
}

/// Represents a Trip entity stored in Firestore at /trips/{tripId}.
class Trip {
  final String tripId;
  final String ownerId;
  final String status; // "active" | "completed" | "cancelled"
  final DateTime startTime;
  final DateTime? endTime;
  final Destination destination;
  final String routeChosen;
  final List<String> sharedWithContactIds;

  const Trip({
    required this.tripId,
    required this.ownerId,
    required this.status,
    required this.startTime,
    this.endTime,
    required this.destination,
    required this.routeChosen,
    required this.sharedWithContactIds,
  });

  factory Trip.fromMap(String tripId, Map<String, dynamic> map) {
    return Trip(
      tripId: tripId,
      ownerId: map['ownerId'] as String? ?? '',
      status: map['status'] as String? ?? 'active',
      startTime: map['startTime'] != null
          ? DateTime.tryParse(map['startTime'].toString()) ?? DateTime.now()
          : DateTime.now(),
      endTime: map['endTime'] != null
          ? DateTime.tryParse(map['endTime'].toString())
          : null,
      destination: Destination.fromMap(map['destination'] as Map<String, dynamic>? ?? {}),
      routeChosen: map['routeChosen'] as String? ?? '',
      sharedWithContactIds: List<String>.from(map['sharedWithContactIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'status': status,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'destination': destination.toMap(),
      'routeChosen': routeChosen,
      'sharedWithContactIds': sharedWithContactIds,
    };
  }
}

/// Summary of a past trip for trip history list.
class TripSummary {
  final String tripId;
  final String destinationLabel;
  final DateTime date;
  final Duration duration;
  final bool alertOccurred;
  final String routeChosen;

  const TripSummary({
    required this.tripId,
    required this.destinationLabel,
    required this.date,
    required this.duration,
    required this.alertOccurred,
    required this.routeChosen,
  });

  factory TripSummary.fromMap(String tripId, Map<String, dynamic> map) {
    return TripSummary(
      tripId: tripId,
      destinationLabel: map['destinationLabel'] as String? ?? map['destination']?['label'] as String? ?? 'Unknown Destination',
      date: map['startTime'] != null
          ? DateTime.tryParse(map['startTime'].toString()) ?? DateTime.now()
          : DateTime.now(),
      duration: Duration(seconds: map['durationSeconds'] as int? ?? 0),
      alertOccurred: map['alertOccurred'] as bool? ?? false,
      routeChosen: map['routeChosen'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'destinationLabel': destinationLabel,
      'startTime': date.toIso8601String(),
      'durationSeconds': duration.inSeconds,
      'alertOccurred': alertOccurred,
      'routeChosen': routeChosen,
    };
  }
}
