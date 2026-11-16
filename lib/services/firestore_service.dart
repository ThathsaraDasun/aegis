import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/alert_model.dart';
import '../models/contact_model.dart';
import '../models/hazard_report_model.dart';
import '../models/shared_trip_model.dart';
import '../models/trip_model.dart';
import '../models/user_model.dart';
import 'share_token.dart';

/// Central Firestore database service used across the Safe Walk application.
/// 
/// Enforces typed CRUD and real-time streaming operations for Users, Contacts,
/// Trips, Alerts, and Hazard Reports. UI screens must call these methods and
/// never invoke [FirebaseFirestore.instance] directly.
class FirestoreService {
  final FirebaseFirestore _db;

  /// Singleton instance of [FirestoreService].
  static final FirestoreService instance = FirestoreService();

  /// Creates a [FirestoreService] instance, optionally receiving a custom [FirebaseFirestore]
  /// instance for testing or dependency injection.
  FirestoreService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  // ===========================================================================
  // USERS
  // ===========================================================================

  /// Saves or merges a user profile document at `users/{user.userId}`.
  Future<void> saveUserProfile(UserModel user) async {
    await _db.collection('users').doc(user.userId).set(
          _userToMap(user),
          SetOptions(merge: true),
        );
  }

  /// Retrieves a user profile by [userId].
  Future<UserModel?> getUserProfile(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    if (!doc.exists) return null;
    return _userFromDoc(doc);
  }

