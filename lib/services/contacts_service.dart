import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/contact_model.dart';
import '../models/medical_profile_model.dart';

/// Trusted contacts (`users/{uid}/contacts`) and the user's medical profile
/// (fields on `users/{uid}`) – Member 3.
///
/// For the SOS flow (Member 1 / Member 4) use [getEmergencyContacts] and
/// [getMedicalProfile]: primary guardians come first.
class ContactsService {
  ContactsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Maximum number of guardians a user can keep.
  static const int maxContacts = 10;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _contacts(String uid) =>
      _userDoc(uid).collection('contacts');

  // ---------------------------------------------------------------------------
  // Contacts
  // ---------------------------------------------------------------------------

  /// Live list of contacts: primary guardians first, then A–Z.
  Stream<List<ContactModel>> streamContacts(String uid) {
    return _contacts(uid).snapshots().map((snapshot) => sortContacts(
        snapshot.docs.map((doc) => ContactModel.fromMap(doc.id, doc.data()))));
  }

  /// One-shot list for the SOS pipeline (primary first).
  Future<List<ContactModel>> getEmergencyContacts(String uid) async {
    final snap = await _contacts(uid).get();
    return sortContacts(snap.docs.map((d) => ContactModel.fromMap(d.id, d.data())));
  }

  static List<ContactModel> sortContacts(Iterable<ContactModel> contacts) {
    final list = contacts.toList();
    list.sort((a, b) {
      if (a.isPrimary != b.isPrimary) return a.isPrimary ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  /// Adds a contact and returns its new id.
  Future<String> addContact(String uid, ContactModel contact) async {
    final ref = _contacts(uid).doc();
    await ref.set({
      ...contact.toMap(),
      'contactId': ref.id,
      'phone': normalizePhone(contact.phone),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> updateContact(String uid, ContactModel contact) {
    if (contact.id.isEmpty) {
      throw ArgumentError('Cannot update a contact without an id.');
    }
    return _contacts(uid).doc(contact.id).set({
      ...contact.toMap(),
      'contactId': contact.id,
      'phone': normalizePhone(contact.phone),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteContact(String uid, String contactId) {
    return _contacts(uid).doc(contactId).delete();
  }

  /// Re-creates a deleted contact with the same id (used by "Undo").
  Future<void> restoreContact(String uid, ContactModel contact) {
    return _contacts(uid).doc(contact.id).set({
      ...contact.toMap(),
      'contactId': contact.id,
    });
  }

  // ---------------------------------------------------------------------------
  // Medical profile
  // ---------------------------------------------------------------------------

  Stream<MedicalProfile> streamMedicalProfile(String uid) {
    return _userDoc(uid).snapshots().map((doc) => MedicalProfile.fromMap(doc.data()));
  }

  Future<MedicalProfile> getMedicalProfile(String uid) async {
    final doc = await _userDoc(uid).get();
    return MedicalProfile.fromMap(doc.data());
  }

  Future<void> saveMedicalProfile(String uid, MedicalProfile profile) {
    return _userDoc(uid).set(profile.toMap(), SetOptions(merge: true));
  }

  /// Kept for older callers – prefer [saveMedicalProfile].
  Future<void> updateMedicalProfile(
    String uid, {
    required String bloodType,
    required String allergies,
    required String emergencyNote,
    String conditions = '',
  }) {
    return saveMedicalProfile(
      uid,
      MedicalProfile(
        bloodType: bloodType,
        allergies: allergies,
        conditions: conditions,
        emergencyNote: emergencyNote,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Validation helpers (pure)
  // ---------------------------------------------------------------------------

  /// Strips spaces, dashes and brackets; converts a local Sri Lankan number
  /// (07XXXXXXXX) to +94 format. Other numbers are left as typed.
  static String normalizePhone(String raw) {
    var p = raw.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (p.startsWith('00')) p = '+${p.substring(2)}';
    if (RegExp(r'^0\d{9}$').hasMatch(p)) p = '+94${p.substring(1)}';
    return p;
  }

  /// Returns an error message, or null when the number looks valid.
  static String? validatePhone(String? raw) {
    final p = normalizePhone(raw ?? '');
    if (p.isEmpty) return 'Phone number is required';
    if (!RegExp(r'^\+?\d{7,15}$').hasMatch(p)) return 'Enter a valid phone number';
    return null;
  }
}
