import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../../models/trip_model.dart';
import '../../services/alert_service.dart';
import '../../services/destination_search_service.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../services/trip_share_service.dart';
import '../../widgets/location_permission_prompt.dart';
import 'destination_search_sheet.dart';
import 'live_map_screen.dart';
import 'trip_map.dart';

class StartTripScreen extends StatefulWidget {
  final FirestoreService? store;
  final Future<LocationStatus> Function()? checkLocation;
  final Future<Position> Function()? readPosition;
  final String? Function()? currentUserId;
  final Widget Function(String)? liveTripBuilder;
  final TileProvider? tileProvider;

  /// Pre-selected destination from the Route Comparison screen (Priority 4).
  final LatLng? presetDestination;

  /// Human-readable name for [presetDestination], e.g. from Nominatim search.
  final String? presetDestinationName;

  /// Planned route polyline to overlay on the live map.
  final List<LatLng>? presetRoutePoints;

  const StartTripScreen({
    super.key,
    this.store,
    this.checkLocation,
    this.readPosition,
    this.currentUserId,
    this.liveTripBuilder,
    this.tileProvider,
    this.presetDestination,
    this.presetDestinationName,
    this.presetRoutePoints,
  });

  @override
  State<StartTripScreen> createState() => _StartTripScreenState();
}

class _StartTripScreenState extends State<StartTripScreen> {
  late final _store = widget.store ?? FirestoreService.instance;
  Future<LocationStatus> _checkLocation() =>
      widget.checkLocation?.call() ?? LocationService().checkLocationStatus();
  final _tripId = const Uuid().v4();
  LocationStatus _status = LocationStatus.ready;
  LatLng? _origin, _destination;
  bool _loading = true, _starting = false;
  String? _error;
  final _mapController = MapController();
  String? _destinationName;
  List<LatLng> _plannedRoutePoints = const [];

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _searchDestination() async {
    final place = await showModalBottomSheet<DestinationPlace>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.85,
        child: DestinationSearchSheet(),
      ),
    );
    if (!mounted || place == null) return;
    setState(() {
      _destination = place.position;
      _destinationName = place.name;
      _error = null;
    });
    _mapController.move(place.position, 16);
  }

  @override
  void initState() {
    super.initState();
    // Apply preset destination from route comparison (Priority 4).
    if (widget.presetDestination != null) {
      _destination = widget.presetDestination;
      _destinationName = widget.presetDestinationName;
      _plannedRoutePoints = widget.presetRoutePoints ?? const [];
    }
    _locate();
  }

  Future<Position> _position() =>
      widget.readPosition?.call() ??
      Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 30),
        ),
      );

  Future<void> _locate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await _checkLocation();
      if (!mounted) return;
      _status = status;
      if (status == LocationStatus.ready) {
        final p = await _position();
        if (!mounted) return;
        _origin = LatLng(p.latitude, p.longitude);
      }
    } catch (e) {
      if (mounted) {
        _error = e is TimeoutException
            ? 'GPS did not return a position within 30 seconds. Enable precise location, move near a window or outdoors, then retry.'
            : 'Could not get your location (${e.runtimeType}): $e';
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<({String? link, TripStartShare? share})> _shareWithGuardians({
    required String uid,
    required String tripId,
    required Position position,
    required LatLng destination,
  }) async {
    if (Firebase.apps.isEmpty) return (link: null, share: null);
    String? link;
    try {
      link = await TripShareService.instance
          .start(
            tripId: tripId,
            lat: position.latitude,
            lng: position.longitude,
            accuracy: position.accuracy,
            fixTime: position.timestamp,
            destination: {
              'lat': destination.latitude,
              'lng': destination.longitude,
            },
            destinationName: _destinationName,
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {}
    TripStartShare? share;
    try {
      final contacts = await FirestoreService.instance
          .getContacts(uid)
          .timeout(const Duration(seconds: 8));
      share = await AlertService.instance
          .prepareTripStartShare(
            userId: uid,
            contactIds: [for (final c in contacts) c.id],
            lat: position.latitude,
            lng: position.longitude,
            tripId: tripId,
            liveLocationUrl: link,
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {}
    return (link: link, share: share);
  }

  Future<void> _start() async {
    if (_starting || _destination == null) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final status = await _checkLocation();
      if (!mounted) return;
      if (status != LocationStatus.ready) {
        setState(() => _status = status);
        return;
      }
      final p = await _position();
      if (!mounted) return;
      final uid = widget.currentUserId != null
          ? widget.currentUserId!()
          : FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('Sign in before starting a trip.');
      final destination = _destination!;
      final id = await _store
          .createTrip(
            TripModel(
              tripId: _tripId,
              userId: uid,
              status: TripStatus.active,
              startLocation: {'lat': p.latitude, 'lng': p.longitude},
              currentLocation: {'lat': p.latitude, 'lng': p.longitude},
              destination: {
                'lat': destination.latitude,
                'lng': destination.longitude,
              },
              startedAt: DateTime.now(),
              destinationName: _destinationName,
            ),
          )
          .timeout(const Duration(seconds: 15));

      final guardians = await _shareWithGuardians(
        uid: uid,
        tripId: id,
        position: p,
        destination: destination,
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                widget.liveTripBuilder?.call(id) ??
                LiveMapScreen(
                  tripId: id,
                  plannedRoutePoints: _plannedRoutePoints,
                  guardianLink: guardians.link,
                  guardianShare: guardians.share,
                  sharingError: TripShareService.instance.lastStartError,
                ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not start trip: $e');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Choose your destination')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _status != LocationStatus.ready
        ? LocationPermissionPrompt(status: _status, onRetry: _locate)
        : _origin == null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error ?? 'Location unavailable'),
                TextButton(onPressed: _locate, child: const Text('Retry')),
                TextButton(
                  onPressed: Geolocator.openLocationSettings,
                  child: const Text('Open location settings'),
                ),
                TextButton(
                  onPressed: Geolocator.openAppSettings,
                  child: const Text('Open app permissions'),
                ),
              ],
            ),
          )
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: OutlinedButton.icon(
                  onPressed: _starting ? null : _searchDestination,
                  icon: const Icon(Icons.search),
                  label: const Text('Search for a shop, school or address'),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Tap the map to choose a destination. Internet is needed for map tiles.',
                ),
              ),
              Expanded(
                child: TripMap(
                  center: _origin!,
                  controller: _mapController,
                  tileProvider: widget.tileProvider,
                  current: _origin,
                  destination: _destination,
                  onTap: _starting
                      ? null
                      : (point) => setState(() {
                          _destination = point;
                          _destinationName = null;
                        }),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  _destination == null
                      ? 'Select a destination to continue.'
                      : _destinationName ??
                            'Destination: ${_destination!.latitude.toStringAsFixed(5)}, ${_destination!.longitude.toStringAsFixed(5)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_error != null)
                Padding(padding: const EdgeInsets.all(8), child: Text(_error!)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _starting || _destination == null
                        ? null
                        : _start,
                    child: Text(_starting ? 'Starting trip…' : 'Start trip'),
                  ),
                ),
              ),
            ],
          ),
  );
}
