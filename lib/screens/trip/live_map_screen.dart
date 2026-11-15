import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../models/trip_model.dart';
import '../../services/location_service.dart';
import '../../services/firestore_service.dart';
import 'trip_summary_screen.dart';
import 'trip_map.dart';

class LiveMapScreen extends StatefulWidget {
  final String tripId;
  const LiveMapScreen({super.key, required this.tripId});
  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen>
    with WidgetsBindingObserver {
  final _map = MapController();
  final _store = FirestoreService();
  final _location = LocationService();
  StreamSubscription<TripModel?>? _tripSubscription;
  StreamSubscription<Position>? _positions;
  Timer? _timer;
  TripModel? _trip;
  LatLng? _current;
  final List<LatLng> _trail = [];
  bool _ready = false, _follow = true, _ending = false, _ended = false;
  bool _foreground = true, _writing = false;
  Future<void>? _pendingWrite;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tripSubscription = _store.streamTrip(widget.tripId).listen((trip) {
      if (!mounted) return;
      final first = _trip == null;
      setState(() {
        _trip = trip;
        if (trip == null) _error = 'This trip no longer exists.';
        _current ??= trip == null ? null : tripCoordinate(trip.currentLocation);
      });
      if (trip == null) {
        _stop();
        return;
      }
      if (trip.endedAt != null || trip.status == TripStatus.completed) {
        _ended = true;
        _stop();
      } else if (first) {
        _startTracking();
        final remaining = trip.startedAt
            .add(const Duration(minutes: 90))
            .difference(DateTime.now());
        _timer = Timer(
          remaining.isNegative ? Duration.zero : remaining,
          () => _end(arrivedSafely: false),
        );
      }
    }, onError: (Object e) => _showError('Could not load trip: $e'));
  }

  void _showError(String message) {
    if (mounted) setState(() => _error = message);
  }

  void _startTracking() {
    if (_positions != null ||
        _ended ||
        _ending ||
        !_foreground ||
        _trip == null) {
      return;
    }
    _positions = _location.livePositionStream().listen(
      (p) {
        if (!mounted || _ending || _ended || !_foreground) return;
        final point = LatLng(p.latitude, p.longitude);
        setState(() {
          _current = point;
          _trail.add(point);
        });
        if (_ready && _follow) _map.move(point, _map.camera.zoom);
        // Keep only one remote location write in flight; a later GPS tick catches up.
        if (!_writing) {
          _writing = true;
          _pendingWrite = _store
              .updateTripLocation(widget.tripId, p.latitude, p.longitude)
              .timeout(const Duration(seconds: 10))
              .catchError((Object e) {
                _showError('Location could not be saved: $e');
              })
              .whenComplete(() => _writing = false);
        }
      },
      onError: (Object e) =>
          _showError('GPS tracking failed. Check location permission: $e'),
    );
  }

  void _stop() {
    _positions?.cancel();
    _positions = null;
    _timer?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _positions?.cancel();
      _positions = null;
    } else {
      _startTracking();
    }
  }

  Future<void> _end({required bool arrivedSafely}) async {
    if (_ending || _ended) return;
    setState(() {
      _ending = true;
      _error = null;
    });
    await _positions?.cancel();
    _positions = null;
    try {
      await _pendingWrite;
      await _store
          .endTrip(
            widget.tripId,
            status: arrivedSafely ? TripStatus.completed : TripStatus.alerted,
          )
          .timeout(const Duration(seconds: 15));
      _ended = true;
      _timer?.cancel();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TripSummaryScreen(
              tripId: widget.tripId,
              arrivedSafely: arrivedSafely,
            ),
          ),
        );
      }
    } catch (e) {
      _showError('Could not end trip. Please retry: $e');
    } finally {
      if (mounted) {
        setState(() => _ending = false);
        if (!_ended) _startTracking();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tripSubscription?.cancel();
    _stop();
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Live Tracking'),
      actions: [
        IconButton(
          tooltip: 'Follow my position',
          icon: Icon(_follow ? Icons.gps_fixed : Icons.gps_not_fixed),
          onPressed: () {
            setState(() => _follow = !_follow);
            if (_follow && _ready && _current != null) {
              _map.move(_current!, _map.camera.zoom);
            }
          },
        ),
      ],
    ),
    body: Column(
      children: [
        if (_error != null)
          Padding(padding: const EdgeInsets.all(8), child: Text(_error!)),
        Expanded(
          child: _current == null
              ? Center(
                  child: _error == null
                      ? const CircularProgressIndicator()
                      : const Text('Map unavailable'),
                )
              : TripMap(
                  center: _current!,
                  current: _current,
                  destination: _trip == null
                      ? null
                      : tripCoordinate(_trip!.destination),
                  trail: List.of(_trail),
                  controller: _map,
                  onReady: () => _ready = true,
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            _ended
                ? 'Trip ended'
                : 'GPS tracking runs while the app is open. The blue line shows this session’s travelled path.',
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 160),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _ending || _ended || _trip == null
                  ? null
                  : () => _end(arrivedSafely: true),
              child: Text(_ending ? 'Ending trip…' : 'I have arrived safely'),
            ),
          ),
        ),
      ],
    ),
  );
}
