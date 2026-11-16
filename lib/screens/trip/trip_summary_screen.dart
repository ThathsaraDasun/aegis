import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/aegis_theme.dart';

class TripSummaryScreen extends StatelessWidget {
  final String tripId;
  final bool arrivedSafely;
  final Duration? duration;
  final String? destinationName;

  const TripSummaryScreen({
    super.key,
    required this.tripId,
    required this.arrivedSafely,
    this.duration,
    this.destinationName,
  });

  String _formatDuration(Duration d) {
    if (d.inMinutes < 1) return 'Less than 1 min';
    if (d.inHours < 1) return '${d.inMinutes} min';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final timeLabel =
        duration != null ? _formatDuration(duration!) : null;

    return Scaffold(
      backgroundColor: AegisColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  arrivedSafely
                      ? Icons.verified_user
                      : Icons.warning_amber_rounded,
                  size: 100,
                  color: arrivedSafely
                      ? AegisColors.tertiary
                      : AegisColors.primary,
                ),
                const SizedBox(height: 32),
                Text(
                  arrivedSafely ? 'Arrived Safely!' : 'Trip Ended',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  arrivedSafely
                      ? 'Your safe arrival has been recorded.'
                      : 'The trip was ended automatically due to a timeout. If you are in danger, use the SOS features.',
                  style: GoogleFonts.outfit(
                    color: AegisColors.textSecondary,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (destinationName != null || timeLabel != null) ...[
                  const SizedBox(height: 28),
                  Container(
                    decoration: BoxDecoration(
                      color: AegisColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(AegisRadius.xl),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    child: Column(
                      children: [
                        if (destinationName != null)
                          _StatRow(
                            icon: Icons.location_pin,
                            iconColor: AegisColors.primary,
                            label: 'Destination',
                            value: destinationName!,
                          ),
                        if (destinationName != null && timeLabel != null)
                          const Divider(
                              color: AegisColors.surfaceContainerHighest,
                              height: 20),
                        if (timeLabel != null)
                          _StatRow(
                            icon: Icons.timer_outlined,
                            iconColor: AegisColors.secondary,
                            label: 'Duration',
                            value: timeLabel,
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.popUntil(context, (route) => route.isFirst),
                    child: const Text('RETURN HOME'),
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  'Trip ID: $tripId',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: AegisColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  const _StatRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: AegisColors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: AegisColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      );
}
