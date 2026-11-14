import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Pure-Dart geo helpers used by the Safe Route layer (no Firebase / Flutter
/// imports, so everything here is unit-testable).
class GeoUtils {
  GeoUtils._();

  static const double earthRadiusM = 6371000.0;
  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  // ---------------------------------------------------------------------------
  // Distance
  // ---------------------------------------------------------------------------

  /// Great-circle distance in metres.
  static double distanceM(LatLng a, LatLng b) {
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(a.latitude)) *
            math.cos(_rad(b.latitude)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * earthRadiusM * math.asin(math.min(1.0, math.sqrt(h)));
  }

  /// Total length of a polyline in metres.
  static double pathLengthM(List<LatLng> path) {
    double total = 0;
    for (var i = 1; i < path.length; i++) {
      total += distanceM(path[i - 1], path[i]);
    }
    return total;
  }

  /// Shortest distance (metres) from [p] to the polyline [path].
  /// Uses a local equirectangular projection – accurate for walking distances.
  static double distanceToPathM(LatLng p, List<LatLng> path) {
    if (path.isEmpty) return double.infinity;
    if (path.length == 1) return distanceM(p, path.first);

    final cosLat = math.cos(_rad(p.latitude));
    double toX(LatLng q) => _rad(q.longitude - p.longitude) * cosLat * earthRadiusM;
    double toY(LatLng q) => _rad(q.latitude - p.latitude) * earthRadiusM;

    double best = double.infinity;
    for (var i = 1; i < path.length; i++) {
      final ax = toX(path[i - 1]), ay = toY(path[i - 1]);
      final bx = toX(path[i]), by = toY(path[i]);
      final dx = bx - ax, dy = by - ay;
      final len2 = dx * dx + dy * dy;
      double t = len2 == 0 ? 0 : -(ax * dx + ay * dy) / len2;
      t = t.clamp(0.0, 1.0);
      final cx = ax + t * dx, cy = ay + t * dy;
      final d = math.sqrt(cx * cx + cy * cy);
      if (d < best) best = d;
    }
    return best;
  }

  /// Returns at most [maxPoints] points evenly sampled along [path]
  /// (always keeps first and last). Keeps Overpass queries small.
  static List<LatLng> samplePath(List<LatLng> path, int maxPoints) {
    if (path.length <= maxPoints) return List.of(path);
    final step = (path.length - 1) / (maxPoints - 1);
    return List.generate(
      maxPoints,
      (i) => path[(i * step).round().clamp(0, path.length - 1)],
    );
  }

  /// Centre and radius (metres) of a circle that covers every point.
  static ({LatLng center, double radiusM}) boundingCircle(List<LatLng> pts) {
    var minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    for (final p in pts) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    double radius = 0;
    for (final p in pts) {
      radius = math.max(radius, distanceM(center, p));
    }
    return (center: center, radiusM: radius);
  }

  /// Moves [origin] by [northM] / [eastM] metres.
  static LatLng offset(LatLng origin, {double northM = 0, double eastM = 0}) {
    final dLat = northM / earthRadiusM;
    final dLng = eastM / (earthRadiusM * math.cos(_rad(origin.latitude)));
    return LatLng(
      origin.latitude + dLat * 180 / math.pi,
      origin.longitude + dLng * 180 / math.pi,
    );
  }

  // ---------------------------------------------------------------------------
  // Geohash (for Firestore geoqueries)
  // ---------------------------------------------------------------------------

  /// Standard base-32 geohash.
  static String encodeGeohash(double lat, double lng, {int precision = 9}) {
    var latMin = -90.0, latMax = 90.0, lngMin = -180.0, lngMax = 180.0;
    final buffer = StringBuffer();
    var bit = 0, ch = 0;
    var evenBit = true;

    while (buffer.length < precision) {
      if (evenBit) {
        final mid = (lngMin + lngMax) / 2;
        if (lng >= mid) {
          ch = (ch << 1) | 1;
          lngMin = mid;
        } else {
          ch = ch << 1;
          lngMax = mid;
        }
      } else {
        final mid = (latMin + latMax) / 2;
        if (lat >= mid) {
          ch = (ch << 1) | 1;
          latMin = mid;
        } else {
          ch = ch << 1;
          latMax = mid;
        }
      }
      evenBit = !evenBit;
      if (++bit == 5) {
        buffer.write(_base32[ch]);
        bit = 0;
        ch = 0;
      }
    }
    return buffer.toString();
  }

  /// Geohash precision whose cells are at least [radiusM] in both directions.
  static int precisionForRadius(double radiusM) {
    if (radiusM <= 600) return 6; // ~1.2km x 0.6km cells
    if (radiusM <= 4800) return 5; // ~4.9km x 4.9km
    if (radiusM <= 19000) return 4; // ~39km x 19.5km
    if (radiusM <= 150000) return 3;
    return 2;
  }

  /// Geohash prefixes whose cells together cover a circle of [radiusM]
  /// around [center]. Query each with `orderBy('geohash').startAt([h])
  /// .endAt(['$h~'])`, then filter results by real distance.
  ///
  /// Because the cell size is >= radius, sampling the centre plus the 8
  /// points at ±radius is enough to hit every cell overlapping the circle.
  static List<String> geohashPrefixesForRadius(LatLng center, double radiusM) {
    final precision = precisionForRadius(radiusM);
    final hashes = <String>{};
    for (final n in [-radiusM, 0.0, radiusM]) {
      for (final e in [-radiusM, 0.0, radiusM]) {
        final p = offset(center, northM: n, eastM: e);
        final lat = p.latitude.clamp(-90.0, 90.0);
        var lng = p.longitude;
        if (lng > 180) lng -= 360;
        if (lng < -180) lng += 360;
        hashes.add(encodeGeohash(lat, lng, precision: precision));
      }
    }
    return hashes.toList()..sort();
  }

  static double _rad(double deg) => deg * math.pi / 180.0;
}
