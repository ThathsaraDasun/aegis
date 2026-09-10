class ContactModel {
  final String id;
  final String name;
  final String phone;
  final String relation;
  final String bloodType;
  final bool isPrimary;

  ContactModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.relation,
    required this.bloodType,
    this.isPrimary = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'relation': relation,
      'bloodType': bloodType,
      'isPrimary': isPrimary,
    };
  }

  factory ContactModel.fromMap(String id, Map<String, dynamic> map) {
    return ContactModel(
      id: id,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      relation: map['relation'] ?? '',
      bloodType: map['bloodType'] ?? 'O+',
      isPrimary: map['isPrimary'] ?? false,
    );
  }
}
