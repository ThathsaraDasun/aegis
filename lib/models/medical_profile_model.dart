/// Optional medical information shown to trusted contacts during an active SOS.
///
/// Stored as fields on the `users/{uid}` document so it stays compatible with
/// [UserModel] (bloodType, allergies, emergencyNote) – `conditions` is an
/// extra optional field.
class MedicalProfile {
  static const List<String> bloodTypes = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
  ];

  final String bloodType;
  final String allergies;
  final String conditions;
  final String emergencyNote;

  const MedicalProfile({
    this.bloodType = '',
    this.allergies = '',
    this.conditions = '',
    this.emergencyNote = '',
  });

  static const MedicalProfile empty = MedicalProfile();

  bool get isEmpty =>
      bloodType.isEmpty &&
      allergies.isEmpty &&
      conditions.isEmpty &&
      emergencyNote.isEmpty;

  bool get isNotEmpty => !isEmpty;

  factory MedicalProfile.fromMap(Map<String, dynamic>? map) {
    if (map == null) return MedicalProfile.empty;
    return MedicalProfile(
      bloodType: (map['bloodType'] ?? '') as String,
      allergies: (map['allergies'] ?? '') as String,
      conditions: (map['conditions'] ?? '') as String,
      emergencyNote: (map['emergencyNote'] ?? '') as String,
    );
  }

  Map<String, dynamic> toMap() => {
        'bloodType': bloodType,
        'allergies': allergies.trim(),
        'conditions': conditions.trim(),
        'emergencyNote': emergencyNote.trim(),
      };

  /// One-line summary used in SOS messages, e.g.
  /// "Blood O+ | Allergies: Penicillin | Note: Contact mother first".
  String toSosSummary() {
    final parts = <String>[
      if (bloodType.isNotEmpty) 'Blood $bloodType',
      if (allergies.isNotEmpty) 'Allergies: $allergies',
      if (conditions.isNotEmpty) 'Conditions: $conditions',
      if (emergencyNote.isNotEmpty) 'Note: $emergencyNote',
    ];
    return parts.join(' | ');
  }
}
