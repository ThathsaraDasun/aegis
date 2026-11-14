import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../models/hazard_report_model.dart';
import '../../services/route/geo_utils.dart';
import '../../services/route/position_helper.dart';
import '../../services/route_safety_service.dart';
import '../../theme/aegis_theme.dart';
import '../../widgets/aegis_empty_state.dart';
import 'report_hazard_screen.dart';
import 'widgets/aegis_map.dart';
import 'widgets/hazard_style.dart';

/// Map + list of crowd-sourced hazard reports around the user.
class NearbyHazardsScreen extends StatefulWidget {
  const NearbyHazardsScreen({super.key});

  @override
  State<NearbyHazardsScreen> createState() => _NearbyHazardsScreenState();
}

class _NearbyHazardsScreenState extends State<NearbyHazardsScreen> {
  static const double _radiusM = 1500;

  final RouteSafetyService _service = RouteSafetyService();
  final MapController _map = MapController();
  final Set<String> _confirmed = {};

  LatLng? _center;
  bool _gpsLive = true;
  Stream<List<HazardReportModel>>? _stream;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await PositionHelper.current();
    if (!mounted) return;
    setState(() {
      _center = result.position;
      _gpsLive = result.isLive;
      _stream = _service.streamNearbyHazards(center: result.position, radiusM: _radiusM);
    });
  }

  Future<void> _confirm(HazardReportModel h) async {
    setState(() => _confirmed.add(h.id));
    try {
      await _service.confirmHazard(h.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _confirmed.remove(h.id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not confirm: $e')));
    }
  }

  Future<void> _delete(HazardReportModel h) async {
    try {
      await _service.deleteHazard(h.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not remove: $e')));
    }
  }

  void _focus(HazardReportModel h) {
    setState(() => _selectedId = h.id);
    _map.move(LatLng(h.lat, h.lng), 17);
  }

  @override
  Widget build(BuildContext context) {
    final center = _center;
    return Scaffold(
      appBar: AppBar(title: const Text('Nearby Hazards')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ReportHazardScreen()),
        ),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: Text('Report', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
      body: center == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<HazardReportModel>>(
              stream: _stream,
              builder: (context, snap) {
                final hazards = snap.data ?? const <HazardReportModel>[];
                return Column(
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.36,
                      child: AegisMap(
                        controller: _map,
                        initialCenter: center,
                        initialZoom: 15,
                        children: [
                          CircleLayer(circles: [
                            CircleMarker(
                              point: center,
                              radius: _radiusM,
                              useRadiusInMeter: true,
                              color: AegisColors.secondary.withValues(alpha: 0.06),
                              borderColor: AegisColors.secondary.withValues(alpha: 0.4),
                              borderStrokeWidth: 1,
                            ),
                          ]),
                          MarkerLayer(markers: [
                            Marker(point: center, width: 26, height: 26, child: const MyLocationDot()),
                            ...hazards.map((h) => Marker(
                                  point: LatLng(h.lat, h.lng),
                                  width: 34,
                                  height: 34,
                                  child: GestureDetector(
                                    onTap: () => setState(() => _selectedId = h.id),
                                    child: HazardPin(
                                      category: h.category,
                                      size: _selectedId == h.id ? 34 : 28,
                                      highlighted: _selectedId == h.id,
                                    ),
                                  ),
                                )),
                          ]),
                        ],
                      ),
                    ),
                    Expanded(child: _buildList(center, hazards, snap)),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildList(LatLng center, List<HazardReportModel> hazards,
      AsyncSnapshot<List<HazardReportModel>> snap) {
    if (snap.hasError) {
      return Padding(
        padding: const EdgeInsets.all(AegisSpacing.lg),
        child: AegisEmptyState(
          icon: Icons.cloud_off,
          iconColor: AegisColors.danger,
          title: 'Couldn\'t load reports',
          message: 'Check your connection or sign in, then try again.',
          actionLabel: 'Retry',
          actionIcon: Icons.refresh,
          onAction: _load,
        ),
      );
    }
    if (!snap.hasData) return const Center(child: CircularProgressIndicator());

    final uid = FirebaseAuth.instance.currentUser?.uid;
    return ListView(
      padding: const EdgeInsets.fromLTRB(AegisSpacing.lg, AegisSpacing.lg, AegisSpacing.lg, 96),
      children: [
        AegisSectionHeader(
          '${hazards.length} report${hazards.length == 1 ? '' : 's'} within ${(_radiusM / 1000).toStringAsFixed(1)} km',
          trailing: _gpsLive
              ? null
              : Text('Approx. location',
                  style: GoogleFonts.outfit(fontSize: 11, color: AegisColors.warning)),
        ),
        if (hazards.isEmpty)
          const AegisEmptyState(
            icon: Icons.verified_outlined,
            iconColor: AegisColors.tertiary,
            title: 'No hazards reported nearby',
            message: 'Nobody has flagged anything around you. Spotted a dark street or unsafe '
                'spot? Drop a pin to warn others.',
          )
        else
          ...hazards.map((h) {
            final style = HazardStyle.of(h.category);
            final d = GeoUtils.distanceM(center, LatLng(h.lat, h.lng));
            final confirmed = _confirmed.contains(h.id);
            final mine = uid != null && h.reportedBy == uid;
            return Padding(
              padding: const EdgeInsets.only(bottom: AegisSpacing.sm),
              child: Material(
                color: _selectedId == h.id
                    ? style.color.withValues(alpha: 0.12)
                    : AegisColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AegisRadius.lg),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AegisRadius.lg),
                  onTap: () => _focus(h),
                  child: Padding(
                    padding: const EdgeInsets.all(AegisSpacing.md),
                    child: Row(
                      children: [
                        HazardPin(category: h.category, size: 36),
                        const SizedBox(width: AegisSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(h.categoryInfo.label,
                                  style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold, color: AegisColors.textPrimary)),
                              if (h.description.isNotEmpty)
                                Text(h.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                        fontSize: 12, color: AegisColors.textSecondary)),
                              const SizedBox(height: 2),
                              Text(
                                '${d.round()} m away · ${timeAgo(h.reportedAt)} · '
                                '${h.confirmCount} confirmed',
                                style: GoogleFonts.outfit(fontSize: 11, color: style.color),
                              ),
                            ],
                          ),
                        ),
                        if (mine)
                          IconButton(
                            tooltip: 'Remove my report',
                            icon: const Icon(Icons.delete_outline, color: AegisColors.textSecondary),
                            onPressed: () => _delete(h),
                          )
                        else
                          TextButton(
                            onPressed: confirmed ? null : () => _confirm(h),
                            child: Text(confirmed ? 'Thanks' : 'I saw it'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}
