import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/contact_model.dart';

class ContactsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream all contacts for the current user
  Stream<List<ContactModel>> streamContacts(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('contacts')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ContactModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  // Add new contact
  Future<void> addContact(String uid, ContactModel contact) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('contacts')
        .add(contact.toMap());
  }

  // Delete contact
  Future<void> deleteContact(String uid, String contactId) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('contacts')
        .doc(contactId)
        .delete();
  }

  // Update Medical Profile on User Document
  Future<void> updateMedicalProfile(String uid, {
    required String bloodType,
    required String allergies,
    required String emergencyNote,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'bloodType': bloodType,
      'allergies': allergies,
      'emergencyNote': emergencyNote,
    }, SetOptions(merge: true));
  }
}
