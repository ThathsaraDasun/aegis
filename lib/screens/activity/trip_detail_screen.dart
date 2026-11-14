import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/alert_model.dart';
import '../../models/trip_model.dart';
import '../../services/activity_service.dart';
import '../../services/saved_location_service.dart';
import '../../theme/aegis_theme.dart';
import '../../widgets/alert_banner.dart';
import '../../widgets/state_views.dart';
import '../../widgets/trip_card.dart';
import '../route/compass_screen.dart';
import 'alert_detail_sheet.dart';

/// Re-opens a past trip for reference: route sketch, timings, alerts raised
/// during the trip, and one-tap actions to view the route in Maps or point the
/// compass at the trip's destination.
class TripDetailScreen extends StatelessWidget {
  const TripDetailScreen({super.key, required this.trip, this.service});

  final TripModel trip;
  final ActivityService? service;

  /// One-tap entry point used by TripCard taps across the app.
  static Future<void> open(BuildContext context, TripModel trip) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TripDetailScreen(trip: trip)),
    );
  }

  bool get _hasStart => trip.startLocation.containsKey('lat') && trip.startLocation.containsKey('lng');
  bool get _hasDestination => trip.destination.containsKey('lat') && trip.destination.containsKey('lng');

  Future<void> _openInMaps(BuildContext context) async {
    final origin = '${trip.startLocation['lat']},${trip.startLocation['lng']}';
    final destination = '${trip.destination['lat']},${trip.destination['lng']}';
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination&travelmode=walking',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open a maps app on this device.')),
      );
    }
  }

  Future<void> _navigateWithCompass(BuildContext context) async {
    await SavedLocationService().saveCoordinates(
      label: 'Trip destination',
      latitude: trip.destination['lat']!,
      longitude: trip.destination['lng']!,
    );
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CompassScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE, MMM dd yyyy');
    final timeFormat = DateFormat('hh:mm a');
    final statusColor = TripCard.statusColor(trip.status);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Trip Details')),
      body: ListView(
        padding: AegisSpacing.screen,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(dateFormat.format(trip.startedAt), style: AegisText.headline),
              StatusChip(label: trip.status, color: statusColor),
            ],
          ),
          const SizedBox(height: AegisSpacing.lg),

          // Route sketch
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: AegisSpacing.card,
              child: AspectRatio(
                aspectRatio: 1.6,
                child: (_hasStart && _hasDestination)
                    ? CustomPaint(painter: RouteSketchPainter(trip))
                    : Center(
                        child: Text('No route data recorded for this trip.', style: AegisText.bodySecondary),
                      ),
              ),
            ),
          ),
          const SizedBox(height: AegisSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _LegendDot(color: AegisColors.tertiary, label: 'Start'),
              const SizedBox(width: AegisSpacing.lg),
              const _LegendDot(color: AegisColors.secondary, label: 'Last position'),
              const SizedBox(width: AegisSpacing.lg),
              _LegendDot(color: AegisColors.primary, label: 'Destination'),
            ],
          ),
          const SizedBox(height: AegisSpacing.xl),

          const SectionHeader('Summary'),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: AegisSpacing.card,
              child: Column(
                children: [
                  _InfoRow(icon: Icons.play_circle_outline, label: 'Started', value: timeFormat.format(trip.startedAt)),
                  _InfoRow(
                    icon: Icons.flag_outlined,
                    label: 'Ended',
                    value: trip.endedAt != null ? timeFormat.format(trip.endedAt!) : 'In progress',
                  ),
                  _InfoRow(
                    icon: Icons.timer_outlined,
                    label: 'Duration',
                    value: TripCard.durationLabel(trip) ?? 'In progress',
                  ),
                  _InfoRow(icon: Icons.trip_origin, label: 'From', value: TripCard.coordinateLabel(trip.startLocation)),
                  _InfoRow(icon: Icons.location_on_outlined, label: 'To', value: TripCard.coordinateLabel(trip.destination)),
                ],
              ),
            ),
          ),
          const SizedBox(height: AegisSpacing.xl),

          const SectionHeader('Alerts during this trip'),
          if (user == null)
            Text('Sign in to see alerts.', style: AegisText.bodySecondary)
          else
            StreamBuilder<List<AlertModel>>(
              stream: (service ?? ActivityService()).watchAlertsForTrip(user.uid, trip.tripId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Could not load alerts.', style: AegisText.bodySecondary);
                }
                if (!snapshot.hasData) return const LoadingView();
                final alerts = snapshot.data!;
                if (alerts.isEmpty) {
                  return Text('No alerts were raised. Arrived safely.', style: AegisText.bodySecondary);
                }
                return Column(
                  children: alerts
                      .map((a) => AlertBanner(alert: a, onTap: () => AlertDetailSheet.show(context, a)))
                      .toList(),
                );
              },
            ),
          const SizedBox(height: AegisSpacing.xl),

          if (_hasStart && _hasDestination) ...[
            SizedBox(
              width: double.infinity,
              height: AegisSizes.buttonHeight,
              child: ElevatedButton.icon(
                onPressed: () => _openInMaps(context),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Open Route in Maps'),
              ),
            ),
            const SizedBox(height: AegisSpacing.md),
          ],
          if (_hasDestination)
            SizedBox(
              width: double.infinity,
              height: AegisSizes.buttonHeight,
              child: OutlinedButton.icon(
                onPressed: () => _navigateWithCompass(context),
                icon: const Icon(Icons.explore_outlined),
                label: const Text('Point Compass to Destination'),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: AegisSizes.iconMd, color: AegisColors.textSecondary),
          const SizedBox(width: AegisSpacing.md),
          Text(label, style: AegisText.bodySecondary),
          const Spacer(),
          Text(value, style: AegisText.body),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: AegisSpacing.xs),
        Text(label, style: AegisText.small),
      ],
    );
  }
}

