import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/trip_model.dart';
import '../theme/aegis_theme.dart';
import 'state_views.dart';

/// A card that displays summary information about a trip.
///
/// Shows status, start time, date, duration (if ended), and destination.
class TripCard extends StatelessWidget {
  /// The trip data to display.
  final TripModel trip;

  /// Callback when the card is tapped.
  final VoidCallback? onTap;

  const TripCard({
    super.key,
    required this.trip,
    this.onTap,
  });

  /// Colour used for a trip status across the app.
  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return AegisColors.tertiary;
      case 'alerted':
        return AegisColors.primary;
      case 'active':
      default:
        return AegisColors.secondary;
    }
  }

  /// "45m" / "1h 20m", or null while the trip is still running.
  static String? durationLabel(TripModel trip) {
    if (trip.endedAt == null) return null;
    final duration = trip.endedAt!.difference(trip.startedAt);
    if (duration.inMinutes < 60) return '${duration.inMinutes}m';
    return '${duration.inHours}h ${duration.inMinutes % 60}m';
  }

  /// "6.9344, 79.8451" for a {lat, lng} map.
  static String coordinateLabel(Map<String, double> point) {
    final lat = point['lat'];
    final lng = point['lng'];
    if (lat == null || lng == null) return 'Unknown location';
    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');
    final color = statusColor(trip.status);
    final duration = durationLabel(trip);

    return Card(
      margin: AegisSpacing.cardMargin,
      elevation: AegisElevation.low,
      shape: AegisRadius.lgShape,
      child: InkWell(
        onTap: onTap,
        borderRadius: AegisRadius.lgAll,
        child: Padding(
          padding: AegisSpacing.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StatusChip(label: trip.status, color: color),
                  Text(duration ?? 'In progress', style: AegisText.small),
                ],
              ),
              const SizedBox(height: AegisSpacing.md),
              Text('Destination', style: AegisText.small),
              const SizedBox(height: AegisSpacing.xs),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: AegisColors.primary,
                    size: AegisSizes.iconMd,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      coordinateLabel(trip.destination),
                      style: AegisText.bodyStrong,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onTap != null)
                    const Icon(Icons.chevron_right, color: AegisColors.textSecondary),
                ],
              ),
              const SizedBox(height: AegisSpacing.lg),
              const Divider(),
              const SizedBox(height: AegisSpacing.md),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: AegisColors.textSecondary,
                    size: AegisSizes.iconSm,
                  ),
                  const SizedBox(width: 6),
                  Text(dateFormat.format(trip.startedAt), style: AegisText.caption),
                  const SizedBox(width: AegisSpacing.lg),
                  const Icon(
                    Icons.access_time,
                    color: AegisColors.textSecondary,
                    size: AegisSizes.iconSm,
                  ),
                  const SizedBox(width: 6),
                  Text(timeFormat.format(trip.startedAt), style: AegisText.caption),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
