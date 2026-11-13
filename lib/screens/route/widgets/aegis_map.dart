import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../theme/aegis_theme.dart';

/// Dark OpenStreetMap base map (CARTO dark tiles – no API key) shared by the
/// Safe Route screens. Pass overlay layers as [children].
class AegisMap extends StatelessWidget {
  final MapController? controller;
  final LatLng initialCenter;
  final double initialZoom;
  final CameraFit? initialFit;
  final List<Widget> children;
  final void Function(TapPosition, LatLng)? onTap;
  final VoidCallback? onMapReady;
  final bool interactive;

  const AegisMap({
    super.key,
    required this.initialCenter,
    this.controller,
    this.initialZoom = 16,
    this.initialFit,
    this.children = const [],
    this.onTap,
    this.onMapReady,
    this.interactive = true,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: initialZoom,
        initialCameraFit: initialFit,
        minZoom: 3,
        maxZoom: 19,
        backgroundColor: AegisColors.surfaceContainerLow,
        onTap: onTap,
        onMapReady: onMapReady,
        interactionOptions: InteractionOptions(
          flags: interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          retinaMode: RetinaMode.isHighDensity(context),
          userAgentPackageName: 'com.aegis.safewalk',
          maxZoom: 19,
        ),
        ...children,
        const SimpleAttributionWidget(
          source: Text('© OpenStreetMap contributors © CARTO'),
          backgroundColor: Color(0xAA1E1F25),
        ),
      ],
    );
  }
}

/// Blue "you are here" dot.
class MyLocationDot extends StatelessWidget {
  const MyLocationDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AegisColors.secondary.withValues(alpha: 0.25),
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(5),
      child: Container(
        decoration: BoxDecoration(
          color: AegisColors.secondary,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
        ),
      ),
    );
  }
}

/// Flag-style destination pin (anchor at bottom centre).
class DestinationPin extends StatelessWidget {
  final Color color;
  final IconData icon;
  const DestinationPin({super.key, this.color = AegisColors.primary, this.icon = Icons.flag_rounded});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6)],
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        Container(width: 3, height: 12, color: color),
      ],
    );
  }
}

/// Small round icon button floating on top of a map.
class MapFab extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  const MapFab({super.key, required this.icon, required this.onPressed, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AegisColors.surfaceContainerHigh,
      shape: const CircleBorder(),
      elevation: 4,
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: AegisColors.textPrimary),
        onPressed: onPressed,
      ),
    );
  }
}
