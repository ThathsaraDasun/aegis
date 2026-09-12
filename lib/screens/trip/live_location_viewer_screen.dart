import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/trip_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/aegis_theme.dart';

class LiveLocationViewerScreen extends StatefulWidget {
  final String tripId;

  const LiveLocationViewerScreen({super.key, required this.tripId});

  @override
  State<LiveLocationViewerScreen> createState() => _LiveLocationViewerScreenState();
}

class _LiveLocationViewerScreenState extends State<LiveLocationViewerScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final FirestoreService _firestoreService = FirestoreService();
  
  StreamSubscription<TripModel>? _tripSubscription;
  Set<Marker> _markers = {};
  TripModel? _tripData;

  @override
  void initState() {
    super.initState();
    _subscribeToTrip();
  }

  @override
  void dispose() {
    _tripSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToTrip() {
    _tripSubscription = _firestoreService.streamTrip(widget.tripId).listen((data) {
      if (mounted) {
        setState(() {
          _tripData = data;
          _updateMarkers();
        });
        
        _moveCamera(LatLng(data.currentLocation.latitude, data.currentLocation.longitude));
      }
    }, onError: (e) {
      debugPrint('Error watching trip: $e');
    });
  }

  void _updateMarkers() {
    if (_tripData == null) return;

    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('start'),
          position: LatLng(_tripData!.startLocation.latitude, _tripData!.startLocation.longitude),
          infoWindow: const InfoWindow(title: 'Trip Started Here'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(_tripData!.destination.latitude, _tripData!.destination.longitude),
          infoWindow: const InfoWindow(title: 'Destination'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
        Marker(
          markerId: const MarkerId('current_pos'),
          position: LatLng(_tripData!.currentLocation.latitude, _tripData!.currentLocation.longitude),
          infoWindow: const InfoWindow(title: 'Live Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      };
    });
  }

  Future<void> _moveCamera(LatLng pos) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLng(pos));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Watcher Mode'),
        backgroundColor: AegisColors.surfaceContainerLow,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_tripData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    bool isActive = _tripData!.status == 'active';

    return Stack(
      children: [
        GoogleMap(
          mapType: MapType.normal,
          initialCameraPosition: CameraPosition(
            target: LatLng(_tripData!.currentLocation.latitude, _tripData!.currentLocation.longitude),
            zoom: 15,
          ),
          markers: _markers,
          onMapCreated: (GoogleMapController controller) {
            _controller.complete(controller);
          },
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
        ),
        
        // Status Overlay
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            decoration: BoxDecoration(
              color: isActive ? AegisColors.primary : Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
            ),
            child: Row(
              children: [
                Icon(
                  isActive ? Icons.sensors : Icons.sensors_off,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Text(
                  isActive ? 'WATCHING LIVE' : 'TRIP ENDED',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),

        if (!isActive)
          _buildTripEndedOverlay(),
      ],
    );
  }

  Widget _buildTripEndedOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, color: AegisColors.tertiary, size: 80),
              const SizedBox(height: 24),
              const Text(
                'Trip Successfully Completed',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'The user has arrived safely or the trip was closed.',
                style: TextStyle(color: AegisColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CLOSE VIEWER'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
