import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/alert_service.dart';
import '../../theme/aegis_theme.dart';

class TripSummaryScreen extends StatelessWidget {
  final String tripId;
  final bool arrivedSafely;
  final Duration? duration;
  final String? destinationName;

  /// True when the trip end is saved on the phone but not yet confirmed by
  /// the server (slow or no connection); it uploads automatically later.
  final bool syncPending;

  /// Last known position, included in the guardian message when the trip
  /// ended without the walker confirming arrival.
  final double? lastLat;
  final double? lastLng;

  const TripSummaryScreen({
    super.key,
    required this.tripId,
    required this.arrivedSafely,
    this.duration,
    this.destinationName,
    this.syncPending = false,
    this.lastLat,
    this.lastLng,
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
    final timeLabel = duration != null ? _formatDuration(duration!) : null;

    return Scaffold(
      backgroundColor: AegisColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
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
                    color: AegisColors.textPrimary,
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
                if (syncPending) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Saved on this phone. It will sync to your account when the connection is back.',
                    style: GoogleFonts.outfit(
                      color: AegisColors.textSecondary,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 20),
                _TripEndGuardianCard(
                  tripId: tripId,
                  arrivedSafely: arrivedSafely,
                  lastLat: lastLat,
                  lastLng: lastLng,
                ),
                if (destinationName != null || timeLabel != null) ...[
                  const SizedBox(height: 28),
                  Container(
                    decoration: BoxDecoration(
                      color: AegisColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(AegisRadius.xl),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
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
                            height: 20,
                          ),
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

/// Tells guardians the trip has ended: sent automatically when automatic SMS
/// is on, otherwise offered as SMS / WhatsApp buttons.
class _TripEndGuardianCard extends StatefulWidget {
  final String tripId;
  final bool arrivedSafely;
  final double? lastLat;
  final double? lastLng;
  const _TripEndGuardianCard({
    required this.tripId,
    required this.arrivedSafely,
    this.lastLat,
    this.lastLng,
  });

  @override
  State<_TripEndGuardianCard> createState() => _TripEndGuardianCardState();
}

class _TripEndGuardianCardState extends State<_TripEndGuardianCard> {
  late final Future<TripStartShare?> _share = _prepare();

  Future<TripStartShare?> _prepare() async {
    if (Firebase.apps.isEmpty) return null;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    try {
      return await AlertService.instance
          .prepareTripEndShare(
            userId: uid,
            tripId: widget.tripId,
            arrivedSafely: widget.arrivedSafely,
            lat: widget.lastLat,
            lng: widget.lastLng,
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      return null;
    }
  }

  Future<void> _sms(TripStartShare share) async {
    final opened = await AlertService.instance.openTripStartSms(share);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open your SMS app.')),
      );
    }
  }

  Future<void> _whatsApp(TripStartShare share) async {
    final links = share.whatsAppLinks;
    if (links.length == 1) {
      await launchUrl(links.first.uri, mode: LaunchMode.externalApplication);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(
              'Send on WhatsApp',
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            for (final link in links)
              ListTile(
                leading: const Icon(
                  Icons.chat_outlined,
                  color: AegisColors.azure,
                ),
                title: Text(link.name),
                onTap: () {
                  Navigator.of(sheet).pop();
                  launchUrl(link.uri, mode: LaunchMode.externalApplication);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<TripStartShare?>(
    future: _share,
    builder: (context, snapshot) {
      final share = snapshot.data;
      final waiting = snapshot.connectionState != ConnectionState.done;
      final String detail;
      if (waiting) {
        detail = 'Preparing a message for your guardians…';
      } else if (share == null) {
        detail =
            'Could not prepare the message (check internet). Let your guardians know you have ended your walk.';
      } else if (share.contactCount == 0) {
        detail = 'No guardians saved, so no message was prepared.';
      } else if (share.sentAutomatically) {
        detail = share.automaticSmsMessage!;
      } else {
        detail = widget.arrivedSafely
            ? 'Let your guardians know you arrived safely.'
            : 'Let your guardians know your walk ended without confirming arrival.';
      }
      final canSend =
          share != null && share.contactCount > 0 && !share.sentAutomatically;
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AegisColors.surfaceContainerHigh),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.mark_chat_read_outlined,
                  color: AegisColors.azure,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tell your guardians',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AegisColors.textPrimary,
                    ),
                  ),
                ),
                if (waiting)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AegisColors.textSecondary,
              ),
            ),
            if (canSend) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _sms(share),
                      icon: const Icon(Icons.sms_outlined, size: 18),
                      label: const Text('Notify by SMS'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AegisColors.azure,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                  if (share.whatsAppLinks.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _whatsApp(share),
                        icon: const Icon(Icons.chat_outlined, size: 18),
                        label: const Text('WhatsApp'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AegisColors.azure,
                          side: const BorderSide(color: AegisColors.azure),
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      );
    },
  );
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
