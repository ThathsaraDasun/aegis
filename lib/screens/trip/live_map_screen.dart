import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/trip_model.dart';
import '../../services/location_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/aegis_theme.dart';
import 'trip_summary_screen.dart';

class LiveMapScreen extends StatefulWidget {
  final String tripId;

  const LiveMapScreen({super.key, required this.tripId});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final LocationService _locationService = LocationService();
  final FirestoreService _firestoreService = FirestoreService();
  
  StreamSubscription<Position>? _positionSubscription;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  final List<LatLng> _routePoints = [];
  TripModel? _tripData;
  Timer? _autoTimeoutTimer;
  bool _followUser = true;

  @override
  void initState() {
    super.initState();
    _loadTripData();
    _startTracking();
    _startAutoTimeout();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _autoTimeoutTimer?.cancel();
    super.dispose();
  }

  void _loadTripData() {
    _firestoreService.streamTrip(widget.tripId).listen((data) {
      if (mounted) {
        setState(() {
          _tripData = data;
          _updateMarkers();
        });
      }
    });
  }

  void _startTracking() {
    _positionSubscription = _locationService.livePositionStream().listen((Position position) {
      LatLng currentLatLng = LatLng(position.latitude, position.longitude);
      
      if (mounted) {
        setState(() {
          _routePoints.add(currentLatLng);
          _updateMarkers();
          _updatePolylines();
        });
        
        if (_followUser) {
          _moveCamera(currentLatLng);
        }
        
        // Update Firestore for watchers
        _firestoreService.updateTripLocation(
          widget.tripId, 
          GeoPoint(position.latitude, position.longitude)
        );
      }
    });
  }

  void _startAutoTimeout() {
    // ASSUMPTION: Trip auto-ends after 90 minutes of total duration for MVP.
    _autoTimeoutTimer = Timer(const Duration(minutes: 90), () {
      _endTrip(arrivedSafely: false);
    });
  }

  void _updateMarkers() {
    if (_tripData == null) return;

    Set<Marker> newMarkers = {
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(_tripData!.destination.latitude, _tripData!.destination.longitude),
        infoWindow: const InfoWindow(title: 'Destination'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };

    if (_routePoints.isNotEmpty) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('current_pos'),
          position: _routePoints.last,
          infoWindow: const InfoWindow(title: 'My Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    }

    setState(() {
      _markers = newMarkers;
    });
  }

  void _updatePolylines() {
    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: _routePoints,
          color: AegisColors.secondary,
          width: 6,
          jointType: JointType.round,
        ),
      };
    });
  }

  Future<void> _moveCamera(LatLng pos) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLng(pos));
  }

  Future<void> _endTrip({required bool arrivedSafely}) async {
    // Stop tracking before updating Firestore to prevent one last update
    await _positionSubscription?.cancel();
    _autoTimeoutTimer?.cancel();

    await _firestoreService.endTrip(widget.tripId, arrivedSafely: arrivedSafely);
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => TripSummaryScreen(
            tripId: widget.tripId,
            arrivedSafely: arrivedSafely,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Tracking'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(_followUser ? Icons.gps_fixed : Icons.gps_not_fixed),
            onPressed: () {
              setState(() => _followUser = !_followUser);
              if (_followUser && _routePoints.isNotEmpty) {
                _moveCamera(_routePoints.last);
              }
            },
          )
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: CameraPosition(
              target: _tripData != null 
                ? LatLng(_tripData!.startLocation.latitude, _tripData!.startLocation.longitude)
                : const LatLng(0, 0),
              zoom: 17,
            ),
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
          ),
          
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_tripData != null)
                  _buildStatusCard(),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () => _endTrip(arrivedSafely: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AegisColors.tertiary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 8,
                    ),
                    child: const Text(
                      'I HAVE ARRIVED SAFELY',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AegisColors.surfaceContainerHigh.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AegisColors.secondary,
            child: Icon(Icons.directions_walk, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trip Active',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Sharing live GPS with your guardians',
                  style: TextStyle(color: AegisColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.timer_outlined, color: AegisColors.primary, size: 20),
          const SizedBox(width: 4),
          const Text(
            '90m Left',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
