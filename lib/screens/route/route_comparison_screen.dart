import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../models/hazard_report_model.dart';
import '../../services/route/geo_utils.dart';
import '../../services/route/position_helper.dart';
import '../../services/route/route_planner_service.dart';
import '../../services/route_safety_service.dart';
import '../../theme/aegis_theme.dart';
import '../../widgets/aegis_empty_state.dart';
import 'nearby_hazards_screen.dart';
import 'report_hazard_screen.dart';
import 'widgets/aegis_map.dart';
import 'widgets/hazard_style.dart';
import 'widgets/safety_score_ring.dart';

/// Called when the user picks a route – Member 2 can hook this into the
/// Start Trip flow (destination + route polyline).
typedef RouteChosenCallback = void Function(CandidateRoute route, RouteSafetyScore score);

/// Safe Route: two candidate routes side by side with explainable safety
/// scores (crowd-sourced hazards + OSM street lighting) – Member 3.
class RouteComparisonScreen extends StatefulWidget {
  final RouteChosenCallback? onRouteChosen;

  /// Optional preset destination (skips the "tap the map" step).
  final LatLng? destination;

  const RouteComparisonScreen({super.key, this.onRouteChosen, this.destination});

  @override
  State<RouteComparisonScreen> createState() => _RouteComparisonScreenState();
}

class _RouteComparisonScreenState extends State<RouteComparisonScreen> {
  static const List<Color> _routeColors = [AegisColors.secondary, Color(0xFFB388FF)];

  final RouteSafetyService _safety = RouteSafetyService();
  final RoutePlannerService _planner = RoutePlannerService();
  final MapController _map = MapController();

  LatLng? _origin;
  bool _gpsLive = false;
  String? _gpsReason;
  LatLng? _destination;

  List<CandidateRoute> _routes = const [];
  List<RouteSafetyScore> _scores = const [];
  int _selected = 0;
  bool _loading = false;
  String? _error;
  int _requestId = 0;

  bool get _hasResults => _routes.length == 2 && _scores.length == 2;

  @override
  void initState() {
    super.initState();
    _destination = widget.destination;
    // Don't pop a permission dialog just because the tab was built.
    _locate(requestPermission: false);
  }

  Future<void> _locate({bool requestPermission = true}) async {
    final r = await PositionHelper.current(requestPermission: requestPermission);
    if (!mounted) return;
    setState(() {
      _origin = r.position;
      _gpsLive = r.isLive;
      _gpsReason = r.reason;
    });
    if (_destination != null) _compute();
  }

  void _setDestination(LatLng point) {
    setState(() => _destination = point);
    _compute();
  }

  void _useDemoDestination() {
    final origin = _origin ?? PositionHelper.fallback;
    _setDestination(GeoUtils.offset(origin, northM: 650, eastM: 700));
  }

