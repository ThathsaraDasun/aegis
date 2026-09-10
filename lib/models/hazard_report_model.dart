class HazardReportModel {
  final String id;
  final String category; // 'Broken Light', 'Suspicious Act', 'Blocked Path', 'Animal Threat'
  final String description;
  final double lat;
  final double lng;
  final String severity; // 'Low', 'Medium', 'High'
  final int confirmCount;
  final DateTime reportedAt;

  HazardReportModel({
    required this.id,
    required this.category,
    required this.description,
    required this.lat,
    required this.lng,
    required this.severity,
    required this.confirmCount,
    required this.reportedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'description': description,
      'location': {'lat': lat, 'lng': lng},
      'severity': severity,
      'confirmCount': confirmCount,
      'reportedAt': reportedAt.toIso8601String(),
    };
  }

  factory HazardReportModel.fromMap(String id, Map<String, dynamic> map) {
    final loc = map['location'] as Map<String, dynamic>? ?? {};
    return HazardReportModel(
      id: id,
      category: map['category'] ?? 'Broken Light',
      description: map['description'] ?? '',
      lat: (loc['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (loc['lng'] as num?)?.toDouble() ?? 0.0,
      severity: map['severity'] ?? 'Medium',
      confirmCount: map['confirmCount'] ?? 1,
      reportedAt: DateTime.tryParse(map['reportedAt'] ?? '') ?? DateTime.now(),
    );
  }
}
