import 'dart:convert';

class SavedLocation {
  final String id;
  final String label;
  final double latitude;
  final double longitude;
  final DateTime savedAt;

  SavedLocation({
    required this.id,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.savedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'latitude': latitude,
      'longitude': longitude,
      'savedAt': savedAt.toIso8601String(),
    };
  }

  factory SavedLocation.fromMap(Map<String, dynamic> map) {
    return SavedLocation(
      id: map['id'] ?? '',
      label: map['label'] ?? '',
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      savedAt: DateTime.parse(map['savedAt']),
    );
  }

  String toJson() => json.encode(toMap());

  factory SavedLocation.fromJson(String source) =>
      SavedLocation.fromMap(json.decode(source));
}
