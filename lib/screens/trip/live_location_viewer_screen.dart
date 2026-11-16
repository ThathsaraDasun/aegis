import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../models/shared_trip_model.dart';
import '../../services/firestore_service.dart';
import 'trip_map.dart';

/// Shows a trip's live position.
///
/// Opened with [tripId] it reads the owner's own trip (owner-only rules).
/// Opened with [shareToken] (from an `aegis://live/<token>` link) it reads the
/// public guardian mirror, which works without signing in while the trip is active.
class LiveLocationViewerScreen extends StatefulWidget {
  final String? tripId;
  final String? shareToken;

  const LiveLocationViewerScreen({super.key, this.tripId, this.shareToken})
    : assert(tripId != null || shareToken != null);

  /// Viewer for a guardian link.
  const LiveLocationViewerScreen.shared({super.key, required String this.shareToken})
    : tripId = null;

  @override
  State<LiveLocationViewerScreen> createState() =>
      _LiveLocationViewerScreenState();
}

class _LiveLocationViewerScreenState extends State<LiveLocationViewerScreen> {
  final _map = MapController();
  bool _ready = false;
  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  late final Stream<SharedTripModel?> _stream = widget.shareToken != null
      ? FirestoreService.instance.streamSharedTrip(widget.shareToken!)
      : FirestoreService.instance
            .streamTrip(widget.tripId!)
            .map((trip) => trip == null ? null : SharedTripModel.fromTrip(trip));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Trip location')),
    body: StreamBuilder<SharedTripModel?>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                widget.shareToken != null
                    ? 'This live link has ended or is not valid.'
                    : 'Unable to access this trip. It must be shared with your account.',
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final trip = snapshot.data;
        if (trip == null) {
          return const Center(child: Text('This trip no longer exists.'));
        }
        final current = tripCoordinate(trip.currentLocation);
        if (current == null) {
          return const Center(
            child: Text('This trip has no valid location yet.'),
          );
        }
        if (_ready) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _map.move(current, _map.camera.zoom);
          });
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                !trip.isLive
                    ? 'Trip ended — last saved position'
                    : trip.alerted
                    ? 'SOS raised — latest shared position'
                    : 'Latest shared position',
              ),
            ),
            Expanded(
              child: TripMap(
                center: current,
                controller: _map,
                onReady: () => _ready = true,
                current: current,
                destination: tripCoordinate(trip.destination),
              ),
            ),
            const SizedBox(height: 160),
          ],
        );
      },
    ),
  );
}
