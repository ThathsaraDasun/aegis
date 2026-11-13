import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/alert_model.dart';
import '../../services/activity_service.dart';
import '../../theme/aegis_theme.dart';
import '../../widgets/alert_banner.dart';
import '../../widgets/state_views.dart';
import '../../widgets/trip_card.dart';

/// Bottom sheet with the full record of one SOS / fall alert:
/// type, time, location and outcome (resolved / escalated).
class AlertDetailSheet extends StatelessWidget {
  const AlertDetailSheet({super.key, required this.alert});

  final AlertModel alert;

  static Future<void> show(BuildContext context, AlertModel alert) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AlertDetailSheet(alert: alert),
    );
  }

  Future<void> _openLocation(BuildContext context) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${alert.location['lat']},${alert.location['lng']}',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open a maps app on this device.')),
      );
    }
  }

  Future<void> _markResolved(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    try {
      await ActivityService().resolveAlert(alert.alertId);
      messenger.showSnackBar(const SnackBar(content: Text('Alert marked as resolved.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not update alert: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('EEE, MMM dd yyyy · hh:mm a');
    final color = AlertBanner.outcomeColor(alert);
    final hasLocation = alert.location.containsKey('lat') && alert.location.containsKey('lng');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AegisSpacing.xxl,
          AegisSpacing.xxl,
          AegisSpacing.xxl,
          AegisSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(AlertBanner.iconFor(alert), color: color, size: AegisSizes.iconLg),
                const SizedBox(width: AegisSpacing.md),
                Expanded(child: Text(alert.typeLabel, style: AegisText.headline)),
                StatusChip(label: alert.outcome, color: color),
              ],
            ),
            const SizedBox(height: AegisSpacing.xl),
            _row('Triggered', format.format(alert.triggeredAt)),
            _row('Location', TripCard.coordinateLabel(alert.location)),
            _row('Trip', alert.tripId.isEmpty ? 'Not linked to a trip' : alert.tripId),
            _row(
              'Outcome',
              alert.resolved
                  ? 'Resolved. The user confirmed they were safe.'
                  : 'Escalated. Trusted contacts were alerted.',
            ),
            const SizedBox(height: AegisSpacing.xl),
            if (hasLocation)
              SizedBox(
                width: double.infinity,
                height: AegisSizes.buttonHeight,
                child: OutlinedButton.icon(
                  onPressed: () => _openLocation(context),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('View Location in Maps'),
                ),
              ),
            if (!alert.resolved) ...[
              const SizedBox(height: AegisSpacing.md),
              SizedBox(
                width: double.infinity,
                height: AegisSizes.buttonHeight,
                child: ElevatedButton.icon(
                  onPressed: () => _markResolved(context),
                  style: ElevatedButton.styleFrom(backgroundColor: AegisColors.tertiary),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Mark as Resolved'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: AegisText.bodySecondary)),
          Expanded(child: Text(value, style: AegisText.body)),
        ],
      ),
    );
  }
}
