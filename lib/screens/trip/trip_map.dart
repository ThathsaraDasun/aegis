import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

LatLng? tripCoordinate(Map<String, double> value) {
  final lat = value['lat'], lng = value['lng'];
  if (lat == null ||
      lng == null ||
      !lat.isFinite ||
      !lng.isFinite ||
      lat.abs() > 90 ||
      lng.abs() > 180) {
    return null;
  }
  return LatLng(lat, lng);
}

/// Standard OSM tiles: visible attribution, identified client, HTTP-aware cache.
/// No offline download/prefetch feature. NetworkTileProvider caches by default.
class TripMap extends StatelessWidget {
  final LatLng center;
  final LatLng? current;
  final LatLng? destination;
  final List<LatLng> trail;
  final MapController? controller;
  final ValueChanged<LatLng>? onTap;
  final VoidCallback? onReady;
  final TileProvider? tileProvider;
  const TripMap({
    super.key,
    required this.center,
    this.current,
    this.destination,
    this.trail = const [],
    this.controller,
    this.onTap,
    this.onReady,
    this.tileProvider,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: FlutterMap(
          mapController: controller,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 16,
            minZoom: 3,
            maxZoom: 19,
            onMapReady: onReady,
            onTap: (_, point) => onTap?.call(point),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.aegis.safewalk',
              tileProvider: tileProvider,
              maxNativeZoom: 19,
              panBuffer: 0,
              keepBuffer: 0,
            ),
            if (trail.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(points: trail, color: Colors.blue, strokeWidth: 5),
                ],
              ),
            MarkerLayer(
              markers: [
                if (current != null)
                  Marker(
                    point: current!,
                    width: 36,
                    height: 36,
                    child: const Tooltip(
                      message: 'Current position',
                      child: Icon(
                        Icons.my_location,
                        color: Colors.blue,
                        size: 30,
                      ),
                    ),
                  ),
                if (destination != null)
                  Marker(
                    point: destination!,
                    width: 42,
                    height: 42,
                    child: const Tooltip(
                      message: 'Destination',
                      child: Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      Material(
        color: Colors.white,
        child: InkWell(
          onTap: () =>
              launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
          child: const SizedBox(
            width: double.infinity,
            height: 30,
            child: Center(
              child: Text(
                '© OpenStreetMap contributors',
                style: TextStyle(color: Colors.black87, fontSize: 12),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}
