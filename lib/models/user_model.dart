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

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'phone': phone,
      'bloodType': bloodType,
      'allergies': allergies,
      'emergencyNote': emergencyNote,
    };
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      bloodType: data['bloodType'] ?? '',
      allergies: data['allergies'] ?? '',
      emergencyNote: data['emergencyNote'] ?? '',
    );
  }
}
