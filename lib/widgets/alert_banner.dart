import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/alert_model.dart';
import '../theme/aegis_theme.dart';

/// A banner/card widget that displays an urgent safety alert.
class AlertBanner extends StatelessWidget {
  /// The alert data to display.
  final AlertModel alert;
  
  /// Callback when the banner is tapped.
  final VoidCallback? onTap;

  const AlertBanner({
    super.key,
    required this.alert,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('hh:mm a');
    
    final bool isManualSos = alert.type.toLowerCase() == 'manual_sos';
    final IconData alertIcon = isManualSos ? Icons.sos : Icons.personal_injury;
    final String alertLabel = isManualSos ? 'Manual SOS' : 'Fall Detected';
    
    final Color alertColor = alert.resolved ? AegisColors.tertiary : Colors.redAccent;

    return Card(
      color: AegisColors.surfaceContainerHigh,
      elevation: 4,
      shadowColor: alertColor.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: alertColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: alertColor, width: 6),
              ),
            ),
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: alertColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    alertIcon,
                    color: alertColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alertLabel,
                        style: GoogleFonts.outfit(
                          color: AegisColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Triggered at ${timeFormat.format(alert.triggeredAt)}',
                        style: GoogleFonts.inter(
                          color: AegisColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: alertColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    alert.resolved ? 'RESOLVED' : 'ACTIVE',
                    style: GoogleFonts.outfit(
                      color: alertColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
