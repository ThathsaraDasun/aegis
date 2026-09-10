import 'package:cloud_firestore/cloud_firestore.dart';

class ContactModel {
  final String contactId;
  final String name;
  final String relation;
  final String phone;

  ContactModel({
    required this.contactId,
    required this.name,
    required this.relation,
    required this.phone,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'contactId': contactId,
      'name': name,
      'relation': relation,
      'phone': phone,
    };
  }

  factory ContactModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ContactModel(
      contactId: data['contactId'] ?? '',
      name: data['name'] ?? '',
      relation: data['relation'] ?? '',
      phone: data['phone'] ?? '',
    );
  }
}
