import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'geo_utils.dart';
import 'http_json.dart';
import 'route_models.dart';

/// Reads OpenStreetMap `lit=*` tags for streets along a route via the
/// Overpass API (https://wiki.openstreetmap.org/wiki/Key:lit).
class OsmLightingService {
  static final List<Uri> _endpoints = [
    Uri.parse('https://overpass.private.coffee/api/interpreter'),
    Uri.parse('https://overpass-api.de/api/interpreter'),
  ];
  final Map<Uri, DateTime> _retryAfter = {};

  /// Search radius around the route line, in metres.
  static const int corridorM = 25;

  static const _litValues = {
    'yes',
    '24/7',
    'automatic',
    'limited',
    'interval',
    'sunset-sunrise',
  };
  static const _unlitValues = {'no', 'disused'};

  final Map<String, LightingSummary> _cache = {};

  /// Builds the Overpass QL query. `around` with several coordinates treats
  /// them as a polyline, so this returns the streets the route runs along.
  static String buildQuery(List<LatLng> route) {
    final pts = GeoUtils.samplePath(route, 40);
    final coords = pts
        .map(
          (p) =>
              '${p.latitude.toStringAsFixed(6)},${p.longitude.toStringAsFixed(6)}',
        )
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
    return LightingSummary(
      litWays: lit,
      unlitWays: unlit,
      unknownWays: unknown,
    );
  }

  /// Never throws – returns [LightingSummary.unavailable] when offline.
  Future<LightingSummary> lightingForRoute(List<LatLng> route) async {
    return (await lightingForRoutes([route])).single;
  }

  /// One request for the comparison, rather than competing parallel queries.
  /// Count records separate each route's ways without mixing their ratings.
  Future<List<LightingSummary>> lightingForRoutes(
    List<List<LatLng>> routes,
  ) async {
    final results = List<LightingSummary>.filled(
      routes.length,
      const LightingSummary.unavailable(),
    );
    final pending = <int>[];
    for (var i = 0; i < routes.length; i++) {
      if (routes[i].length < 2) continue;
      final cached = _cache[buildQuery(routes[i])];
      if (cached != null) {
        results[i] = cached;
      } else {
        pending.add(i);
      }
    }
    if (pending.isEmpty) return results;
    final query = StringBuffer('[out:json][timeout:10];');
    for (final i in pending) {
      final single = buildQuery(routes[i]);
      query.write(
        single.substring(single.indexOf('way('), single.indexOf('out tags;')),
      );
      query.write('out tags;out count;');
    }

    for (final endpoint in _endpoints) {
      if (_retryAfter[endpoint]?.isAfter(DateTime.now()) ?? false) continue;
      try {
        final json = await HttpJson.postForm(endpoint, {
          'data': query.toString(),
        }, timeout: const Duration(seconds: 12));
        // Overpass can return HTTP 200 with a runtime-error remark and partial data.
        if (json['remark'] != null || json['elements'] is! List) continue;
        final summaries = <LightingSummary>[];
        final ways = <dynamic>[];
        for (final element in json['elements'] as List) {
          if (element is Map && element['type'] == 'count') {
            summaries.add(parseResponse({'elements': List.of(ways)}));
            ways.clear();
          } else {
            ways.add(element);
          }
        }
        if (summaries.length != pending.length || ways.isNotEmpty) continue;
        for (var n = 0; n < pending.length; n++) {
          final i = pending[n];
          results[i] = summaries[n];
          _cache[buildQuery(routes[i])] = summaries[n];
        }
        return results;
      } catch (error) {
        // Do not log query coordinates or personal data.
        debugPrint(
          'Lighting lookup failed on ${endpoint.host}: ${error.runtimeType}',
        );
        _retryAfter[endpoint] = DateTime.now().add(const Duration(seconds: 30));
      }
    }
    return results;
  }
}
