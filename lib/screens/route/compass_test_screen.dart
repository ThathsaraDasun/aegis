import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/compass_service.dart';

class CompassTestScreen extends StatefulWidget {
  const CompassTestScreen({super.key});

  @override
  State<CompassTestScreen> createState() => _CompassTestScreenState();
}

class _CompassTestScreenState extends State<CompassTestScreen> {
  double _heading = 0;
  double _bearing = 0;
  double _rotation = 0;
  StreamSubscription<double>? _subscription;

  // Hardcoded test values — replace with real GPS later
  final double _testUserLat = 6.9271;
  final double _testUserLng = 79.8612;
  final double _testDestLat = 6.9310;
  final double _testDestLng = 79.8650;

  @override
  void initState() {
    super.initState();

    // Calculate bearing once (doesn't change unless location updates)
    _bearing = CompassService.calculateBearing(
      startLat: _testUserLat,
      startLng: _testUserLng,
      endLat: _testDestLat,
      endLng: _testDestLng,
    );

    // Listen to live heading updates
    _subscription = CompassService.headingStream.listen((heading) {
      setState(() {
        _heading = heading;
        _rotation = CompassService.calculateArrowRotation(
          deviceHeading: heading,
          destinationBearing: _bearing,
        );
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Compass Logic Test")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Device Heading: ${_heading.toStringAsFixed(1)}°",
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text("Destination Bearing: ${_bearing.toStringAsFixed(1)}°",
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text("Arrow Rotation: ${_rotation.toStringAsFixed(1)}°",
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 40),
            Transform.rotate(
              angle: _rotation * (3.14159 / 180),
              child: const Icon(
                Icons.navigation,
                size: 100,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}