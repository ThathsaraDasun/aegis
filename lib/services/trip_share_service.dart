import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Live location sharing for a Safe Walk trip.
///
/// When a trip starts, [start] creates a private `trip_shares/{token}`
/// document (a random 256-bit token is the only key) and returns an https
/// link that guardians open in any browser. While the trip runs, the walker's
/// position is written about every 15 seconds — also with the screen locked,
/// using an Android foreground-service notification. [stopForTrip] revokes the
/// link when the trip ends. Links also expire on their own after [maxAge].
///
/// This is separate from SOS sharing (`live_shares`), so SOS behaviour is
/// unchanged.
class TripShareService {
  TripShareService._();
  static final TripShareService instance = TripShareService._();

  /// Guardian web page (Firebase Hosting, `sos-viewer/trip/`).
  static const String viewerBase = 'https://aegis-45002.web.app/trip/';

  /// A trip auto-ends after 90 minutes; the link outlives it a little in case
  /// the app is closed, then expires (rules allow at most 12 hours).
  static const Duration maxAge = Duration(hours: 4);

  static const Duration _uploadEvery = Duration(seconds: 15);
  static const String _prefToken = 'trip_share_token';
  static const String _prefTrip = 'trip_share_trip';
  static const String _prefOwner = 'trip_share_owner';

  StreamSubscription<Position>? _positions;
  String? _token;
  String? _tripId;
  DateTime _lastUpload = DateTime.fromMillisecondsSinceEpoch(0);
  bool _uploading = false;

  /// Whether sharing can run here (Android app with Firebase initialised).
  static bool get supported =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      Firebase.apps.isNotEmpty;

  /// The guardian link for [token].
  static String linkFor(String token) => '$viewerBase#$token';

  /// A new random 64-character hex token.
  static String newToken([Random? random]) {
    final r = random ?? Random.secure();
    return List.generate(
      32,
      (_) => r.nextInt(256),
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// True while this trip's location is being shared.
  bool isSharing(String tripId) => _tripId == tripId && _token != null;

  /// The current guardian link for [tripId], if it is being shared.
  String? linkForTrip(String tripId) =>
      isSharing(tripId) ? linkFor(_token!) : null;

  /// Starts sharing [tripId]. Returns the guardian link, or null if sharing
  /// could not start (offline, viewer not deployed, not signed in…). A null
  /// result never blocks the trip itself.
  Future<String?> start({
    required String tripId,
    required double lat,
    required double lng,
    double? accuracy,
    DateTime? fixTime,
    required Map<String, double> destination,
    String? destinationName,
  }) async {
    if (!supported) return null;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    if (isSharing(tripId)) return linkForTrip(tripId);
    await stopCurrent();

    // Never send guardians a link before the viewer page is deployed.
    if (!await _viewerReady()) return null;

    final token = newToken();
    final hasFix =
        accuracy != null &&
        accuracy >= 0 &&
        accuracy <= 100 &&
        fixTime != null &&
        DateTime.now().difference(fixTime) < const Duration(minutes: 2);
    final name = destinationName?.trim();
    try {
      await FirebaseFirestore.instance
          .collection('trip_shares')
          .doc(token)
          .set({
            'ownerUid': uid,
            'tripId': tripId,
            'active': true,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'expiresAt': Timestamp.fromDate(DateTime.now().add(maxAge)),
            'lat': hasFix ? lat : null,
            'lng': hasFix ? lng : null,
            'accuracy': hasFix ? accuracy : null,
            'fixAt': hasFix ? Timestamp.fromDate(fixTime) : null,
            'destLat': destination['lat'],
            'destLng': destination['lng'],
            'destName': (name == null || name.isEmpty)
                ? null
                : (name.length > 120 ? name.substring(0, 120) : name),
          })
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      return null;
    }

    _token = token;
    _tripId = tripId;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefToken, token);
      await prefs.setString(_prefTrip, tripId);
      await prefs.setString(_prefOwner, uid);
    } catch (_) {}
    _listen();
    return linkFor(token);
  }

  /// Continues sharing [tripId] after the app was restarted during a trip.
  Future<void> resume(String tripId) async {
    if (!supported || isSharing(tripId)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_prefTrip) != tripId ||
          prefs.getString(_prefOwner) !=
              FirebaseAuth.instance.currentUser?.uid) {
        return;
      }
      final token = prefs.getString(_prefToken);
      if (token == null) return;
      _token = token;
      _tripId = tripId;
      _listen();
    } catch (_) {}
  }

  /// Stops sharing [tripId] and revokes its link (call when the trip ends).
  Future<void> stopForTrip(String tripId) async {
    if (_tripId == tripId || _tripId == null) await stopCurrent();
  }

  /// Stops any trip sharing (also a link left by a previous app session).
  Future<void> stopCurrent() async {
    await _positions?.cancel();
    _positions = null;
    var token = _token;
    _token = null;
    _tripId = null;
    if (!supported) return;
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      token ??= prefs.getString(_prefToken);
    } catch (_) {}
    if (token == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('trip_shares')
          .doc(token)
          .update({'active': false})
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Offline: the revoke stays queued in Firestore and syncs later; the
      // link also expires on its own.
    }
    try {
      await prefs?.remove(_prefToken);
      await prefs?.remove(_prefTrip);
      await prefs?.remove(_prefOwner);
    } catch (_) {}
  }

  void _listen() {
    _positions?.cancel();
    _positions = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        intervalDuration: _uploadEvery,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Sharing your Safe Walk',
          notificationText:
              'Your guardians can follow your location until you end the trip.',
          notificationChannelName: 'Trip location sharing',
          enableWakeLock: true,
          setOngoing: true,
        ),
      ),
    ).listen(_upload, onError: (_) {});
  }

  Future<void> _upload(Position p) async {
    final token = _token;
    if (token == null || _uploading) return;
    if (DateTime.now().difference(_lastUpload) < _uploadEvery) return;
    if (!p.latitude.isFinite || !p.longitude.isFinite) return;
    if (p.accuracy < 0 || p.accuracy > 100) return;
    _uploading = true;
    _lastUpload = DateTime.now();
    try {
      await FirebaseFirestore.instance
          .collection('trip_shares')
          .doc(token)
          .update({
            'lat': p.latitude,
            'lng': p.longitude,
            'accuracy': p.accuracy,
            'fixAt': Timestamp.fromDate(p.timestamp),
            'updatedAt': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // A missed update is fine: the next GPS fix tries again.
    } finally {
      _uploading = false;
    }
  }

  Future<bool> _viewerReady() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final request = await client
          .getUrl(Uri.parse('${viewerBase}ready.json'))
          .timeout(const Duration(seconds: 3));
      request.followRedirects = false;
      final response = await request.close().timeout(
        const Duration(seconds: 3),
      );
      if (response.statusCode != 200) return false;
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 3));
      return body.trim() == '{"version":1}';
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }
}
