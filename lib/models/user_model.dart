import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String userId;
  final String name;
  final String phone;
  final String bloodType;
  final String allergies;
  final String emergencyNote;

  UserModel({
    required this.userId,
    required this.name,
    required this.phone,
    this.bloodType = '',
    this.allergies = '',
    this.emergencyNote = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'phone': phone,
      'bloodType': bloodType,
      'allergies': allergies,
      'emergencyNote': emergencyNote,
    };
  }

  Map<String, dynamic> toFirestore() => toMap();

  factory UserModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    return UserModel(
      userId: (map['userId'] as String?) ?? docId ?? '',
      name: (map['name'] as String?) ?? '',
      phone: (map['phone'] as String?) ?? '',
      bloodType: (map['bloodType'] as String?) ?? '',
      allergies: (map['allergies'] as String?) ?? '',
      emergencyNote: (map['emergencyNote'] as String?) ?? '',
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return UserModel.fromMap(data, doc.id);
  }

  UserModel copyWith({
    String? userId,
    String? name,
    String? phone,
    String? bloodType,
    String? allergies,
    String? emergencyNote,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      bloodType: bloodType ?? this.bloodType,
      allergies: allergies ?? this.allergies,
      emergencyNote: emergencyNote ?? this.emergencyNote,
    );
  }
}
