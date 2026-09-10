import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/route_safety_service.dart';
import '../../theme/aegis_theme.dart';

class RouteComparisonScreen extends StatelessWidget {
  const RouteComparisonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final routeAScore = RouteSafetyService.calculateSafetyScore(hazardCount: 0, lightingRatio: 0.8).round();
    final routeBScore = RouteSafetyService.calculateSafetyScore(hazardCount: 2, lightingRatio: 0.2).round();

    return Scaffold(
      backgroundColor: AegisColors.background,
      appBar: AppBar(title: Text("Route Safety Scoring", style: GoogleFonts.outfit(fontWeight: FontWeight.bold))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildRouteCard(
              title: "Route A: 5th Ave Corridor",
              score: "$routeAScore%",
              duration: "14 min (1.1 km)",
              lighting: "100% Smart-Lit",
              hazards: "0 Reported",
              isRecommended: true,
            ),
            const SizedBox(height: 16),
            _buildRouteCard(
              title: "Route B: Back Alley Cut-through",
              score: "$routeBScore%",
              duration: "10 min (0.8 km)",
              lighting: "45% Poor Lighting",
              hazards: "2 Hazards Reported",
              isRecommended: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteCard({
    required String title,
    required String score,
    required String duration,
    required String lighting,
    required String hazards,
    required bool isRecommended,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AegisColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: isRecommended ? Border.all(color: AegisColors.tertiary, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AegisColors.textPrimary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isRecommended ? AegisColors.tertiaryContainer : AegisColors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "Safety $score",
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: isRecommended ? Colors.white : AegisColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(duration, style: GoogleFonts.outfit(color: AegisColors.textSecondary)),
          const Divider(color: AegisColors.surfaceContainerHighest, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(lighting, style: GoogleFonts.outfit(fontSize: 12, color: AegisColors.tertiary)),
              Text(hazards, style: GoogleFonts.outfit(fontSize: 12, color: AegisColors.secondary)),
            ],
          ),
        ],
      ),
    );
  }
}
