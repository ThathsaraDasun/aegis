import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/aegis_theme.dart';

/// Circular 0–100 safety gauge.
class SafetyScoreRing extends StatelessWidget {
  final int? score; // null → loading
  final double size;

  const SafetyScoreRing({super.key, required this.score, this.size = 72});

  @override
  Widget build(BuildContext context) {
    final s = score;
    final color = s == null ? AegisColors.textSecondary : AegisColors.forScore(s);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (s ?? 0) / 100),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => CircularProgressIndicator(
                value: s == null ? null : value,
                strokeWidth: size * 0.09,
                strokeCap: StrokeCap.round,
                color: color,
                backgroundColor: AegisColors.surfaceContainerHighest,
              ),
            ),
          ),
          if (s != null)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$s',
                  style: GoogleFonts.outfit(
                    fontSize: size * 0.32,
                    fontWeight: FontWeight.bold,
                    color: AegisColors.textPrimary,
                    height: 1,
                  ),
                ),
                Text(
                  'SAFETY',
                  style: GoogleFonts.outfit(
                    fontSize: size * 0.11,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w600,
                    color: AegisColors.textSecondary,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Thin labelled bar for a sub-score (lighting / hazards).
class SubScoreBar extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;

  const SubScoreBar({super.key, required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final color = AegisColors.forScore(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Expanded(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(fontSize: 11, color: AegisColors.textSecondary)),
            ),
            Text('$value',
                style: GoogleFonts.outfit(
                    fontSize: 11, fontWeight: FontWeight.bold, color: AegisColors.textPrimary)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value / 100,
            minHeight: 5,
            color: color,
            backgroundColor: AegisColors.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}
