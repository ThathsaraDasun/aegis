import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'geo_utils.dart';
import 'http_json.dart';
import 'route_models.dart';

/// Finds two walking route options between two points using free OSRM
/// servers (no API key). Falls back to a forced detour when the router only
/// returns one route, and to synthetic demo routes when offline.
class RoutePlannerService {
  /// FOSSGIS foot-routing server (real pedestrian profile).
  static const _footBase = 'https://routing.openstreetmap.de/routed-foot/route/v1/driving';

  /// Public OSRM demo (car profile) – last-resort fallback.
  static const _osrmDemoBase = 'https://router.project-osrm.org/route/v1/foot';

  /// Average walking speed used when the server profile isn't pedestrian.
  static const double walkingSpeedMps = 1.35;

  /// Returns exactly two routes (Route A, Route B) or throws if the routers
  /// cannot be reached – callers may then use [demoRoutes].
  Future<List<CandidateRoute>> findTwoRoutes(LatLng from, LatLng to) async {
    var routes = await _query(from, to, alternatives: true);

    if (routes.length < 2) {
      final via = _detourPoint(from, to);
      final detour = await _query(from, to, via: via, alternatives: false);
      if (detour.isNotEmpty) routes = [...routes, detour.first];
    }
    if (routes.isEmpty) {
      throw StateError('No walking route found between these points.');
    }
    if (routes.length == 1) {
      // Router returned a single path even with a via point – mirror detour.
      final via = _detourPoint(from, to, side: -1);
      routes = [routes.first, _straightVia(from, via, to, isDemo: false)];
    }

    final two = routes.take(2).toList();
    return [
      _relabel(two[0], 'Route A'),
      _relabel(two[1], 'Route B'),
    ];
  }

  Future<List<CandidateRoute>> _query(
    LatLng from,
    LatLng to, {
    LatLng? via,
    required bool alternatives,
  }) async {
    final pts = [from, if (via != null) via, to];
    final coords = pts
        .map((p) => '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}')
        .join(';');
    final query = 'alternatives=${alternatives ? 'true' : 'false'}'
        '&overview=full&geometries=geojson&steps=false';

    for (final base in [_footBase, _osrmDemoBase]) {
      try {
        final json = await HttpJson.get(Uri.parse('$base/$coords?$query'));
        if (json['code'] != 'Ok') continue;
        final isFoot = base == _footBase;
        final list = (json['routes'] as List? ?? const []);
        return list.map((r) => _parseRoute(r as Map<String, dynamic>, isFoot)).toList();
      } catch (_) {
        // try next server
      }
    }
    return const [];
  }

  CandidateRoute _parseRoute(Map<String, dynamic> r, bool isFoot) {
    final coords = ((r['geometry'] as Map)['coordinates'] as List)
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
    final distance = (r['distance'] as num).toDouble();
    final duration = isFoot ? (r['duration'] as num).toDouble() : distance / walkingSpeedMps;
    return CandidateRoute(label: '', points: coords, distanceM: distance, durationS: duration);
  }

  CandidateRoute _relabel(CandidateRoute r, String label) => CandidateRoute(
        label: label,
        points: r.points,
        distanceM: r.distanceM,
        durationS: r.durationS,
        isDemo: r.isDemo,
      );

  /// A point beside the midpoint, perpendicular to the straight line,
  /// ~30% of the trip length away – forces the router onto other streets.
  LatLng _detourPoint(LatLng from, LatLng to, {int side = 1}) {
    final mid = LatLng((from.latitude + to.latitude) / 2, (from.longitude + to.longitude) / 2);
    final dist = GeoUtils.distanceM(from, to);
    final dNorth = GeoUtils.distanceM(from, LatLng(to.latitude, from.longitude)) *
        (to.latitude >= from.latitude ? 1 : -1);
    final dEast = GeoUtils.distanceM(from, LatLng(from.latitude, to.longitude)) *
        (to.longitude >= from.longitude ? 1 : -1);
    final len = math.max(1.0, math.sqrt(dNorth * dNorth + dEast * dEast));
    final shift = math.max(80.0, dist * 0.3) * side;
    // Perpendicular vector (-east, north).
    return GeoUtils.offset(mid, northM: -dEast / len * shift, eastM: dNorth / len * shift);
  }

  CandidateRoute _straightVia(LatLng from, LatLng via, LatLng to, {required bool isDemo}) {
    final pts = <LatLng>[];
    void seg(LatLng a, LatLng b) {
      const steps = 12;
      for (var i = 0; i < steps; i++) {
        final t = i / steps;
        pts.add(LatLng(a.latitude + (b.latitude - a.latitude) * t,
            a.longitude + (b.longitude - a.longitude) * t));
      }
    }

    seg(from, via);
    seg(via, to);
    pts.add(to);
    final d = GeoUtils.pathLengthM(pts);
    return CandidateRoute(
      label: '',
      points: pts,
      distanceM: d,
      durationS: d / walkingSpeedMps,
      isDemo: isDemo,
    );
  }

  /// Offline demo: a direct route and a detour between [from] and [to].
  List<CandidateRoute> demoRoutes(LatLng from, LatLng to) {
    final direct = _straightVia(from, _detourPoint(from, to, side: 1), to, isDemo: true);
    final detour = _straightVia(from, _detourPoint(from, to, side: -1), to, isDemo: true);
    return [_relabel(direct, 'Route A'), _relabel(detour, 'Route B')];
  }
}