  Future<void> _compute({bool demo = false}) async {
    final from = _origin, to = _destination;
    if (from == null || to == null) return;
    if (GeoUtils.distanceM(from, to) < 60) {
      setState(() => _error = 'Destination is too close – pick a point further away.');
      return;
    }

    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
      _routes = const [];
      _scores = const [];
      _selected = 0;
    });

    try {
      final routes = demo ? _planner.demoRoutes(from, to) : await _planner.findTwoRoutes(from, to);
      if (!mounted || id != _requestId) return;
      setState(() => _routes = routes);
      _fitToRoutes();

      final scores = await _safety.scoreRoutes(routes);
      if (!mounted || id != _requestId) return;
      setState(() {
        _scores = scores;
        _selected = scores[0].score >= scores[1].score ? 0 : 1;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _loading = false;
        _error = 'Could not get walking routes. Check your internet connection.';
      });
    }
  }

  void _fitToRoutes() {
    final pts = [
      ..._routes.expand((r) => r.points),
      if (_origin != null) _origin!,
      if (_destination != null) _destination!,
    ];
    if (pts.length < 2) return;
    try {
      _map.fitCamera(CameraFit.coordinates(
        coordinates: pts,
        padding: const EdgeInsets.fromLTRB(40, 70, 40, 40),
      ));
    } catch (_) {
      // Map not rendered yet – initial camera is fine.
    }
  }

  void _reset() {
    _requestId++;
    setState(() {
      _destination = null;
      _routes = const [];
      _scores = const [];
      _error = null;
      _loading = false;
    });
    if (_origin != null) _map.move(_origin!, 15);
  }

  void _choose() {
    if (!_hasResults) return;
    final route = _routes[_selected];
    final score = _scores[_selected];
    if (widget.onRouteChosen != null) {
      widget.onRouteChosen!(route, score);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '${route.label} selected · safety ${score.score} · ${route.durationMin} min walk'),
        backgroundColor: AegisColors.tertiaryContainer,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safe Route'),
        actions: [
          IconButton(
            tooltip: 'Nearby hazards',
            icon: const Icon(Icons.map_outlined),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const NearbyHazardsScreen())),
          ),
          IconButton(
            tooltip: 'Report a hazard',
            icon: const Icon(Icons.add_location_alt_outlined, color: AegisColors.primary),
            onPressed: () async {
              final added = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => ReportHazardScreen(initialLocation: _origin)),
              );
              if (added == true && _destination != null) _compute();
            },
          ),
        ],
      ),
      body: _origin == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(flex: 4, child: _buildMap()),
                Expanded(flex: 6, child: _buildPanel()),
              ],
            ),
    );
  }

  Widget _buildMap() {
    final origin = _origin!;
    final Iterable<HazardReportModel> hazards = _hasResults
        ? {for (final s in _scores) for (final h in s.hazards) h.report.id: h.report}.values
        : const <HazardReportModel>[];

    return Stack(
      children: [
        AegisMap(
          controller: _map,
          initialCenter: origin,
          initialZoom: 15,
          onTap: (_, p) => _setDestination(p),
          onMapReady: _fitToRoutes,
          children: [
            PolylineLayer(
              polylines: [
                for (var i = _routes.length - 1; i >= 0; i--)
                  if (i != _selected) _polyline(i, selected: false),
                if (_routes.length > _selected) _polyline(_selected, selected: true),
              ],
            ),
            MarkerLayer(markers: [
              ...hazards.map((h) => Marker(
                    point: LatLng(h.lat, h.lng),
                    width: 24,
                    height: 24,
                    child: HazardPin(category: h.category, size: 24),
                  )),
              Marker(point: origin, width: 26, height: 26, child: const MyLocationDot()),
              if (_destination != null)
                Marker(
                  point: _destination!,
                  width: 34,
                  height: 46,
                  alignment: Alignment.topCenter,
                  child: const DestinationPin(),
                ),
            ]),
          ],
        ),
        Positioned(
          top: AegisSpacing.md,
          left: AegisSpacing.md,
          right: AegisSpacing.md,
          child: _hint(),
        ),
        Positioned(
          right: AegisSpacing.md,
          bottom: AegisSpacing.xl,
          child: Column(
            children: [
              if (_destination != null) ...[
                MapFab(icon: Icons.close, tooltip: 'Clear destination', onPressed: _reset),
                const SizedBox(height: AegisSpacing.sm),
              ],
              MapFab(icon: Icons.my_location, tooltip: 'My location', onPressed: () => _locate()),
            ],
          ),
        ),
      ],
    );
  }

  Polyline _polyline(int i, {required bool selected}) {
    final color = _routeColors[i % _routeColors.length];
    return Polyline(
      points: _routes[i].points,
      strokeWidth: selected ? 6 : 4,
      color: selected ? color : color.withValues(alpha: 0.45),
      borderColor: selected ? Colors.black54 : Colors.transparent,
      borderStrokeWidth: selected ? 2 : 0,
    );
  }

  Widget _hint() {
    final String text;
    final IconData icon;
    Color color = AegisColors.textSecondary;
    if (!_gpsLive) {
      text = '${_gpsReason ?? 'GPS unavailable'} – tap to use GPS';
      icon = Icons.gps_off;
      color = AegisColors.warning;
    } else if (_destination == null) {
      text = 'Tap the map where you want to walk to';
      icon = Icons.touch_app_outlined;
    } else {
      text = 'Tap anywhere to change destination';
      icon = Icons.flag_outlined;
    }
    return GestureDetector(
      onTap: _gpsLive ? null : () => _locate(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AegisSpacing.md, vertical: AegisSpacing.sm),
        decoration: BoxDecoration(
          color: AegisColors.surfaceContainerLow.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(AegisRadius.md),
          border: Border.all(
            color: _gpsLive ? AegisColors.surfaceContainerHighest : color.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: AegisSpacing.sm),
            Expanded(
              child: Text(text,
                  style: GoogleFonts.outfit(fontSize: 12, color: AegisColors.textPrimary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanel() {
    Widget child;
    if (_destination == null) {
      child = ListView(
        padding: const EdgeInsets.all(AegisSpacing.lg),
        children: [
          AegisEmptyState(
            icon: Icons.alt_route,
            iconColor: AegisColors.secondary,
            title: 'Compare two walking routes',
            message: 'Pick a destination on the map. Safe Walk finds two routes and scores each '
                'one using street lighting (OpenStreetMap) and hazards reported by other walkers.',
            actionLabel: 'Try a demo destination',
            actionIcon: Icons.flag_outlined,
            onAction: _useDemoDestination,
          ),
        ],
      );
    } else if (_error != null && !_loading) {
      child = ListView(
        padding: const EdgeInsets.all(AegisSpacing.lg),
        children: [
          AegisEmptyState(
            icon: Icons.wifi_off_rounded,
            iconColor: AegisColors.warning,
            title: 'Routes unavailable',
            message: _error!,
            actionLabel: 'Retry',
            actionIcon: Icons.refresh,
            onAction: () => _compute(),
          ),
          const SizedBox(height: AegisSpacing.md),
          OutlinedButton.icon(
            onPressed: () => _compute(demo: true),
            icon: const Icon(Icons.science_outlined),
            label: const Text('Use offline demo routes'),
          ),
        ],
      );
    } else {
      child = _buildResults();
    }

    return Container(
      decoration: const BoxDecoration(
        color: AegisColors.surfaceContainerLow,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AegisRadius.xxl)),
      ),
      child: child,
    );
  }

  Widget _buildResults() {
    final scoresReady = _hasResults;
    final best = scoresReady ? (_scores[0].score >= _scores[1].score ? 0 : 1) : -1;

    return ListView(
      padding: const EdgeInsets.fromLTRB(AegisSpacing.lg, AegisSpacing.lg, AegisSpacing.lg, AegisSpacing.xl),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _loading && _routes.isEmpty
                    ? 'Finding walking routes…'
                    : _loading
                        ? 'Scoring safety…'
                        : 'Pick the route you feel safest on',
                style: GoogleFonts.outfit(
                    fontSize: 16, fontWeight: FontWeight.bold, color: AegisColors.textPrimary),
              ),
            ),
            if (_routes.isNotEmpty && _routes.first.isDemo)
              const Chip(label: Text('DEMO'), visualDensity: VisualDensity.compact),
          ],
        ),
        const SizedBox(height: AegisSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < 2; i++) ...[
              if (i == 1) const SizedBox(width: AegisSpacing.md),
              Expanded(
                child: _RouteOptionCard(
                  label: i == 0 ? 'Route A' : 'Route B',
                  color: _routeColors[i],
                  route: i < _routes.length ? _routes[i] : null,
                  score: scoresReady ? _scores[i] : null,
                  selected: _selected == i,
                  recommended: best == i && _scores[0].score != _scores[1].score,
                  onTap: _routes.length > i ? () => setState(() => _selected = i) : null,
                ),
              ),
            ],
          ],
        ),
        if (scoresReady) ...[
          const SizedBox(height: AegisSpacing.lg),
          _ScoreExplanation(
            route: _routes[_selected],
            score: _scores[_selected],
            color: _routeColors[_selected],
          ),
          const SizedBox(height: AegisSpacing.lg),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _choose,
              icon: const Icon(Icons.directions_walk),
              label: Text('Walk ${_routes[_selected].label}'),
            ),
          ),
        ],
      ],
    );
  }
}

