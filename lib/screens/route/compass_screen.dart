import 'dart:async';
import 'dart:math' show pi;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/saved_location_model.dart';
import '../../services/compass_service.dart';
import '../../services/saved_location_service.dart';
import '../../theme/aegis_theme.dart';
import '../../widgets/state_views.dart';

/// Magnetometer compass whose arrow points at a saved destination
/// ("Where I Parked", or a past trip destination set from Trip Details).
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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _destination = await _locationService.getSavedLocation();
      await _checkPermissionsAndStartUpdates();
    } catch (e) {
      _errorMessage = 'Initialization error: $e';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkPermissionsAndStartUpdates() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _errorMessage = 'Location services are disabled. Turn on GPS to use the compass.';
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _errorMessage = 'Location permission is needed to point you to your destination.';
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _errorMessage = 'Location permission is permanently denied. Enable it in system settings.';
      return;
    }

    _startSubscriptions();
  }

  void _startSubscriptions() {
    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
      ),
    ).listen((position) {
      if (mounted) setState(() => _currentPosition = position);
    });

    _headingSubscription?.cancel();
    _headingSubscription = CompassService.headingStream.listen((heading) {
      if (mounted) setState(() => _heading = heading);
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
    final saved = await _locationService.saveCurrentLocation('Where I Parked');
    if (!mounted) return;
    if (saved != null) {
      setState(() {
        _destination = saved;
        _errorMessage = null;
      });
      _startSubscriptions();
    } else {
      setState(() => _errorMessage = 'Failed to save location. Check permissions.');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _clearDestination() async {
    await _locationService.clearSavedLocation();
    if (!mounted) return;
    setState(() => _destination = null);
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

    final target = CompassService.calculateArrowRotation(
      deviceHeading: _heading!,
      destinationBearing: bearing,
    );

    // Accumulate along the shortest arc so the arrow never spins the long way.
    _lastRotation += CompassService.shortestAngleDelta(_lastRotation, target);
    return _lastRotation;
  }

  String _getDistanceString() {
    if (_currentPosition == null || _destination == null) return '--';

    final distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _destination!.latitude,
      _destination!.longitude,
    );

    return distance < 1000
        ? '${distance.toStringAsFixed(0)} m'
        : '${(distance / 1000).toStringAsFixed(2)} km';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compass'),
        actions: [
          if (_destination != null)
            IconButton(
              tooltip: 'Clear destination',
              icon: const Icon(Icons.delete_outline, color: AegisColors.primary),
              onPressed: _clearDestination,
            ),
        ],
      ),
      body: _isLoading ? const LoadingView() : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null && _destination != null) {
      return ErrorStateView(error: _errorMessage!, onRetry: _initialize);
    }
    if (_destination == null) {
      return EmptyStateView(
        icon: Icons.location_on_outlined,
        message: 'No destination set.\nSave your current location to find your way back later.',
        actionLabel: 'Set Where I Parked',
        onAction: _saveCurrentLocation,
      );
    }
    return _buildCompassState();
  }

  Widget _buildCompassState() {
    final rotation = _calculateRotation();
    final waiting = _heading == null || _currentPosition == null;

    return Center(
      child: SingleChildScrollView(
        padding: AegisSpacing.screen,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_destination!.label, style: AegisText.headline.copyWith(color: AegisColors.textSecondary)),
            const SizedBox(height: AegisSpacing.huge),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: rotation * (pi / 180)),
              duration: const Duration(milliseconds: 300),
              builder: (context, angle, child) => Transform.rotate(angle: angle, child: child),
              child: const Icon(Icons.navigation, size: 200, color: AegisColors.primary),
            ),
            const SizedBox(height: AegisSpacing.huge),
            Text(_getDistanceString(), style: AegisText.display),
            Text('REMAINING', style: AegisText.sectionHeader),
            const SizedBox(height: AegisSpacing.xxl),
            if (waiting)
              Text('Waiting for GPS and compass signal...', style: AegisText.bodySecondary),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: AegisText.body.copyWith(color: AegisColors.primary),
              ),
            const SizedBox(height: AegisSpacing.sm),
            Text(
              'Hold your phone flat for the most accurate direction.',
              textAlign: TextAlign.center,
              style: AegisText.small,
            ),
            const SizedBox(height: AegisSpacing.xxl),
            TextButton.icon(
              onPressed: _saveCurrentLocation,
              icon: const Icon(Icons.my_location),
              label: const Text('Save current spot instead'),
            ),
          ],
        ),
      ),
    );
  }
}
