/// Trusted contact ("guardian") stored at `users/{uid}/contacts/{contactId}`.
///
/// Firestore schema (scope doc §4):
/// ```json
/// { "contactId": "cnt_01", "name": "Trusted Contact",
///   "relation": "Mother", "phone": "+94777654321", "isPrimary": true }
/// ```
///
/// Medical info is NOT stored per contact – it belongs to the user and lives
/// on the `users/{uid}` document (see `MedicalProfile`).
class ContactModel {
  final String id;
  final String name;
  final String phone;
  final String relation;

  /// Primary guardians are alerted first during an SOS.
  final bool isPrimary;

  /// Legacy field kept only so older callers keep compiling. It is no longer
  /// written to Firestore – medical info lives on the user profile.
  final String bloodType;

  ContactModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.relation,
    this.isPrimary = false,
    this.bloodType = '',
  });

  /// `contactId` alias that matches the schema naming.
  String get contactId => id;

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'phone': phone.trim(),
      'relation': relation.trim(),
      'isPrimary': isPrimary,
    };
  }

  factory ContactModel.fromMap(String id, Map<String, dynamic> map) {
    return ContactModel(
      id: id,
      name: (map['name'] ?? '') as String,
      phone: (map['phone'] ?? '') as String,
      relation: (map['relation'] ?? '') as String,
      isPrimary: (map['isPrimary'] ?? false) as bool,
    );
  }

  ContactModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? relation,
    bool? isPrimary,
  }) {
    return ContactModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relation: relation ?? this.relation,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }
}
