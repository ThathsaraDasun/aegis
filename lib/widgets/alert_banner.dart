import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/alert_model.dart';
import '../theme/aegis_theme.dart';
import 'state_views.dart';

/// A banner/card widget that displays a safety alert and its outcome.
class AlertBanner extends StatelessWidget {
  /// The alert data to display.
  final AlertModel alert;

  /// Callback when the banner is tapped.
  final VoidCallback? onTap;

  const AlertBanner({super.key, required this.alert, this.onTap});

  /// Colour for an alert outcome: green when resolved, orange when unresolved.
  static Color outcomeColor(AlertModel alert) =>
      alert.resolved ? AegisColors.tertiary : AegisColors.primary;

  /// Icon for the alert type.
  static IconData iconFor(AlertModel alert) =>
      alert.type.toLowerCase() == 'manual_sos'
      ? Icons.sos
      : Icons.personal_injury;

  @override
  Widget build(BuildContext context) {
    final dateTimeFormat = DateFormat('MMM dd, hh:mm a');
    final Color alertColor = outcomeColor(alert);

    return Card(
      margin: AegisSpacing.cardMargin,
      elevation: AegisElevation.medium,
      shadowColor: alertColor.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: AegisRadius.lgAll,
        side: BorderSide(color: alertColor.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AegisRadius.lgAll,
        child: ClipRRect(
          borderRadius: AegisRadius.lgAll,
          child: Container(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: alertColor, width: 6)),
            ),
            padding: AegisSpacing.card,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: alertColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    iconFor(alert),
                    color: alertColor,
                    size: AegisSizes.iconLg,
                  ),
                ),
                const SizedBox(width: AegisSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alert.typeLabel, style: AegisText.title),
                      const SizedBox(height: AegisSpacing.xs),
                      Text(
                        'Triggered ${dateTimeFormat.format(alert.triggeredAt)}',
                        style: AegisText.caption,
                      ),
                    ],
                  ),
                ),
                StatusChip(label: alert.outcome, color: alertColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
