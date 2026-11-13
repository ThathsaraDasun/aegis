import 'package:flutter/material.dart';

import '../../../models/hazard_report_model.dart';
import '../../../theme/aegis_theme.dart';

/// Icon + colour for each hazard category.
class HazardStyle {
  final IconData icon;
  final Color color;

  const HazardStyle(this.icon, this.color);

  static HazardStyle of(String categoryKey) {
    switch (HazardCategory.normalizeKey(categoryKey)) {
      case 'poor_lighting':
        return const HazardStyle(Icons.lightbulb_outline, AegisColors.warning);
      case 'unsafe_area':
        return const HazardStyle(Icons.warning_amber_rounded, AegisColors.primary);
      case 'past_incident':
        return const HazardStyle(Icons.report_gmailerrorred, AegisColors.danger);
      case 'no_sidewalk':
        return const HazardStyle(Icons.directions_walk, AegisColors.secondary);
      default:
        return const HazardStyle(Icons.more_horiz, AegisColors.textSecondary);
    }
  }
}

/// Round map pin for a hazard report.
class HazardPin extends StatelessWidget {
  final String category;
  final double size;
  final bool highlighted;

  const HazardPin({super.key, required this.category, this.size = 30, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    final style = HazardStyle.of(category);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: style.color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: highlighted ? 3 : 2),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
      ),
      child: Icon(style.icon, color: Colors.white, size: size * 0.55),
    );
  }
}

/// "5m ago", "3h ago", "2d ago".
String timeAgo(DateTime t, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 30) return '${d.inDays}d ago';
  return '${(d.inDays / 30).floor()}mo ago';
}
