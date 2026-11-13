import 'package:latlong2/latlong.dart';

import 'geo_utils.dart';
import 'http_json.dart';
import 'route_models.dart';

/// Reads OpenStreetMap `lit=*` tags for streets along a route via the
/// Overpass API (https://wiki.openstreetmap.org/wiki/Key:lit).
class OsmLightingService {
  static final List<Uri> _endpoints = [
    Uri.parse('https://overpass-api.de/api/interpreter'),
    Uri.parse('https://overpass.kumi.systems/api/interpreter'),
  ];

  /// Search radius around the route line, in metres.
  static const int corridorM = 25;

  static const _litValues = {'yes', '24/7', 'automatic', 'limited', 'interval', 'sunset-sunrise'};
  static const _unlitValues = {'no', 'disused'};

  final Map<String, LightingSummary> _cache = {};

  /// Builds the Overpass QL query. `around` with several coordinates treats
  /// them as a polyline, so this returns the streets the route runs along.
  static String buildQuery(List<LatLng> route) {
    final pts = GeoUtils.samplePath(route, 40);
    final coords = pts
        .map((p) => '${p.latitude.toStringAsFixed(6)},${p.longitude.toStringAsFixed(6)}')
        .join(',');
    return '[out:json][timeout:20];'
        'way(around:$corridorM,$coords)["highway"]'
        '["highway"!~"motorway|trunk|motorway_link|trunk_link|construction|proposed"];'
        'out tags;';
  }

  /// Counts lit / unlit / untagged ways in an Overpass JSON response.
  static LightingSummary parseResponse(Map<String, dynamic> json) {
    final elements = (json['elements'] as List?) ?? const [];
    var lit = 0, unlit = 0, unknown = 0;
    for (final e in elements) {
      final tags = (e is Map ? e['tags'] as Map? : null) ?? const {};
      final value = (tags['lit'] as String?)?.toLowerCase();
      if (value == null) {
        unknown++;
      } else if (_litValues.contains(value)) {
        lit++;
      } else if (_unlitValues.contains(value)) {
        unlit++;
      } else {
        unknown++;
      }
    }
    return LightingSummary(litWays: lit, unlitWays: unlit, unknownWays: unknown);
  }

  /// Never throws – returns [LightingSummary.unavailable] when offline.
  Future<LightingSummary> lightingForRoute(List<LatLng> route) async {
    if (route.length < 2) return const LightingSummary.unavailable();
    final query = buildQuery(route);
    final cached = _cache[query];
    if (cached != null) return cached;

    for (final endpoint in _endpoints) {
      try {
        final json = await HttpJson.postForm(endpoint, {'data': query});
        final summary = parseResponse(json);
        _cache[query] = summary;
        return summary;
      } catch (_) {
        // try next mirror
      }
    }
    return const LightingSummary.unavailable();
  }
}
