import 'package:aegis/models/hazard_report_model.dart';
import 'package:aegis/models/medical_profile_model.dart';
import 'package:aegis/services/contacts_service.dart';
import 'package:aegis/services/route/geo_utils.dart';
import 'package:aegis/services/route/osm_lighting_service.dart';
import 'package:aegis/services/route/route_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('GeoUtils', () {
    test('geohash matches known value', () {
      // Reference value from geohash.org for (57.64911, 10.40744).
      expect(GeoUtils.encodeGeohash(57.64911, 10.40744, precision: 11), 'u4pruydqqvj');
    });

    test('distance between two Colombo points is ~850 m', () {
      final d = GeoUtils.distanceM(LatLng(6.9344, 79.8428), LatLng(6.9271, 79.8450));
      expect(d, inInclusiveRange(700, 1000));
    });

    test('point on a path has ~0 distance', () {
      final path = [LatLng(6.92, 79.86), LatLng(6.93, 79.86)];
      expect(GeoUtils.distanceToPathM(LatLng(6.925, 79.86), path), lessThan(1));
    });

    test('geohash prefixes cover nearby points', () {
      final center = LatLng(6.9271, 79.8612);
      final prefixes = GeoUtils.geohashPrefixesForRadius(center, 500);
      final near = GeoUtils.offset(center, northM: 450, eastM: -300);
      final hash = GeoUtils.encodeGeohash(near.latitude, near.longitude);
      expect(prefixes.any(hash.startsWith), isTrue);
    });
  });

  group('RouteSafetyScorer', () {
    final route = [LatLng(6.9271, 79.8612), LatLng(6.9310, 79.8650)];
    final onRoute = HazardReportModel(
      id: 'h1',
      category: 'past_incident',
      lat: 6.9290,
      lng: 79.8631,
      reportedAt: DateTime(2026, 11, 1),
    );
    final farAway = HazardReportModel(
      id: 'h2',
      category: 'poor_lighting',
      lat: 6.95,
      lng: 79.90,
      reportedAt: DateTime(2026, 11, 1),
    );

    test('hazard near the route lowers the score, far one is ignored', () {
      const lit = LightingSummary(litWays: 8, unlitWays: 2, unknownWays: 5);
      final clean = RouteSafetyScorer.score(
          route: route, hazards: [farAway], lighting: lit, now: DateTime(2026, 11, 13));
      final risky = RouteSafetyScorer.score(
          route: route, hazards: [onRoute, farAway], lighting: lit, now: DateTime(2026, 11, 13));

      expect(clean.hazards, isEmpty);
      expect(clean.score, 92); // 0.6*100 + 0.4*80
      expect(risky.hazards.length, 1);
      expect(risky.score, lessThan(clean.score));
    });

    test('missing lighting data is neutral (50)', () {
      final s = RouteSafetyScorer.score(
          route: route, hazards: const [], lighting: const LightingSummary.unavailable());
      expect(s.lightingScore, 50);
      expect(s.explanation, isNotEmpty);
    });

    test('confirmations increase weight, old reports decay', () {
      final now = DateTime(2026, 11, 13);
      final fresh = HazardReportModel(
          id: 'a', category: 'unsafe_area', lat: 0, lng: 0, reportedAt: now, confirmCount: 3);
      final old = HazardReportModel(
          id: 'b', category: 'unsafe_area', lat: 0, lng: 0,
          reportedAt: now.subtract(const Duration(days: 60)));
      expect(RouteSafetyScorer.hazardWeight(fresh, now: now), closeTo(2.25, 1e-9));
      expect(RouteSafetyScorer.hazardWeight(old, now: now), closeTo(0.75, 1e-9));
    });
  });

  group('OSM lighting parser', () {
    test('counts lit / unlit / unknown ways', () {
      final summary = OsmLightingService.parseResponse({
        'elements': [
          {'tags': {'highway': 'residential', 'lit': 'yes'}},
          {'tags': {'highway': 'footway', 'lit': 'no'}},
          {'tags': {'highway': 'service'}},
          {'tags': {'highway': 'primary', 'lit': '24/7'}},
        ],
      });
      expect(summary.litWays, 2);
      expect(summary.unlitWays, 1);
      expect(summary.unknownWays, 1);
      expect(summary.litRatio, closeTo(2 / 3, 1e-9));
    });
  });

  group('Contacts & medical helpers', () {
    test('Sri Lankan local numbers become +94', () {
      expect(ContactsService.normalizePhone('077 123-4567'), '+94771234567');
      expect(ContactsService.validatePhone('abc'), isNotNull);
      expect(ContactsService.validatePhone('+94771234567'), isNull);
    });

    test('legacy hazard labels map onto schema keys', () {
      expect(HazardCategory.normalizeKey('Broken Light'), 'poor_lighting');
      expect(HazardCategory.normalizeKey('Suspicious Act'), 'unsafe_area');
      expect(HazardCategory.normalizeKey(null), 'other');
    });

    test('medical SOS summary', () {
      const p = MedicalProfile(bloodType: 'O+', allergies: 'Penicillin');
      expect(p.toSosSummary(), 'Blood O+ | Allergies: Penicillin');
      expect(MedicalProfile.empty.isEmpty, isTrue);
    });
  });
}
