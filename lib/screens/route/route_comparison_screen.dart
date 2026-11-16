import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/hazard_report_model.dart';
import '../../screens/trip/destination_search_sheet.dart';
import '../../screens/trip/start_trip_screen.dart';
import '../../services/destination_search_service.dart';
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
typedef RouteChosenCallback =
    void Function(CandidateRoute route, RouteSafetyScore score);

/// Safe Route: live OpenStreetMap map + two candidate walking routes side by side with
/// explainable safety scores (crowd-sourced hazards + OSM street lighting).
class RouteComparisonScreen extends StatefulWidget {
  final RouteChosenCallback? onRouteChosen;

  /// Optional preset destination (skips the "pick a place" step).
  final LatLng? destination;

  const RouteComparisonScreen({
    super.key,
    this.onRouteChosen,
    this.destination,
  });

  @override
  State<RouteComparisonScreen> createState() => _RouteComparisonScreenState();
}

class _RouteComparisonScreenState extends State<RouteComparisonScreen> {
  static const List<Color> _routeColors = [
    AegisColors.primary,
    AegisColors.accent,
  ];

  final RouteSafetyService _safety = RouteSafetyService();
  final RoutePlannerService _planner = RoutePlannerService();
  final MapController _map = MapController();
  bool _mapReady = false;

  /// Which route line (if any) is under the finger – lets users tap a line to select it.
  final LayerHitNotifier<int> _routeHit = ValueNotifier(null);

  LatLng? _origin;
  bool _gpsLive = false;
  bool _locating = false;
  String? _gpsReason;
  LatLng? _destination;
  String? _destinationName;

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

  @override
  void dispose() {
    _routeHit.dispose();
    _map.dispose();
    super.dispose();
  }

  Future<void> _locate({bool requestPermission = true}) async {
    if (_locating) return;
    setState(() => _locating = true);
    final r = await PositionHelper.current(
      requestPermission: requestPermission,
    );
    if (!mounted) return;
    setState(() {
      _origin = r.position;
      _gpsLive = r.isLive;
      _gpsReason = r.reason;
      _locating = false;
    });
    if (_destination != null) {
      _compute();
    } else {
      _moveCamera(r.position, 16);
    }
  }

  void _moveCamera(LatLng target, double zoom) {
    if (!_mapReady) return;
    _map.move(target, zoom);
  }

  void _setDestination(LatLng point, {String? name}) {
    setState(() {
      _destination = point;
      _destinationName = name;
    });
    _compute();
  }

