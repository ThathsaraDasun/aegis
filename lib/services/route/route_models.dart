import 'package:latlong2/latlong.dart';

import '../../models/hazard_report_model.dart';
import 'geo_utils.dart';

/// A walkable route option returned by the route planner.
class CandidateRoute {
  final String label; // "Route A", "Route B"
  final List<LatLng> points;
  final double distanceM;
  final double durationS;

  /// True when the route is synthetic demo data (no network / no router).
  final bool isDemo;

  const CandidateRoute({
    required this.label,
    required this.points,
    required this.distanceM,
    required this.durationS,
    this.isDemo = false,
  });

  double get distanceKm => distanceM / 1000.0;
  int get durationMin => (durationS / 60).round().clamp(1, 100000);

  String get distanceLabel => distanceM >= 1000
      ? '${distanceKm.toStringAsFixed(1)} km'
      : '${distanceM.round()} m';
}

/// Street-lighting summary from OpenStreetMap `lit=*` tags along a route.
class LightingSummary {
  /// Ways tagged lit=yes (or 24/7, automatic, limited, interval…).
  final int litWays;

  /// Ways tagged lit=no / disused.
  final int unlitWays;

  /// Highway ways near the route with no `lit` tag at all.
  final int unknownWays;

  /// False when Overpass could not be reached.
  final bool available;

  const LightingSummary({
    required this.litWays,
    required this.unlitWays,
    required this.unknownWays,
    this.available = true,
  });

  const LightingSummary.unavailable()
      : litWays = 0,
        unlitWays = 0,
        unknownWays = 0,
        available = false;

  int get taggedWays => litWays + unlitWays;
  int get totalWays => taggedWays + unknownWays;

  /// Fraction of *tagged* ways that are lit, or null if nothing is tagged.
  double? get litRatio => taggedWays == 0 ? null : litWays / taggedWays;
}

/// A hazard that sits close to a route, with its contribution to the score.
class NearbyHazard {
  final HazardReportModel report;
  final double distanceM;
  final double weight;

  const NearbyHazard({
    required this.report,
    required this.distanceM,
    required this.weight,
  });
}

/// Explainable safety score for one route.
class RouteSafetyScore {
  /// 0–100, higher is safer.
  final int score;

  /// 0–100 sub-score from OSM street lighting.
  final int lightingScore;

  /// 0–100 sub-score from crowd-sourced hazard reports.
  final int hazardScore;

  final LightingSummary lighting;
  final List<NearbyHazard> hazards;
  final double hazardPenalty;

  const RouteSafetyScore({
    required this.score,
    required this.lightingScore,
    required this.hazardScore,
    required this.lighting,
    required this.hazards,
    required this.hazardPenalty,
  });

  String get rating {
    if (score >= 75) return 'Safe';
    if (score >= 50) return 'Moderate';
    return 'Risky';
  }

  /// Human-readable reasons, shown in the "Why this score?" panel.
  List<String> get explanation {
    final ratio = lighting.litRatio;
    final lines = <String>[];
    if (!lighting.available) {
      lines.add('Street-lighting data unavailable (offline) – neutral 50 used.');
    } else if (ratio == null) {
      lines.add('No OSM lighting tags on ${lighting.totalWays} nearby streets – neutral 50 used.');
    } else {
      lines.add(
          '${(ratio * 100).round()}% of tagged streets are lit (${lighting.litWays}/${lighting.taggedWays} OSM ways).');
    }
    if (hazards.isEmpty) {
      lines.add('No hazard reports within ${RouteSafetyScorer.hazardBufferM.round()} m of this route.');
    } else {
      final byCat = <String, int>{};
      for (final h in hazards) {
        final label = h.report.categoryInfo.label;
        byCat[label] = (byCat[label] ?? 0) + 1;
      }
      final summary = byCat.entries.map((e) => '${e.value}× ${e.key}').join(', ');
      lines.add('${hazards.length} hazard report(s) nearby: $summary.');
    }
    lines.add(
        'Score = ${(RouteSafetyScorer.hazardShare * 100).round()}% hazards ($hazardScore) + '
        '${((1 - RouteSafetyScorer.hazardShare) * 100).round()}% lighting ($lightingScore).');
    return lines;
  }
}

/// Pure scoring logic – no I/O, fully unit-testable.
class RouteSafetyScorer {
  RouteSafetyScorer._();

  /// Hazards further than this from the route line are ignored.
  static const double hazardBufferM = 40;

  /// Weight of the hazard sub-score in the final score.
  static const double hazardShare = 0.6;

  /// Points removed from the hazard sub-score per 1.0 of weighted hazard.
  static const double pointsPerHazard = 15;

  static int lightingScoreFrom(LightingSummary lighting) {
    final ratio = lighting.litRatio;
    if (!lighting.available || ratio == null) return 50;
    return (ratio * 100).round().clamp(0, 100);
  }

  /// Weight of a single report: category weight, boosted by confirmations
  /// (max ×2) and halved once the report is older than 30 days.
  static double hazardWeight(HazardReportModel report, {DateTime? now}) {
    final base = report.categoryInfo.weight;
    final confirms = (report.confirmCount - 1).clamp(0, 4);
    final confirmBoost = 1 + confirms * 0.25;
    final age = (now ?? DateTime.now()).difference(report.reportedAt);
    final recency = age.inDays > 30 ? 0.5 : 1.0;
    return base * confirmBoost * recency;
  }

  static RouteSafetyScore score({
    required List<LatLng> route,
    required List<HazardReportModel> hazards,
    required LightingSummary lighting,
    DateTime? now,
  }) {
    final nearby = <NearbyHazard>[];
    for (final h in hazards) {
      final d = _distanceToRoute(h, route);
      if (d <= hazardBufferM) {
        nearby.add(NearbyHazard(report: h, distanceM: d, weight: hazardWeight(h, now: now)));
      }
    }
    nearby.sort((a, b) => b.weight.compareTo(a.weight));

    final penalty = nearby.fold<double>(0, (sum, h) => sum + h.weight);
    final hazardScore = (100 - penalty * pointsPerHazard).round().clamp(0, 100);
    final lightingScore = lightingScoreFrom(lighting);
    final total =
        (hazardShare * hazardScore + (1 - hazardShare) * lightingScore).round().clamp(0, 100);

    return RouteSafetyScore(
      score: total,
      lightingScore: lightingScore,
      hazardScore: hazardScore,
      lighting: lighting,
      hazards: nearby,
      hazardPenalty: penalty,
    );
  }

  static double _distanceToRoute(HazardReportModel h, List<LatLng> route) =>
      GeoUtils.distanceToPathM(LatLng(h.lat, h.lng), route);
}