/// Draws a simple, map-free sketch of a trip: start -> last position ->
/// destination, scaled to fit the available box.
class RouteSketchPainter extends CustomPainter {
  RouteSketchPainter(this.trip);

  final TripModel trip;

  @override
  void paint(Canvas canvas, Size size) {
    final points = <Offset>[];
    final colors = <Color>[];

    void add(Map<String, double> p, Color c) {
      final lat = p['lat'];
      final lng = p['lng'];
      if (lat == null || lng == null) return;
      points.add(Offset(lng, lat));
      colors.add(c);
    }

    add(trip.startLocation, AegisColors.tertiary);
    if (trip.currentLocation.isNotEmpty && !mapEquals(trip.currentLocation, trip.destination)) {
      add(trip.currentLocation, AegisColors.secondary);
    }
    add(trip.destination, AegisColors.primary);
    if (points.length < 2) return;

    // Fit lng/lat bounds into the canvas, keeping aspect ratio.
    double minX = points.first.dx, maxX = minX, minY = points.first.dy, maxY = minY;
    for (final p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    final spanX = (maxX - minX).abs() < 1e-9 ? 1e-9 : maxX - minX;
    final spanY = (maxY - minY).abs() < 1e-9 ? 1e-9 : maxY - minY;
    const pad = 24.0;
    final scale = [
      (size.width - pad * 2) / spanX,
      (size.height - pad * 2) / spanY,
    ].reduce((a, b) => a < b ? a : b);
    final offsetX = (size.width - spanX * scale) / 2;
    final offsetY = (size.height - spanY * scale) / 2;

    Offset project(Offset p) => Offset(
          offsetX + (p.dx - minX) * scale,
          // Latitude grows northwards, canvas y grows downwards.
          offsetY + (maxY - p.dy) * scale,
        );

    final projected = points.map(project).toList();

    final linePaint = Paint()
      ..color = AegisColors.textSecondary.withValues(alpha: 0.7)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(projected.first.dx, projected.first.dy);
    for (final p in projected.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, linePaint);

    for (var i = 0; i < projected.length; i++) {
      canvas.drawCircle(projected[i], 9, Paint()..color = colors[i].withValues(alpha: 0.25));
      canvas.drawCircle(projected[i], 5, Paint()..color = colors[i]);
    }
  }

  @override
  bool shouldRepaint(covariant RouteSketchPainter oldDelegate) => oldDelegate.trip != trip;
}