class _RouteOptionCard extends StatelessWidget {
  final String label;
  final Color color;
  final CandidateRoute? route;
  final RouteSafetyScore? score;
  final bool selected;
  final bool recommended;
  final VoidCallback? onTap;

  const _RouteOptionCard({
    required this.label,
    required this.color,
    required this.route,
    required this.score,
    required this.selected,
    required this.recommended,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = score;
    final r = route;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.12) : AegisColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AegisRadius.xl),
        border: Border.all(
          color: selected ? color : AegisColors.surfaceContainerHighest,
          width: selected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AegisRadius.xl),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AegisSpacing.md),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(label,
                          style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold, color: AegisColors.textPrimary)),
                    ),
                    if (recommended)
                      const Icon(Icons.verified, color: AegisColors.tertiary, size: 18),
                  ],
                ),
                const SizedBox(height: AegisSpacing.md),
                SafetyScoreRing(score: s?.score, size: 78),
                const SizedBox(height: AegisSpacing.sm),
                Text(
                  s == null ? '…' : (recommended ? 'Safer choice' : s.rating),
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: s == null ? AegisColors.textSecondary : AegisColors.forScore(s.score),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  r == null ? '—' : '${r.durationMin} min · ${r.distanceLabel}',
                  style: GoogleFonts.outfit(fontSize: 12, color: AegisColors.textSecondary),
                ),
                if (s != null) ...[
                  const SizedBox(height: AegisSpacing.md),
                  SubScoreBar(label: 'Lighting', value: s.lightingScore, icon: Icons.lightbulb_outline),
                  const SizedBox(height: AegisSpacing.sm),
                  SubScoreBar(
                    label: s.hazards.isEmpty ? 'No hazards' : '${s.hazards.length} hazard${s.hazards.length == 1 ? '' : 's'}',
                    value: s.hazardScore,
                    icon: Icons.warning_amber_rounded,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreExplanation extends StatelessWidget {
  final CandidateRoute route;
  final RouteSafetyScore score;
  final Color color;

  const _ScoreExplanation({required this.route, required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AegisColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AegisRadius.lg),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          iconColor: AegisColors.textSecondary,
          collapsedIconColor: AegisColors.textSecondary,
          leading: Icon(Icons.insights_outlined, color: color),
          title: Text('Why ${route.label} scores ${score.score}',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AegisColors.textPrimary)),
          childrenPadding: const EdgeInsets.fromLTRB(AegisSpacing.lg, 0, AegisSpacing.lg, AegisSpacing.lg),
          children: [
            ...score.explanation.map((line) => Padding(
                  padding: const EdgeInsets.only(bottom: AegisSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Icon(Icons.circle, size: 6, color: AegisColors.textSecondary),
                      ),
                      const SizedBox(width: AegisSpacing.sm),
                      Expanded(
                        child: Text(line,
                            style: GoogleFonts.outfit(fontSize: 13, color: AegisColors.textPrimary)),
                      ),
                    ],
                  ),
                )),
            if (score.hazards.isNotEmpty) ...[
              const SizedBox(height: AegisSpacing.xs),
              ...score.hazards.take(4).map((h) => Padding(
                    padding: const EdgeInsets.only(bottom: AegisSpacing.xs),
                    child: Row(
                      children: [
                        HazardPin(category: h.report.category, size: 20),
                        const SizedBox(width: AegisSpacing.sm),
                        Expanded(
                          child: Text(
                            '${h.report.categoryInfo.label} · ${h.distanceM.round()} m off route · ${timeAgo(h.report.reportedAt)}',
                            style: GoogleFonts.outfit(fontSize: 12, color: AegisColors.textSecondary),
                          ),
                        ),
                        Text('−${(h.weight * RouteSafetyScorer.pointsPerHazard).round()}',
                            style: GoogleFonts.outfit(
                                fontSize: 12, fontWeight: FontWeight.bold, color: AegisColors.danger)),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}
