import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'package:rxdart/rxdart.dart';

import '../models/hazard_report_model.dart';
import 'route/geo_utils.dart';
import 'route/osm_lighting_service.dart';
import 'route/route_models.dart';

export 'route/route_models.dart';

/// Safe Route layer (Member 3): hazard reports + route safety scoring.
///
/// * Hazard reports → `hazard_reports` collection, geohash-indexed.
/// * Geoqueries → geohash prefix range queries + exact distance filter.
/// * Lighting → OpenStreetMap `lit` tags via Overpass ([OsmLightingService]).
/// * Scoring → [RouteSafetyScorer] (pure, unit-tested).
class RouteSafetyService {
  RouteSafetyService({FirebaseFirestore? firestore, OsmLightingService? lighting})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _lighting = lighting ?? OsmLightingService();

  final FirebaseFirestore _firestore;
  final OsmLightingService _lighting;

  static const String collection = 'hazard_reports';

  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection(collection);

  // ---------------------------------------------------------------------------
  // Hazard reports
  // ---------------------------------------------------------------------------

  /// Saves a new hazard pin and returns its document id. Geohash, reporter
  /// and server timestamp are filled in automatically.
  Future<String> reportHazard(HazardReportModel report) async {
    final data = HazardReportModel(
      id: '',
      category: HazardCategory.normalizeKey(report.category),
      description: report.description,
      lat: report.lat,
      lng: report.lng,
      geohash: GeoUtils.encodeGeohash(report.lat, report.lng),
      reportedBy: FirebaseAuth.instance.currentUser?.uid ?? report.reportedBy,
      confirmCount: report.confirmCount < 1 ? 1 : report.confirmCount,
      reportedAt: report.reportedAt,
    ).toMap(useServerTimestamp: true);

    final ref = await _reports.add(data);
    try {
      await ref.update({'reportId': ref.id});
    } catch (_) {
      // Optional field – ignore if security rules don't allow updates.
    }
    return ref.id;
  }

  /// "I saw this too" – bumps the confirmation counter.
  Future<void> confirmHazard(String reportId) {
    return _reports.doc(reportId).update({'confirmCount': FieldValue.increment(1)});
  }

  /// Lets the reporter remove their own pin.
  Future<void> deleteHazard(String reportId) => _reports.doc(reportId).delete();

  /// Live hazard reports within [radiusM] of [center], nearest first.
  ///
  /// Without a [center] this streams the latest 200 reports (legacy
  /// behaviour, used by older callers).
  Stream<List<HazardReportModel>> streamNearbyHazards({
    LatLng? center,
    double radiusM = 1500,
  }) {
    if (center == null) {
      return _reports
          .orderBy('reportedAt', descending: true)
          .limit(200)
          .snapshots()
          .map((s) => s.docs.map((d) => HazardReportModel.fromMap(d.id, d.data())).toList());
    }

    final streams = GeoUtils.geohashPrefixesForRadius(center, radiusM)
        .map((prefix) => _reports
            .orderBy('geohash')
            .startAt([prefix])
            .endAt(['$prefix~'])
            .snapshots()
            .map((s) => s.docs
                .map((d) => HazardReportModel.fromMap(d.id, d.data()))
                .toList()))
        .toList();

    return CombineLatestStream.list<List<HazardReportModel>>(streams)
        .map((lists) => _filterByDistance(lists.expand((l) => l), center, radiusM));
  }

  /// One-shot version of [streamNearbyHazards].
  Future<List<HazardReportModel>> fetchHazardsNear(LatLng center, double radiusM) async {
    final prefixes = GeoUtils.geohashPrefixesForRadius(center, radiusM);
    final snaps = await Future.wait(prefixes.map((prefix) => _reports
        .orderBy('geohash')
        .startAt([prefix])
        .endAt(['$prefix~'])
        .get()));
    final all = snaps.expand(
        (s) => s.docs.map((d) => HazardReportModel.fromMap(d.id, d.data())));
    return _filterByDistance(all, center, radiusM);
  }

  List<HazardReportModel> _filterByDistance(
      Iterable<HazardReportModel> reports, LatLng center, double radiusM) {
    final unique = <String, HazardReportModel>{};
    for (final r in reports) {
      unique[r.id] = r;
    }
    final within = unique.values
        .where((r) => GeoUtils.distanceM(center, LatLng(r.lat, r.lng)) <= radiusM)
        .toList()
      ..sort((a, b) => GeoUtils.distanceM(center, LatLng(a.lat, a.lng))
          .compareTo(GeoUtils.distanceM(center, LatLng(b.lat, b.lng))));
    return within;
  }

  // ---------------------------------------------------------------------------
  // Route scoring
  // ---------------------------------------------------------------------------

  /// Scores several routes. Hazards are fetched once for the whole area and
  /// lighting is fetched per route in parallel.
  Future<List<RouteSafetyScore>> scoreRoutes(List<CandidateRoute> routes) async {
    final allPoints = routes.expand((r) => r.points).toList();
    if (allPoints.isEmpty) return const [];

    final circle = GeoUtils.boundingCircle(allPoints);
    List<HazardReportModel> hazards;
    try {
      hazards = await fetchHazardsNear(
        circle.center,
        circle.radiusM + RouteSafetyScorer.hazardBufferM + 50,
      );
    } catch (_) {
      hazards = const []; // offline / not signed in – lighting still counts
    }

    final lighting = await Future.wait(
        routes.map((r) => r.isDemo
            ? Future.value(const LightingSummary.unavailable())
            : _lighting.lightingForRoute(r.points)));

    return [
      for (var i = 0; i < routes.length; i++)
        RouteSafetyScorer.score(
          route: routes[i].points,
          hazards: hazards,
          lighting: lighting[i],
        ),
    ];
  }

  /// Simple 0–100 score kept for backwards compatibility with the first
  /// version of the route screen.
  static double calculateSafetyScore({required int hazardCount, required double lightingRatio}) {
    double baseScore = 100.0;
    baseScore -= (hazardCount * 15.0);
    baseScore += (lightingRatio * 30.0);
    return baseScore.clamp(0.0, 100.0);
  }
}