  Future<void> _searchDestination() async {
    final place = await showModalBottomSheet<DestinationPlace>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.85,
        child: DestinationSearchSheet(),
      ),
    );
    if (!mounted || place == null) return;
    _setDestination(place.position, name: place.name);
  }

  Future<void> _compute() async {
    final from = _origin, to = _destination;
    if (from == null || to == null) return;
    final id = ++_requestId;
    if (GeoUtils.distanceM(from, to) < 60) {
      setState(() {
        _loading = false;
        _routes = const [];
        _scores = const [];
        _error =
            'That place is very close to you – pick somewhere further away.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _routes = const [];
      _scores = const [];
      _selected = 0;
    });

    try {
      final routes = await _planner
          .findTwoRoutes(from, to)
          .timeout(const Duration(seconds: 30));
      if (!mounted || id != _requestId) return;
      setState(() => _routes = routes);
      _fitToRoutes();

      final scores = await _safety
          .scoreRoutes(routes)
          .timeout(const Duration(seconds: 36));
      if (!mounted || id != _requestId) return;
      setState(() {
        _scores = scores;
        _selected = scores.every((s) => s.hasLightingData)
            ? (scores[0].score >= scores[1].score ? 0 : 1)
            : 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _loading = false;
        _error = e is SafetyDataUnavailable
            ? e.message
            : _routes.isEmpty
            ? 'Could not get walking routes. Check your internet connection and try again.'
            : 'Safety data unavailable. Hazard reports or street-lighting data could not be loaded in time. No safety rating has been assigned. Check your connection and try again.';
      });
    }
  }

  void _fitToRoutes() {
    final pts = <LatLng>[
      ..._routes.expand((r) => r.points),
      ?_origin,
      ?_destination,
    ];
    if (pts.length < 2 || !_mapReady) return;
    try {
      _map.fitCamera(
        CameraFit.coordinates(
          coordinates: pts,
          padding: const EdgeInsets.fromLTRB(48, 90, 72, 48),
        ),
      );
    } catch (_) {
      // Map not laid out yet – the initial camera is fine.
    }
  }

  void _reset() {
    _requestId++;
    setState(() {
      _destination = null;
      _destinationName = null;
      _routes = const [];
      _scores = const [];
      _error = null;
      _loading = false;
    });
    if (_origin != null) _moveCamera(_origin!, 16);
  }

  void _choose() {
    if (_routes.length != 2 || _loading) return;
    final route = _routes[_selected];
    if (widget.onRouteChosen != null) {
      if (!_hasResults) return;
      widget.onRouteChosen!(route, _scores[_selected]);
      return;
    }
    // Navigate to StartTripScreen with the chosen destination and route pre-filled.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StartTripScreen(
          presetDestination: _destination!,
          presetDestinationName: _destinationName,
          presetRoutePoints: route.points,
        ),
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
              context,
              MaterialPageRoute(builder: (_) => const NearbyHazardsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Report a hazard',
            icon: const Icon(
              Icons.add_location_alt_outlined,
              color: AegisColors.primary,
            ),
            onPressed: () async {
              final added = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => ReportHazardScreen(initialLocation: _origin),
                ),
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
                Expanded(flex: 6, child: _buildMap()),
                Expanded(flex: 4, child: _buildPanel()),
              ],
            ),
    );
  }

  Widget _buildMap() {
    final origin = _origin!;
    final Iterable<HazardReportModel> hazards = _hasResults
        ? {
            for (final s in _scores)
              for (final h in s.hazards) h.report.id: h.report,
          }.values
        : const <HazardReportModel>[];

    return Stack(
      children: [
        AegisMap(
          controller: _map,
          initialCenter: origin,
          initialZoom: 16,
          onMapReady: () {
            _mapReady = true;
            if (_routes.isNotEmpty) _fitToRoutes();
          },
          onTap: (_, p) {
            final hit = _routeHit.value;
            if (hit != null && hit.hitValues.isNotEmpty) {
              setState(() => _selected = hit.hitValues.first);
            } else {
              _setDestination(p);
            }
          },
          children: [
            PolylineLayer<int>(
              hitNotifier: _routeHit,
              polylines: [
                for (var i = _routes.length - 1; i >= 0; i--)
                  if (i != _selected) _polyline(i, selected: false),
                if (_routes.length > _selected)
                  _polyline(_selected, selected: true),
              ],
            ),
            MarkerLayer(
              markers: [
                ...hazards.map(
                  (h) => Marker(
                    point: LatLng(h.lat, h.lng),
                    width: 26,
                    height: 26,
                    child: Tooltip(
                      message:
                          '${h.categoryInfo.label} · ${timeAgo(h.reportedAt)}',
                      child: HazardPin(category: h.category, size: 26),
                    ),
                  ),
                ),
                Marker(
                  point: origin,
                  width: 28,
                  height: 28,
                  child: Tooltip(
                    message: _gpsLive
                        ? 'Your location'
                        : 'Approximate starting location',
                    child: const MyLocationDot(),
                  ),
                ),
                if (_destination != null)
                  Marker(
                    point: _destination!,
                    width: 44,
                    height: 50,
                    alignment: Alignment.topCenter,
                    child: Tooltip(
                      message: _destinationName ?? 'Selected destination',
                      child: const DestinationPin(
                        color: AegisColors.danger,
                        icon: Icons.place,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          top: AegisSpacing.md,
          left: AegisSpacing.md,
          right: AegisSpacing.md,
          child: _searchBar(),
        ),
        if (!_gpsLive)
          Positioned(
            top: 68,
            left: AegisSpacing.md,
            right: AegisSpacing.md,
            child: _gpsBanner(),
          ),
        Positioned(
          right: AegisSpacing.md,
          bottom: AegisSpacing.lg,
          child: Column(
            children: [
              if (_destination != null) ...[
                MapFab(
                  icon: Icons.fit_screen,
                  tooltip: 'Show entire route',
                  onPressed: _fitToRoutes,
                ),
                const SizedBox(height: AegisSpacing.sm),
                MapFab(
                  icon: Icons.close,
                  tooltip: 'Clear destination',
                  onPressed: _reset,
                ),
                const SizedBox(height: AegisSpacing.sm),
              ],
              MapFab(
                icon: _locating ? Icons.gps_not_fixed : Icons.my_location,
                tooltip: 'My location',
                onPressed: () => _locate(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Polyline<int> _polyline(int i, {required bool selected}) {
    final color = _routeColors[i % _routeColors.length];
    return Polyline<int>(
      points: _routes[i].points,
      hitValue: i,
      strokeWidth: selected ? 7 : 5,
      color: selected ? color : color.withValues(alpha: 0.5),
      borderColor: selected ? Colors.white : Colors.transparent,
      borderStrokeWidth: selected ? 2 : 0,
    );
  }

  /// "Where to?" search bar – opens place search.
  Widget _searchBar() {
    final label = _destination == null
        ? 'Where are you walking to?'
        : (_destinationName ?? 'Pinned location on map');
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: AegisColors.primary.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(AegisRadius.xl),
      child: InkWell(
        borderRadius: BorderRadius.circular(AegisRadius.xl),
        onTap: _searchDestination,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AegisSpacing.lg,
            vertical: 14,
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: AegisColors.primary),
              const SizedBox(width: AegisSpacing.md),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: _destination == null
                        ? FontWeight.w500
                        : FontWeight.w600,
                    color: _destination == null
                        ? AegisColors.textSecondary
                        : AegisColors.textPrimary,
                  ),
                ),
              ),
              if (_destination != null)
                GestureDetector(
                  onTap: _reset,
                  child: const Icon(
                    Icons.close,
                    size: 20,
                    color: AegisColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gpsBanner() {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(AegisRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AegisRadius.md),
        onTap: _locating ? null : () => _locate(),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AegisSpacing.md,
            vertical: AegisSpacing.sm,
          ),
          child: Row(
            children: [
              const Icon(Icons.gps_off, size: 18, color: AegisColors.warning),
              const SizedBox(width: AegisSpacing.sm),
              Expanded(
                child: Text(
                  '${_gpsReason ?? 'GPS unavailable'}. Showing an approximate start.',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AegisColors.textPrimary,
                  ),
                ),
              ),
              Text(
                _locating ? 'Locating…' : 'Turn on',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AegisColors.primary,
                ),
              ),
            ],
          ),
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
          Text(
            'Plan a safer walk',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AegisColors.textPrimary,
            ),
          ),
          const SizedBox(height: AegisSpacing.xs),
          Text(
            'Search for a place or tap anywhere on the map. We compare two walking routes '
            'using street lighting and hazards reported by other walkers.',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AegisColors.textSecondary,
            ),
          ),
          const SizedBox(height: AegisSpacing.lg),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _searchDestination,
              icon: const Icon(Icons.search),
              label: const Text('Search for a place'),
            ),
          ),
          const SizedBox(height: AegisSpacing.lg),
          const _StepRow(
            icon: Icons.place_outlined,
            text: 'Choose where you are going',
          ),
          const _StepRow(
            icon: Icons.alt_route,
            text: 'Compare the safety score of two routes',
          ),
          const _StepRow(
            icon: Icons.directions_walk,
            text: 'Start a live trip your guardians can follow',
          ),
        ],
      );
    } else if (_error != null && !_loading && _routes.isEmpty) {
      child = ListView(
        padding: const EdgeInsets.all(AegisSpacing.lg),
        children: [
          AegisEmptyState(
            icon: Icons.wifi_off_rounded,
            iconColor: AegisColors.warning,
            title: _routes.isNotEmpty
                ? 'Safety data unavailable'
                : 'Routes unavailable',
            message: _error!,
            actionLabel: 'Try again',
            actionIcon: Icons.refresh,
            onAction: _compute,
          ),
        ],
      );
    } else {
      child = _buildResults();
    }

    return Container(
      decoration: const BoxDecoration(
        color: AegisColors.surfaceContainerLow,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AegisRadius.xxl),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A007FFF),
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildResults() {
    final scoresReady = _hasResults;
    final fullyRated = scoresReady && _scores.every((s) => s.hasLightingData);
    final best = fullyRated
        ? (_scores[0].score >= _scores[1].score ? 0 : 1)
        : -1;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AegisSpacing.lg,
        AegisSpacing.lg,
        AegisSpacing.lg,
        96,
      ),
      children: [
        Row(
          children: [
            if (_loading) ...[
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: AegisSpacing.sm),
            ],
            Expanded(
              child: Text(
                _loading && _routes.isEmpty
                    ? 'Finding walking routes…'
                    : _loading
                    ? 'Checking lighting and hazards…'
                    : fullyRated
                    ? 'Pick the route you feel safest on'
                    : 'Choose a walking route',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AegisColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        if (_routes.isNotEmpty && !_loading) ...[
          const SizedBox(height: 2),
          Text(
            'Tip: tap a line on the map to select it.',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AegisColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: AegisSpacing.md),
        if (scoresReady && !fullyRated) ...[
          const Text(
            'Hazard reports only',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const Text(
            'Street-lighting information is unavailable or not mapped. Compare the reported hazards below; no overall safety rating is available.',
          ),
          TextButton.icon(
            onPressed: () => _compute(),
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh safety information'),
          ),
        ],
        if (_error != null && !_loading) ...[
          Text(_error!, style: TextStyle(color: AegisColors.warning)),
          const Text(
            'You can still start a trip. No safer-route recommendation is available.',
          ),
          TextButton.icon(
            onPressed: () => _compute(),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry route safety check'),
          ),
        ],
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
                  loading: _loading,
                  selected: _selected == i,
                  recommended:
                      best == i && _scores[0].score != _scores[1].score,
                  onTap: _routes.length > i
                      ? () => setState(() => _selected = i)
                      : null,
                ),
              ),
            ],
          ],
        ),
        if (_routes.length == 2 &&
            !_loading &&
            (widget.onRouteChosen == null || scoresReady)) ...[
          const SizedBox(height: AegisSpacing.lg),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _choose,
              icon: const Icon(Icons.directions_walk),
              label: Text(
                'Start walking · ${_routes[_selected].label}${scoresReady ? '' : ' (unrated)'}',
              ),
            ),
          ),
        ],
        if (scoresReady) ...[
          const SizedBox(height: AegisSpacing.lg),
          _ScoreExplanation(
            route: _routes[_selected],
            score: _scores[_selected],
            color: _routeColors[_selected],
          ),
        ],
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _StepRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AegisSpacing.sm),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AegisColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AegisRadius.md),
            ),
            child: Icon(icon, size: 18, color: AegisColors.primary),
          ),
          const SizedBox(width: AegisSpacing.md),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AegisColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteOptionCard extends StatelessWidget {
  final String label;
  final Color color;
  final CandidateRoute? route;
  final RouteSafetyScore? score;
  final bool loading;
  final bool selected;
  final bool recommended;
  final VoidCallback? onTap;

  const _RouteOptionCard({
    required this.label,
    required this.color,
    required this.route,
    required this.score,
    required this.loading,
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
        color: selected
            ? color.withValues(alpha: 0.12)
            : AegisColors.surfaceContainerHigh,
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
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: AegisColors.textPrimary,
                        ),
                      ),
                    ),
                    if (recommended)
                      const Icon(
                        Icons.verified,
                        color: AegisColors.tertiary,
                        size: 18,
                      ),
                  ],
                ),
                const SizedBox(height: AegisSpacing.md),
                if (s == null && !loading)
                  const SizedBox(
                    height: 78,
                    child: Center(child: Icon(Icons.help_outline, size: 48)),
                  )
                else if (s != null && !s.hasLightingData)
                  SizedBox(
                    height: 78,
                    child: Center(
                      child: Text(
                        '${s.hazards.length}',
                        style: GoogleFonts.outfit(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                else
                  SafetyScoreRing(score: s?.score, size: 78),
                const SizedBox(height: AegisSpacing.sm),
                Text(
                  s == null
                      ? (loading ? '…' : 'Not rated')
                      : !s.hasLightingData
                      ? 'Reported hazards'
                      : (recommended ? 'Safer choice' : s.rating),
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: s == null || !s.hasLightingData
                        ? AegisColors.textSecondary
                        : AegisColors.forScore(s.score),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  r == null ? '—' : '${r.durationMin} min · ${r.distanceLabel}',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AegisColors.textSecondary,
                  ),
                ),
                if (s != null && !s.hasLightingData)
                  const Padding(
                    padding: EdgeInsets.only(top: AegisSpacing.sm),
                    child: Text(
                      'Lighting unknown\nNot safety-rated',
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (s != null && s.hasLightingData) ...[
                  const SizedBox(height: AegisSpacing.md),
                  SubScoreBar(
                    label: 'Lighting',
                    value: s.lightingScore,
                    icon: Icons.lightbulb_outline,
                  ),
                  const SizedBox(height: AegisSpacing.sm),
                  SubScoreBar(
                    label: s.hazards.isEmpty
                        ? 'No reports'
                        : '${s.hazards.length} hazard${s.hazards.length == 1 ? '' : 's'}',
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

  const _ScoreExplanation({
    required this.route,
    required this.score,
    required this.color,
  });

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
          initiallyExpanded: false,
          iconColor: AegisColors.textSecondary,
          collapsedIconColor: AegisColors.textSecondary,
          leading: Icon(Icons.insights_outlined, color: color),
          title: Text(
            score.hasLightingData
                ? 'Why ${route.label} scores ${score.score}'
                : '${route.label}: reported hazards',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: AegisColors.textPrimary,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AegisSpacing.lg,
            0,
            AegisSpacing.lg,
            AegisSpacing.lg,
          ),
          children: [
            ...score.explanation.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: AegisSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(
                        Icons.circle,
                        size: 6,
                        color: AegisColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: AegisSpacing.sm),
                    Expanded(
                      child: Text(
                        line,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AegisColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (score.hazards.isNotEmpty) ...[
              const SizedBox(height: AegisSpacing.xs),
              ...score.hazards
                  .take(4)
                  .map(
                    (h) => Padding(
                      padding: const EdgeInsets.only(bottom: AegisSpacing.xs),
                      child: Row(
                        children: [
                          HazardPin(category: h.report.category, size: 20),
                          const SizedBox(width: AegisSpacing.sm),
                          Expanded(
                            child: Text(
                              '${h.report.categoryInfo.label} · ${h.distanceM.round()} m off route · ${timeAgo(h.report.reportedAt)}',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: AegisColors.textSecondary,
                              ),
                            ),
                          ),
                          Text(
                            '−${(h.weight * RouteSafetyScorer.pointsPerHazard).round()}',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AegisColors.danger,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}
