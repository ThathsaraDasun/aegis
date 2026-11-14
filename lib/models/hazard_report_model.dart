import 'package:cloud_firestore/cloud_firestore.dart';

/// Crowd-sourced hazard pin stored in the `hazard_reports` collection.
///
/// Firestore schema (scope doc §4, extended):
/// ```json
/// { "reportId": "hz_101", "category": "poor_lighting",
///   "location": {"lat": 6.9295, "lng": 79.8635}, "geohash": "tc3m2x9",
///   "description": "...", "reportedBy": "uid",
///   "reportedAt": TIMESTAMP, "confirmCount": 3 }
/// ```
class HazardReportModel {
  final String id;

  /// One of [HazardCategory.all] keys (e.g. `poor_lighting`).
  final String category;
  final String description;
  final double lat;
  final double lng;

  /// Geohash (precision 9) of [lat]/[lng] – used for Firestore geoqueries.
  final String geohash;
  final String reportedBy;
  final int confirmCount;
  final DateTime reportedAt;

  HazardReportModel({
    required this.id,
    required this.category,
    required this.lat,
    required this.lng,
    required this.reportedAt,
    this.description = '',
    this.geohash = '',
    this.reportedBy = '',
    this.confirmCount = 1,
  });

  String get reportId => id;

  HazardCategory get categoryInfo => HazardCategory.fromKey(category);

  Map<String, dynamic> toMap({bool useServerTimestamp = false}) {
    return {
      'category': category,
      'description': description.trim(),
      'location': {'lat': lat, 'lng': lng},
      'geohash': geohash,
      'reportedBy': reportedBy,
      'confirmCount': confirmCount,
      'reportedAt': useServerTimestamp
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(reportedAt),
    };
  }

  factory HazardReportModel.fromMap(String id, Map<String, dynamic> map) {
    final loc = (map['location'] as Map?)?.cast<String, dynamic>() ?? const {};
    return HazardReportModel(
      id: id,
      category: HazardCategory.normalizeKey(map['category'] as String?),
      description: (map['description'] ?? '') as String,
      lat: (loc['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (loc['lng'] as num?)?.toDouble() ?? 0.0,
      geohash: (map['geohash'] ?? '') as String,
      reportedBy: (map['reportedBy'] ?? '') as String,
      confirmCount: (map['confirmCount'] as num?)?.toInt() ?? 1,
      reportedAt: _parseDate(map['reportedAt']),
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    // Server timestamp not resolved yet (local pending write).
    return DateTime.now();
  }
}

/// Hazard category metadata (label + scoring weight). UI styling (icon/colour)
/// lives in `screens/route/widgets/hazard_style.dart`.
class HazardCategory {
  final String key;
  final String label;
  final String description;

  /// How strongly one report of this type lowers a route's safety score.
  final double weight;

  const HazardCategory._(this.key, this.label, this.description, this.weight);

  static const poorLighting = HazardCategory._(
      'poor_lighting', 'Poor Lighting', 'Dark or unlit stretch', 1.0);
  static const unsafeArea = HazardCategory._(
      'unsafe_area', 'Unsafe Area', 'Loitering, harassment, threat', 1.5);
  static const pastIncident = HazardCategory._(
      'past_incident', 'Past Incident', 'Something happened here', 2.0);
  static const noSidewalk = HazardCategory._(
      'no_sidewalk', 'No Sidewalk', 'Walking on the road', 0.8);
  static const other =
      HazardCategory._('other', 'Other', 'Blocked path, animals, etc.', 0.7);

  static const List<HazardCategory> all = [
    poorLighting,
    unsafeArea,
    pastIncident,
    noSidewalk,
    other,
  ];

  static HazardCategory fromKey(String? key) {
    final normalized = normalizeKey(key);
    return all.firstWhere((c) => c.key == normalized, orElse: () => other);
  }

  /// Maps legacy labels written by the first version of the screen
  /// ("Broken Light", "Suspicious Act", ...) onto schema keys.
  static String normalizeKey(String? raw) {
    switch (raw) {
      case 'poor_lighting':
      case 'Broken Light':
        return 'poor_lighting';
      case 'unsafe_area':
      case 'Suspicious Act':
      case 'Animal Threat':
        return 'unsafe_area';
      case 'past_incident':
        return 'past_incident';
      case 'no_sidewalk':
        return 'no_sidewalk';
      case 'Blocked Path':
      case 'other':
        return 'other';
      default:
        return 'other';
    }
  }
}
