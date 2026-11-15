import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../models/trip_model.dart';
import '../../services/firestore_service.dart';
import 'trip_map.dart';

/// Reads only trips permitted by the deployed Firestore rules.
class LiveLocationViewerScreen extends StatefulWidget {
  final String tripId;
  const LiveLocationViewerScreen({super.key, required this.tripId});
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

  late final _stream = FirestoreService.instance.streamTrip(widget.tripId);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Trip location')),
    body: StreamBuilder<TripModel?>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Unable to access this trip. It must be shared with your account.',
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
                trip.endedAt == null && trip.status != TripStatus.completed
                    ? 'Latest shared position'
                    : 'Trip ended — last saved position',
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
