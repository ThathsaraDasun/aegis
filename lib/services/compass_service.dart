import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

class CompassService {
  static double _lastHeading = 0;

  /// Streams the device's heading in degrees (0–360).
  static Stream<double> get headingStream {
    return magnetometerEventStream().map((event) {
      // Standard formula for Android/iOS devices held flat
      // atan2(y, x) gives the angle relative to the X axis.
      // We adjust it to make North = 0.
      double heading = atan2(event.y, event.x) * (180 / pi);
      
      // Convert to 0-360 range and adjust offset
      heading = (heading + 450) % 360; 

      // Smoothing filter
      double filteredHeading = _lastHeading + 0.2 * (heading - _lastHeading);
      if ((heading - _lastHeading).abs() > 180) filteredHeading = heading;

      _lastHeading = filteredHeading;
      return filteredHeading;
    });
  }

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

  static double calculateArrowRotation({
    required double deviceHeading,
    required double destinationBearing,
  }) {
    return (destinationBearing - deviceHeading + 360) % 360;
  }

  static double _degToRad(double degree) => degree * (pi / 180);
}
