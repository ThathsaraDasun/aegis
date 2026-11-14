import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/alert_model.dart';
import '../models/contact_model.dart';
import '../models/hazard_report_model.dart';
import '../models/trip_model.dart';
import '../models/user_model.dart';

/// Service for seeding and clearing demo data for testing and demonstration purposes.
class SeedService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  /// Singleton instance of [SeedService].
  static final SeedService instance = SeedService();

  SeedService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Seeds realistic sample profile, contacts, trips, alert, and hazard reports
  /// in a single atomic batch using fixed `demo_` document IDs.
  Future<void> seedDemoData() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('Cannot seed demo data: No user is currently signed in.');
    }
    final uid = currentUser.uid;
    final now = DateTime.now();

    final batch = _db.batch();

    // 1. Seed User Profile
    final userRef = _db.collection('users').doc(uid);
    final userModel = UserModel(
      userId: uid,
      name: 'Elena Vance (Demo)',
      phone: '+94771234567',
      bloodType: 'O+',
      allergies: 'Penicillin, Peanuts',
      emergencyNote: 'Asthma patient. Keeps inhaler in primary bag pocket. Contact emergency response immediately on SOS.',
    );
    batch.set(userRef, userModel.toMap(), SetOptions(merge: true));

    // 2. Seed 2 Trusted Contacts
    final contact1Ref = userRef.collection('contacts').doc('demo_contact_1');
    final contact1 = ContactModel(
      id: 'demo_contact_1',
      name: 'Sarah Vance',
      phone: '+94779876543',
      relation: 'Mother',
      isPrimary: true,
    );
    batch.set(contact1Ref, contact1.toMap(), SetOptions(merge: true));

    final contact2Ref = userRef.collection('contacts').doc('demo_contact_2');
    final contact2 = ContactModel(
      id: 'demo_contact_2',
      name: 'Dr. Mark Vance',
      phone: '+94771122334',
      relation: 'Doctor',
      isPrimary: false,
    );
    batch.set(contact2Ref, contact2.toMap(), SetOptions(merge: true));

    // 3. Seed 3 Trips around Colombo
    // Trip 1: Completed
    final trip1Ref = _db.collection('trips').doc('demo_trip_1');
    final trip1 = TripModel(
      tripId: 'demo_trip_1',
      userId: uid,
      status: TripStatus.completed,
      startLocation: {'lat': 6.9271, 'lng': 79.8612},
      currentLocation: {'lat': 6.9344, 'lng': 79.8451},
      destination: {'lat': 6.9344, 'lng': 79.8451},
      startedAt: now.subtract(const Duration(hours: 3)),
      endedAt: now.subtract(const Duration(hours: 2, minutes: 20)),
    );
    batch.set(trip1Ref, trip1.toMap(), SetOptions(merge: true));

    // Trip 2: Completed
    final trip2Ref = _db.collection('trips').doc('demo_trip_2');
    final trip2 = TripModel(
      tripId: 'demo_trip_2',
      userId: uid,
      status: TripStatus.completed,
      startLocation: {'lat': 6.9100, 'lng': 79.8800},
      currentLocation: {'lat': 6.9200, 'lng': 79.8700},
      destination: {'lat': 6.9200, 'lng': 79.8700},
      startedAt: now.subtract(const Duration(days: 1, hours: 2)),
      endedAt: now.subtract(const Duration(days: 1, hours: 1)),
    );
    batch.set(trip2Ref, trip2.toMap(), SetOptions(merge: true));

    // Trip 3: Alerted
    final trip3Ref = _db.collection('trips').doc('demo_trip_3');
    final trip3 = TripModel(
      tripId: 'demo_trip_3',
      userId: uid,
      status: TripStatus.alerted,
      startLocation: {'lat': 6.9280, 'lng': 79.8620},
      currentLocation: {'lat': 6.9310, 'lng': 79.8650},
      destination: {'lat': 6.9400, 'lng': 79.8500},
      startedAt: now.subtract(const Duration(minutes: 45)),
    );
    batch.set(trip3Ref, trip3.toMap(), SetOptions(merge: true));

    // 4. Seed 1 Unresolved Fall Alert linked to Trip 3
    final alert1Ref = _db.collection('alerts').doc('demo_alert_1');
    final alert1 = AlertModel(
      alertId: 'demo_alert_1',
      tripId: 'demo_trip_3',
      userId: uid,
      type: AlertType.fallDetected,
      location: {'lat': 6.9310, 'lng': 79.8650},
      triggeredAt: now.subtract(const Duration(minutes: 30)),
      resolved: false,
    );
    batch.set(alert1Ref, alert1.toMap(), SetOptions(merge: true));

    // 5. Seed 4 Hazard Reports around Colombo
    final hazard1Ref = _db.collection('hazard_reports').doc('demo_hazard_1');
    final hazard1 = HazardReportModel(
      id: 'demo_hazard_1',
      category: HazardCategory.poorLighting.key,
      description: 'Dark unlit street section',
      lat: 6.9295,
      lng: 79.8635,
      geohash: 'tc3m2x9',
      reportedBy: uid,
      confirmCount: 3,
      reportedAt: now.subtract(const Duration(days: 2)),
    );
    batch.set(hazard1Ref, hazard1.toMap(), SetOptions(merge: true));

    final hazard2Ref = _db.collection('hazard_reports').doc('demo_hazard_2');
    final hazard2 = HazardReportModel(
      id: 'demo_hazard_2',
      category: HazardCategory.noSidewalk.key,
      description: 'Broken pavement and narrow road',
      lat: 6.9250,
      lng: 79.8660,
      geohash: 'tc3m2x0',
      reportedBy: uid,
      confirmCount: 5,
      reportedAt: now.subtract(const Duration(days: 1)),
    );
    batch.set(hazard2Ref, hazard2.toMap(), SetOptions(merge: true));

    final hazard3Ref = _db.collection('hazard_reports').doc('demo_hazard_3');
    final hazard3 = HazardReportModel(
      id: 'demo_hazard_3',
      category: HazardCategory.unsafeArea.key,
      description: 'Isolated dimly lit alley',
      lat: 6.9320,
      lng: 79.8600,
      geohash: 'tc3m2y1',
      reportedBy: uid,
      confirmCount: 2,
      reportedAt: now.subtract(const Duration(hours: 12)),
    );
    batch.set(hazard3Ref, hazard3.toMap(), SetOptions(merge: true));

    final hazard4Ref = _db.collection('hazard_reports').doc('demo_hazard_4');
    final hazard4 = HazardReportModel(
      id: 'demo_hazard_4',
      category: HazardCategory.other.key,
      description: 'Construction debris blocking pathway',
      lat: 6.9350,
      lng: 79.8550,
      geohash: 'tc3m2z2',
      reportedBy: uid,
      confirmCount: 1,
      reportedAt: now.subtract(const Duration(hours: 4)),
    );
    batch.set(hazard4Ref, hazard4.toMap(), SetOptions(merge: true));

    // Commit all seed operations atomically
    await batch.commit();
  }

  /// Removes seeded demo contacts, trips, and alert.
  /// 
  /// Note: Document deletions on `hazard_reports` are denied by Firestore security rules,
  /// so hazard report demo docs remain or can be reset in local Firestore emulator.
  Future<void> clearDemoData() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    final uid = currentUser.uid;

    final batch = _db.batch();

    // Delete contacts
    batch.delete(_db.collection('users').doc(uid).collection('contacts').doc('demo_contact_1'));
    batch.delete(_db.collection('users').doc(uid).collection('contacts').doc('demo_contact_2'));

    // Delete trips
    batch.delete(_db.collection('trips').doc('demo_trip_1'));
    batch.delete(_db.collection('trips').doc('demo_trip_2'));
    batch.delete(_db.collection('trips').doc('demo_trip_3'));

    // Delete alert
    batch.delete(_db.collection('alerts').doc('demo_alert_1'));

    await batch.commit();
  }
}
