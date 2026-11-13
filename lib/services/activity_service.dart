import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import '../models/alert_model.dart';
import '../models/trip_model.dart';
import '../models/user_model.dart';

/// One entry in the combined Activity feed: either a trip or an alert.
class ActivityItem {
  final TripModel? trip;
  final AlertModel? alert;

  const ActivityItem.trip(TripModel this.trip) : alert = null;
  const ActivityItem.alert(AlertModel this.alert) : trip = null;

  DateTime get timestamp => trip?.startedAt ?? alert!.triggeredAt;
}

/// Firestore streams backing the secondary views
/// (Trip History, Activity feed, Profile).
///
/// Screens call these documented methods instead of the Firestore SDK.
class ActivityService {
  ActivityService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Live stream of the user's trips, most recent first.
  ///
  /// Sorting happens on the client so no composite Firestore index is needed.
  Stream<List<TripModel>> watchTrips(String userId) {
    return _db
        .collection('trips')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
      final trips = snap.docs.map(TripModel.fromFirestore).toList();
      trips.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      return trips;
    });
  }

  /// Live stream of the user's SOS / fall alerts, most recent first.
  Stream<List<AlertModel>> watchAlerts(String userId) {
    return _db
        .collection('alerts')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
      final alerts = snap.docs.map(AlertModel.fromFirestore).toList();
      alerts.sort((a, b) => b.triggeredAt.compareTo(a.triggeredAt));
      return alerts;
    });
  }

  /// Trips and alerts merged into one chronological feed (most recent first).
  ///
  /// [CombineLatestStream] keeps the latest snapshot of both collections, so
  /// the whole list is re-sorted whenever either one changes.
  Stream<List<ActivityItem>> watchActivity(String userId) {
    return CombineLatestStream.combine2(
      watchTrips(userId),
      watchAlerts(userId),
      (List<TripModel> trips, List<AlertModel> alerts) {
        final items = [
          ...trips.map(ActivityItem.trip),
          ...alerts.map(ActivityItem.alert),
        ];
        items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return items;
      },
    );
  }

  /// Alerts raised during a single trip.
  Stream<List<AlertModel>> watchAlertsForTrip(String userId, String tripId) {
    return watchAlerts(userId)
        .map((alerts) => alerts.where((a) => a.tripId == tripId).toList());
  }

  /// Live stream of the user profile document (null if it does not exist yet).
  Stream<UserModel?> watchUser(String userId) {
    return _db.collection('users').doc(userId).snapshots().map(
          (doc) => doc.exists ? UserModel.fromFirestore(doc) : null,
        );
  }

  /// Creates or updates the user profile document.
  Future<void> saveUser(UserModel user) {
    return _db
        .collection('users')
        .doc(user.userId)
        .set(user.toFirestore(), SetOptions(merge: true));
  }

  /// Marks an alert as resolved (the user confirmed they are safe).
  Future<void> resolveAlert(String alertDocId) {
    return _db.collection('alerts').doc(alertDocId).update({'resolved': true});
  }
}
