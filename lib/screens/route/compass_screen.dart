import 'dart:async';
import 'dart:math' show pi;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/saved_location_model.dart';
import '../../services/compass_service.dart';
import '../../services/saved_location_service.dart';
import '../../theme/aegis_theme.dart';

class CompassScreen extends StatefulWidget {
  const CompassScreen({super.key});

  @override
  State<CompassScreen> createState() => _CompassScreenState();
}

class _CompassScreenState extends State<CompassScreen> {
  final SavedLocationService _locationService = SavedLocationService();
  
  SavedLocation? _destination;
  Position? _currentPosition;
  double? _heading;
  double _lastRotation = 0.0;
  
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<double>? _headingSubscription;

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);
    
    try {
      _destination = await _locationService.getSavedLocation();
      await _checkPermissionsAndStartUpdates();
    } catch (e) {
      setState(() => _errorMessage = "Initialization error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkPermissionsAndStartUpdates() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _errorMessage = "Location services are disabled.");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _errorMessage = "Location permissions are denied.");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _errorMessage = "Location permissions are permanently denied.");
      return;
    }

    _startSubscriptions();
  }

  void _startSubscriptions() {
    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best, // නිරවද්‍යතාවය උපරිම කිරීම
        distanceFilter: 0, // සෑම මීටරයකටම යාවත්කාලීන කිරීම
      ),
    ).listen((position) {
      if (mounted) {
        setState(() => _currentPosition = position);
      }
    });

    _headingSubscription?.cancel();
    _headingSubscription = CompassService.headingStream.listen((heading) {
      if (mounted) {
        setState(() => _heading = heading);
      }
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _headingSubscription?.cancel();
    super.dispose();
  }

  Future<void> _saveCurrentLocation() async {
    setState(() => _isLoading = true);
    final saved = await _locationService.saveCurrentLocation("Where I Parked");
    if (saved != null) {
      setState(() {
        _destination = saved;
        _errorMessage = null;
      });
      _startSubscriptions();
    } else {
      setState(() => _errorMessage = "Failed to save location. Check permissions.");
    }
    setState(() => _isLoading = false);
  }

  Future<void> _clearDestination() async {
    await _locationService.clearSavedLocation();
    setState(() {
      _destination = null;
      _currentPosition = null;
    });
  }

  double _calculateRotation() {
    if (_heading == null || _currentPosition == null || _destination == null) {
      return _lastRotation;
    }

    final bearing = CompassService.calculateBearing(
      startLat: _currentPosition!.latitude,
      startLng: _currentPosition!.longitude,
      endLat: _destination!.latitude,
      endLng: _destination!.longitude,
    );

    double newRotation = CompassService.calculateArrowRotation(
      deviceHeading: _heading!,
      destinationBearing: bearing,
    );

    // Shortest path rotation logic
    double diff = newRotation - (_lastRotation % 360);
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    _lastRotation += diff;

    return _lastRotation;
  }

  String _getDistanceString() {
    if (_currentPosition == null || _destination == null) return "--";
    
    final distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _destination!.latitude,
      _destination!.longitude,
    );

    if (distance < 1000) {
      return "${distance.toStringAsFixed(0)}m";
    } else {
      return "${(distance / 1000).toStringAsFixed(2)}km";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AegisColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Compass",
          style: GoogleFonts.outfit(
            color: AegisColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_destination != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AegisColors.primary),
              onPressed: _clearDestination,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AegisColors.primary))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null && _destination != null) {
      return _buildErrorState();
    }

    if (_destination == null) {
      return _buildEmptyState();
    }

    return _buildCompassState();
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 80,
              color: AegisColors.textSecondary,
            ),
            const SizedBox(height: 24),
            Text(
              "No Destination Set",
              style: GoogleFonts.outfit(
                fontSize: 24,
                color: AegisColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Save your current location to find your way back later.",
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: AegisColors.textSecondary,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _saveCurrentLocation,
              icon: const Icon(Icons.add_location_alt),
              label: const Text("Set Where I Parked"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AegisColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompassState() {
    final rotation = _calculateRotation();
    final distance = _getDistanceString();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _destination!.label,
            style: GoogleFonts.outfit(
              fontSize: 22,
              color: AegisColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 40),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: rotation * (pi / 180)),
            duration: const Duration(milliseconds: 300),
            builder: (context, angle, child) {
              return Transform.rotate(
                angle: angle,
                child: const Icon(
                  Icons.navigation, // නැවතත් ලස්සන Navigation icon එකට මාරු කළා
                  size: 200,
                  color: AegisColors.primary,
                ),
              );
            },
          ),
          const SizedBox(height: 40),
          Text(
            distance,
            style: GoogleFonts.outfit(
              fontSize: 48,
              color: AegisColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            "REMAINING",
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: AegisColors.textSecondary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 60),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: AegisColors.textPrimary),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initialize,
              child: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }
}
