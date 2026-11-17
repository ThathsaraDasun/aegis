import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/trip_model.dart';
import '../../services/alert_service.dart';
import '../../services/location_service.dart';
import '../../services/firestore_service.dart';
import '../../services/trip_share_service.dart';
import '../../theme/aegis_theme.dart';
import 'trip_summary_screen.dart';
import 'trip_map.dart';

/// Member 2 (Location & Maps Lead): Live map tracking with real-time position, markers, and polylines.
class LiveMapScreen extends StatefulWidget {
  final String tripId;

  /// Planned route points from route comparison (may be empty).
  final List<LatLng> plannedRoutePoints;

  /// Guardian live-location link for this trip (null if sharing is off).
  final String? guardianLink;

  /// Prepared trip-start alert for guardians (SMS/WhatsApp options).
  final TripStartShare? guardianShare;
  final String? sharingError;

  const LiveMapScreen({
    super.key,
    required this.tripId,
    this.plannedRoutePoints = const [],
    this.guardianLink,
    this.guardianShare,
    this.sharingError,
  });
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
        _stopGuardianSharing();
      } else if (first) {
        _startTracking();
        // After an app restart, continue sharing a link sent earlier.
        TripShareService.instance.resume(widget.tripId).then((_) {
          if (mounted) setState(() {});
        });
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

  /// Ends guardian live sharing for this trip (revokes the link).
  void _stopGuardianSharing() {
    if (TripShareService.supported) {
      TripShareService.instance.stopForTrip(widget.tripId);
    }
  }

  bool get _sharing =>
      widget.guardianLink != null ||
      (TripShareService.supported &&
          TripShareService.instance.isSharing(widget.tripId));

  Future<void> _notifyBySms() async {
    final share = widget.guardianShare;
    if (share == null) return;
    final opened = await AlertService.instance.openTripStartSms(share);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open your SMS app.')),
      );
    }
  }

  Future<void> _notifyByWhatsApp() async {
    final links = widget.guardianShare?.whatsAppLinks ?? const [];
    if (links.isEmpty) return;
    if (links.length == 1) {
      await launchUrl(links.first.uri, mode: LaunchMode.externalApplication);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Text(
              'Send on WhatsApp',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            for (final link in links)
              ListTile(
                leading: const Icon(
                  Icons.chat_outlined,
                  color: AegisColors.azure,
                ),
                title: Text(link.name),
                onTap: () {
                  Navigator.of(sheet).pop();
                  launchUrl(link.uri, mode: LaunchMode.externalApplication);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _guardianCard() {
    final share = widget.guardianShare;
    final autoMessage = share?.automaticSmsMessage;
    final canNotify =
        share != null &&
        share.contactCount > 0 &&
        autoMessage == null &&
        !_ended;
    final String title;
    final String detail;
    if (_ended) {
      title = 'Trip ended – sharing stopped';
      detail = 'Your guardians can no longer see your location.';
    } else if (_sharing) {
      title = 'Guardians can follow this trip';
      detail =
          autoMessage ??
          (share == null
              ? 'Could not load guardian messaging details. No message has been confirmed; contact your guardian directly.'
              : share.contactCount == 0
              ? 'No guardians saved – add one in the Guardians tab to share your trip.'
              : 'Send them your live link. It keeps working with the screen locked and stops when you end the trip.');
    } else {
      title = 'Live sharing is off';
      detail =
          widget.sharingError ??
          (share == null
              ? 'Could not prepare guardian sharing. Check your connection; no message has been confirmed.'
              : share.contactCount == 0
              ? 'No guardians saved – add one in the Guardians tab.'
              : 'Could not create a live link (check internet). You can still send your starting location.');
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AegisColors.surfaceContainerHigh),
        boxShadow: [
          BoxShadow(
            color: AegisColors.azure.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AegisColors.azure.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _sharing && !_ended
                      ? Icons.share_location_rounded
                      : Icons.location_off_outlined,
                  color: AegisColors.azure,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AegisColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AegisColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (canNotify) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _notifyBySms,
                    icon: const Icon(Icons.sms_outlined, size: 18),
                    label: const Text('Notify by SMS'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AegisColors.azure,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
                if (share.whatsAppLinks.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _notifyByWhatsApp,
                      icon: const Icon(Icons.chat_outlined, size: 18),
                      label: const Text('WhatsApp'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AegisColors.azure,
                        side: const BorderSide(color: AegisColors.azure),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
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
      // A slow location write must not hold up ending the trip.
      try {
        await _pendingWrite?.timeout(const Duration(seconds: 3));
      } catch (_) {}
      // Firestore applies the end on the phone immediately and uploads it
      // when the server is reachable. On a slow or missing connection the
      // server confirmation can take a long time, so a timeout here means
      // "queued", not "failed"; only a real error (e.g. permission) fails.
      var syncPending = false;
      try {
        await _store
            .endTrip(
              widget.tripId,
              status: arrivedSafely ? TripStatus.completed : TripStatus.alerted,
            )
            .timeout(const Duration(seconds: 6));
      } on TimeoutException {
        syncPending = true;
      }
      _ended = true;
      _timer?.cancel();
      _stopGuardianSharing();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => TripSummaryScreen(
              tripId: widget.tripId,
              arrivedSafely: arrivedSafely,
              duration: _trip == null
                  ? null
                  : DateTime.now().difference(_trip!.startedAt),
              destinationName: _trip?.destinationName,
              syncPending: syncPending,
              lastLat: _current?.latitude,
              lastLng: _current?.longitude,
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
        _guardianCard(),
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
                  plannedRoute: widget.plannedRoutePoints,
                  controller: _map,
                  onReady: () => _ready = true,
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            _ended
                ? 'Trip ended'
                : _sharing
                ? 'Guardians keep receiving your location with the screen locked. The blue line shows this session’s travelled path.'
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
