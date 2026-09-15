import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/trip_model.dart';
import '../theme/aegis_theme.dart';

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

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');
    
    Color statusColor;
    switch (trip.status.toLowerCase()) {
      case 'completed':
        statusColor = AegisColors.tertiary;
        break;
      case 'alerted':
        statusColor = Colors.redAccent;
        break;
      case 'active':
      default:
        statusColor = AegisColors.primary;
        break;
    }

    String? durationString;
    if (trip.endedAt != null) {
      final duration = trip.endedAt!.difference(trip.startedAt);
      if (duration.inMinutes < 60) {
        durationString = '${duration.inMinutes}m';
      } else {
        durationString = '${duration.inHours}h ${duration.inMinutes % 60}m';
      }
    }

    return Card(
      color: AegisColors.surfaceContainerHigh,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        trip.status.toUpperCase(),
                        style: GoogleFonts.outfit(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  if (durationString != null)
                    Text(
                      durationString,
                      style: GoogleFonts.inter(
                        color: AegisColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Destination',
                style: GoogleFonts.inter(
                  color: AegisColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: AegisColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Lat: ${trip.destination['lat']?.toStringAsFixed(4)}, Lng: ${trip.destination['lng']?.toStringAsFixed(4)}',
                      style: GoogleFonts.outfit(
                        color: AegisColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: AegisColors.surfaceContainerHighest, height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: AegisColors.textSecondary,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    dateFormat.format(trip.startedAt),
                    style: GoogleFonts.inter(
                      color: AegisColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(
                    Icons.access_time,
                    color: AegisColors.textSecondary,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    timeFormat.format(trip.startedAt),
                    style: GoogleFonts.inter(
                      color: AegisColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
