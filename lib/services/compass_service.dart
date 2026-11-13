import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

/// Magnetometer-based compass maths.
class CompassService {
  /// Weight of each new reading in the low-pass filter (0-1).
  static const double smoothing = 0.2;

  /// Streams the device heading in degrees (0-360, 0 = magnetic north,
  /// clockwise), smoothed to remove sensor jitter.
  ///
  /// Assumes the phone is held roughly flat, screen up.
  static Stream<double> get headingStream {
    double? last;
    return magnetometerEventStream().map((event) {
      final raw = headingFromMagnetometer(event.x, event.y);
      last = last == null ? raw : smoothHeading(last!, raw, smoothing);
      return last!;
    });
  }

  /// Converts raw magnetometer x/y (Android device axes: +x to the right of
  /// the screen, +y towards the top edge) into a compass heading.
  ///
  /// The horizontal magnetic field points to magnetic north. When the top of
  /// the phone faces north the field lies along +y (heading 0); facing east the
  /// field lies along -x (heading 90).
  static double headingFromMagnetometer(double x, double y) {
    final heading = atan2(-x, y) * (180 / pi);
    return (heading + 360) % 360;
  }

  /// Low-pass filter that blends angles along the shortest arc, so moving
  /// from 359 to 1 degree goes through 0 rather than spinning round.
  static double smoothHeading(double previous, double next, double factor) {
    final delta = shortestAngleDelta(previous, next);
    return (previous + factor * delta + 360) % 360;
  }

  /// Signed difference from [from] to [to] in the range (-180, 180].
  static double shortestAngleDelta(double from, double to) {
    var diff = (to - from) % 360;
    if (diff > 180) diff -= 360;
    if (diff <= -180) diff += 360;
    return diff;
  }

  /// Initial great-circle bearing from start to end (0-360, clockwise from
  /// north).
  static double calculateBearing({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    final double startLatRad = _degToRad(startLat);
    final double startLngRad = _degToRad(startLng);
    final double endLatRad = _degToRad(endLat);
    final double endLngRad = _degToRad(endLng);

    final double dLng = endLngRad - startLngRad;
    final double y = sin(dLng) * cos(endLatRad);
    final double x = cos(startLatRad) * sin(endLatRad) -
        sin(startLatRad) * cos(endLatRad) * cos(dLng);

    return (atan2(y, x) * (180 / pi) + 360) % 360;
  }

  /// How far to rotate an "up" arrow on screen so it points at the
  /// destination, given the device heading.
  static double calculateArrowRotation({
    required double deviceHeading,
    required double destinationBearing,
  }) {
    return (destinationBearing - deviceHeading + 360) % 360;
  }

  static double _degToRad(double degree) => degree * (pi / 180);
}
