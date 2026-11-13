import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/aegis_theme.dart';

/// Friendly placeholder for empty lists, errors and "sign in required" states,
/// so screens never show a blank view.
class AegisEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final Color iconColor;
  final bool compact;

  const AegisEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.iconColor = AegisColors.textSecondary,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? AegisSpacing.lg : AegisSpacing.xl),
      decoration: BoxDecoration(
        color: AegisColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AegisRadius.xl),
        border: Border.all(color: AegisColors.surfaceContainerHighest),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(compact ? 10 : 16),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: compact ? 28 : 40),
          ),
          SizedBox(height: compact ? AegisSpacing.sm : AegisSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: compact ? 15 : 17,
              fontWeight: FontWeight.bold,
              color: AegisColors.textPrimary,
            ),
          ),
          const SizedBox(height: AegisSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 13, color: AegisColors.textSecondary, height: 1.35),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AegisSpacing.lg),
            FilledButton.icon(
              onPressed: onAction,
              icon: Icon(actionIcon ?? Icons.add, size: 18),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small uppercase section label used across Member 3 screens.
class AegisSectionHeader extends StatelessWidget {
  final String text;
  final Color color;
  final Widget? trailing;

  const AegisSectionHeader(
    this.text, {
    super.key,
    this.color = AegisColors.textSecondary,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AegisSpacing.sm + 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: color,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