  /// Streams real-time updates for a user profile at `users/{userId}`.
  Stream<UserModel?> streamUserProfile(String userId) {
    return _db.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return _userFromDoc(doc);
    });
  }

  /// Updates safety-critical emergency medical information on `users/{userId}`.
  Future<void> updateMedicalInfo(
    String userId, {
    required String bloodType,
    required String allergies,
    required String emergencyNote,
  }) async {
    await _db.collection('users').doc(userId).set({
      'bloodType': bloodType,
      'allergies': allergies.trim(),
      'emergencyNote': emergencyNote.trim(),
    }, SetOptions(merge: true));
  }

  // ===========================================================================
  // CONTACTS (users/{uid}/contacts)
  // ===========================================================================

  /// Adds a new trusted contact under `users/{userId}/contacts`, sets `contactId`,
  /// and returns the generated document ID.
  Future<String> addContact(String userId, ContactModel contact) async {
    final ref = _db.collection('users').doc(userId).collection('contacts').doc();
    final data = _contactToMap(contact)..['contactId'] = ref.id;
    await ref.set(data);
    return ref.id;
  }

  /// Updates an existing contact at `users/{userId}/contacts/{contact.id}`.
  Future<void> updateContact(String userId, ContactModel contact) async {
    if (contact.id.isEmpty) {
      throw ArgumentError('Cannot update a contact without a valid contactId.');
    }
    final data = _contactToMap(contact)..['contactId'] = contact.id;
    await _db
        .collection('users')
        .doc(userId)
        .collection('contacts')
        .doc(contact.id)
        .set(data, SetOptions(merge: true));
  }

  /// Deletes a contact at `users/{userId}/contacts/{contactId}`.
  Future<void> deleteContact(String userId, String contactId) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('contacts')
        .doc(contactId)
        .delete();
  }

  /// Streams real-time trusted contacts list for [userId], sorted with primary guardians first.
  Stream<List<ContactModel>> streamContacts(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('contacts')
        .snapshots()
        .map((snap) => _sortContacts(snap.docs.map((d) => _contactFromDoc(d))));
  }

  /// Gets a one-shot list of trusted contacts for [userId], sorted with primary guardians first.
  Future<List<ContactModel>> getContacts(String userId) async {
    final snap =
        await _db.collection('users').doc(userId).collection('contacts').get();
    return _sortContacts(snap.docs.map((d) => _contactFromDoc(d)));
  }

  static List<ContactModel> _sortContacts(Iterable<ContactModel> contacts) {
    final list = contacts.toList();
    list.sort((a, b) {
      if (a.isPrimary != b.isPrimary) return a.isPrimary ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  // ===========================================================================
  // TRIPS (/trips)
  // ===========================================================================

  /// Creates a new trip document under `/trips`, assigns `tripId`, and returns the ID.
  ///
  /// An active trip also gets a guardian share token (generated here when the
  /// model has none) and a public mirror at `shared_trips/{shareToken}`. Both
  /// documents are written in one batch so a trip never exists without its link.
  Future<String> createTrip(TripModel trip) async {
    final ref = _db.collection('trips').doc(trip.tripId.isNotEmpty ? trip.tripId : null);
    final shareToken = ShareToken.isValid(trip.shareToken)
        ? trip.shareToken
        : ShareToken.generate();
    final data = _tripToMap(trip)
      ..['tripId'] = ref.id
      ..['shareToken'] = shareToken;
    if (trip.status != TripStatus.active) {
      await ref.set(data);
      return ref.id;
    }
    final batch = _db.batch()
      ..set(ref, data)
      ..set(
        _sharedTripRef(shareToken),
        SharedTripModel.fromTrip(trip).toMap()
          ..['updatedAt'] = FieldValue.serverTimestamp(),
      );
    await batch.commit();
    return ref.id;
  }

  DocumentReference<Map<String, dynamic>> _sharedTripRef(String shareToken) =>
      _db.collection('shared_trips').doc(shareToken);

  /// Applies [fields] to the guardian mirror. The mirror is best-effort: a
  /// failure here must never block the owner's own trip write.
  Future<void> _updateSharedTrip(
    String? shareToken,
    Map<String, dynamic> fields,
  ) async {
    if (!ShareToken.isValid(shareToken)) return;
    try {
      await _sharedTripRef(shareToken!).update({
        ...fields,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      /* Old trips have no mirror; offline writes retry inside the SDK. */
    }
  }

  /// Fetches a trip by [tripId].
  Future<TripModel?> getTrip(String tripId) async {
    final doc = await _db.collection('trips').doc(tripId).get();
    if (!doc.exists) return null;
    return _tripFromDoc(doc);
  }

  /// Streams real-time updates for a trip by [tripId].
  Stream<TripModel?> streamTrip(String tripId) {
    return _db.collection('trips').doc(tripId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return _tripFromDoc(doc);
    });
  }

  /// Streams the guardian mirror at `shared_trips/{shareToken}`.
  ///
  /// Works without signing in. Emits null when the document does not exist;
  /// once the trip ends the rules deny the read and the stream errors with
  /// `permission-denied`. A malformed token errors immediately.
  Stream<SharedTripModel?> streamSharedTrip(String shareToken) {
    if (!ShareToken.isValid(shareToken)) {
      return Stream.error(ArgumentError.value(shareToken, 'shareToken'));
    }
    return _sharedTripRef(shareToken).snapshots().map((doc) {
      final data = doc.data();
      return data == null ? null : SharedTripModel.fromMap(data);
    });
  }

  /// Updates the current GPS coordinates of an active trip, and of its
  /// guardian mirror when [shareToken] is given.
  Future<void> updateTripLocation(
    String tripId,
    double lat,
    double lng, {
    String? shareToken,
  }) async {
    final location = {'lat': lat, 'lng': lng};
    await _db.collection('trips').doc(tripId).update({
      'currentLocation': location,
    });
    await _updateSharedTrip(shareToken, {'currentLocation': location});
  }

  /// Marks a trip as completed (or custom status) and sets `endedAt` to server timestamp.
  /// The guardian mirror becomes `ended`, which the rules make unreadable.
  Future<void> endTrip(
    String tripId, {
    String status = TripStatus.completed,
    String? shareToken,
  }) async {
    await _db.collection('trips').doc(tripId).update({
      'status': status,
      'endedAt': FieldValue.serverTimestamp(),
    });
    await _updateSharedTrip(shareToken, {'status': SharedTripStatus.ended});
  }

  /// Sets the trip status to `alerted` when an emergency SOS or fall occurs.
  /// The guardian mirror stays `active` (so the link keeps working during the
  /// emergency) and is flagged with `alerted: true`.
  Future<void> markTripAlerted(String tripId, {String? shareToken}) async {
    await _db.collection('trips').doc(tripId).update({
      'status': TripStatus.alerted,
    });
    await _updateSharedTrip(shareToken, {'alerted': true});
  }

  /// Streams the currently active trip for [userId], if any.
  Stream<TripModel?> streamActiveTrip(String userId) {
    return _db
        .collection('trips')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: TripStatus.active)
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isEmpty ? null : _tripFromDoc(snap.docs.first));
  }

  /// Streams past trip history for [userId], ordered newest first (`startedAt` DESC).
  Stream<List<TripModel>> streamTripHistory(String userId) {
    return _db
        .collection('trips')
        .where('userId', isEqualTo: userId)
        .orderBy('startedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => _tripFromDoc(d)).toList());
  }

  // ===========================================================================
  // ALERTS (/alerts)
  // ===========================================================================

  /// Creates a new alert document under `/alerts`, assigns `alertId`, and returns the ID.
  Future<String> createAlert(AlertModel alert) async {
    final ref = _db.collection('alerts').doc(alert.alertId.isNotEmpty ? alert.alertId : null);
    final data = _alertToMap(alert)..['alertId'] = ref.id;
    await ref.set(data);
    return ref.id;
  }

  /// Marks an alert as resolved.
  Future<void> resolveAlert(String alertId) async {
    await _db.collection('alerts').doc(alertId).update({'resolved': true});
  }

  /// Fetches a single alert by [alertId].
  Future<AlertModel?> getAlert(String alertId) async {
    final doc = await _db.collection('alerts').doc(alertId).get();
    if (!doc.exists) return null;
    return _alertFromDoc(doc);
  }

  /// Streams all alerts triggered for [userId], ordered newest first (`triggeredAt` DESC).
  Stream<List<AlertModel>> streamAlerts(String userId) {
    return _db
        .collection('alerts')
        .where('userId', isEqualTo: userId)
        .orderBy('triggeredAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => _alertFromDoc(d)).toList());
  }

  // ===========================================================================
  // HAZARD REPORTS (/hazard_reports)
  // ===========================================================================

  /// Adds a crowd-sourced hazard report document and returns the assigned `reportId`.
  Future<String> addHazardReport(HazardReportModel report) async {
    final ref = _db.collection('hazard_reports').doc();
    final data = report.toMap(useServerTimestamp: true)..['reportId'] = ref.id;
    await ref.set(data);
    return ref.id;
  }

  /// Increments the confirmation counter (`confirmCount`) of a hazard report by 1.
  Future<void> confirmHazardReport(String reportId) async {
    await _db.collection('hazard_reports').doc(reportId).update({
      'confirmCount': FieldValue.increment(1),
    });
  }

  /// Streams all hazard reports ordered by `reportedAt` descending.
  Stream<List<HazardReportModel>> streamHazardReports() {
    return _db
        .collection('hazard_reports')
        .orderBy('reportedAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => HazardReportModel.fromMap(d.id, d.data())).toList());
  }

  /// Queries hazard reports within a bounding latitude band, filtering longitude
  /// and exact Haversine distance ([radiusMeters]) on the client.
  Future<List<HazardReportModel>> getNearbyHazards(
    double lat,
    double lng,
    double radiusMeters,
  ) async {
    // 1 degree latitude ~ 111,000 meters
    final double latDelta = radiusMeters / 111000.0;
    final double minLat = lat - latDelta;
    final double maxLat = lat + latDelta;

    final snap = await _db
        .collection('hazard_reports')
        .where('location.lat', isGreaterThanOrEqualTo: minLat)
        .where('location.lat', isLessThanOrEqualTo: maxLat)
        .get();

    final allInBand = snap.docs.map((d) => HazardReportModel.fromMap(d.id, d.data()));

    final nearby = allInBand.where((h) {
      final dist = _haversineMeters(lat, lng, h.lat, h.lng);
      return dist <= radiusMeters;
    }).toList();

    nearby.sort((a, b) {
      final dA = _haversineMeters(lat, lng, a.lat, a.lng);
      final dB = _haversineMeters(lat, lng, b.lat, b.lng);
      return dA.compareTo(dB);
    });

    return nearby;
  }

  static double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0; // Earth radius in meters
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static double _toRadians(double degree) => degree * math.pi / 180.0;

  // ===========================================================================
  // MODEL ADAPTERS
  // ===========================================================================

  Map<String, dynamic> _userToMap(UserModel user) => user.toMap();
  UserModel _userFromDoc(DocumentSnapshot doc) => UserModel.fromFirestore(doc);

  Map<String, dynamic> _contactToMap(ContactModel contact) => contact.toMap();
  ContactModel _contactFromDoc(DocumentSnapshot doc) =>
      ContactModel.fromMap(doc.id, (doc.data() as Map<String, dynamic>?) ?? {});

  Map<String, dynamic> _tripToMap(TripModel trip) => trip.toMap();
  TripModel _tripFromDoc(DocumentSnapshot doc) => TripModel.fromFirestore(doc);

  Map<String, dynamic> _alertToMap(AlertModel alert) => alert.toMap();
  AlertModel _alertFromDoc(DocumentSnapshot doc) => AlertModel.fromFirestore(doc);
}
