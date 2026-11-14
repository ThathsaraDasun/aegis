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
import 'widgets/aegis_map.dart';
import 'widgets/hazard_style.dart';

/// Drop a hazard pin (category + timestamp) – Member 3, scope §3.4.
class ReportHazardScreen extends StatefulWidget {
  /// Optional starting pin (e.g. a point long-pressed on the route map).
  final LatLng? initialLocation;

  const ReportHazardScreen({super.key, this.initialLocation});

  @override
  State<ReportHazardScreen> createState() => _ReportHazardScreenState();
}

class _ReportHazardScreenState extends State<ReportHazardScreen> {
  final RouteSafetyService _service = RouteSafetyService();
  final MapController _map = MapController();
  final TextEditingController _description = TextEditingController();

  LatLng? _myPosition;
  LatLng? _pin;
  bool _gpsLive = false;
  String? _gpsReason;
  String _category = HazardCategory.poorLighting.key;
  bool _submitting = false;
  Stream<List<HazardReportModel>>? _nearby;

  @override
  void initState() {
    super.initState();
    _pin = widget.initialLocation;
    _locate();
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _locate({bool movePin = false}) async {
    final result = await PositionHelper.current();
    if (!mounted) return;
    setState(() {
      _myPosition = result.position;
      _gpsLive = result.isLive;
      _gpsReason = result.reason;
      if (_pin == null || movePin) _pin = result.position;
      _nearby ??= _service.streamNearbyHazards(center: result.position, radiusM: 1000);
    });
    if (movePin) _map.move(result.position, 17);
  }

  Future<void> _submit() async {
    final pin = _pin;
    if (pin == null) return;
    setState(() => _submitting = true);
    try {
      await _service.reportHazard(HazardReportModel(
        id: '',
        category: _category,
        description: _description.text,
        lat: pin.latitude,
        lng: pin.longitude,
        reportedAt: DateTime.now(),
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${HazardCategory.fromKey(_category).label} reported – thanks for keeping others safe'),
          backgroundColor: AegisColors.tertiaryContainer,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit report: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report a Hazard')),
      body: _myPosition == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(flex: 5, child: _buildMap()),
                Expanded(flex: 6, child: _buildForm()),
              ],
            ),
    );
  }

  Widget _buildMap() {
    final pin = _pin!;
    return Stack(
      children: [
        AegisMap(
          controller: _map,
          initialCenter: pin,
          initialZoom: 17,
          onTap: (_, point) => setState(() => _pin = point),
          children: [
            StreamBuilder<List<HazardReportModel>>(
              stream: _nearby,
              builder: (context, snap) => MarkerLayer(
                markers: (snap.data ?? const [])
                    .map((h) => Marker(
                          point: LatLng(h.lat, h.lng),
                          width: 24,
                          height: 24,
                          child: Opacity(opacity: 0.75, child: HazardPin(category: h.category, size: 24)),
                        ))
                    .toList(),
              ),
            ),
            MarkerLayer(markers: [
              if (_myPosition != null)
                Marker(point: _myPosition!, width: 26, height: 26, child: const MyLocationDot()),
              Marker(
                point: pin,
                width: 44,
                height: 60,
                alignment: Alignment.topCenter,
                child: _DroppedPin(category: _category),
              ),
            ]),
          ],
        ),
        Positioned(
          top: AegisSpacing.md,
          left: AegisSpacing.md,
          right: 72,
          child: _MapHint(
            text: _gpsLive
                ? 'Tap the map to move the pin to the exact spot'
                : '${_gpsReason ?? 'GPS unavailable'} – tap the map to place the pin',
            warning: !_gpsLive,
          ),
        ),
        Positioned(
          right: AegisSpacing.md,
          bottom: AegisSpacing.xl,
          child: MapFab(
            icon: Icons.my_location,
            tooltip: 'Use my location',
            onPressed: () => _locate(movePin: true),
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    final pin = _pin!;
    final distance = _myPosition == null ? null : GeoUtils.distanceM(_myPosition!, pin);
    return Container(
      decoration: const BoxDecoration(
        color: AegisColors.surfaceContainerLow,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AegisRadius.xxl)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AegisSpacing.lg, AegisSpacing.lg, AegisSpacing.lg, AegisSpacing.xl),
        children: [
          Row(
            children: [
              const Icon(Icons.place_outlined, color: AegisColors.primary, size: 18),
              const SizedBox(width: AegisSpacing.xs),
              Expanded(
                child: Text(
                  '${pin.latitude.toStringAsFixed(5)}, ${pin.longitude.toStringAsFixed(5)}',
                  style: GoogleFonts.outfit(color: AegisColors.textPrimary, fontWeight: FontWeight.w600),
                ),
              ),
              if (distance != null)
                Text(
                  distance < 15 ? 'At your location' : '${distance.round()} m from you',
                  style: GoogleFonts.outfit(fontSize: 12, color: AegisColors.textSecondary),
                ),
            ],
          ),
          const SizedBox(height: AegisSpacing.lg),
          const AegisSectionHeader('What did you notice?'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AegisSpacing.sm,
            crossAxisSpacing: AegisSpacing.sm,
            childAspectRatio: 2.6,
            children: HazardCategory.all.map(_categoryTile).toList(),
          ),
          const SizedBox(height: AegisSpacing.lg),
          TextField(
            controller: _description,
            maxLines: 2,
            maxLength: 160,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Details (optional)',
              hintText: 'e.g. Street lamp broken near the bus stop',
              alignLabelWithHint: true,
            ),
          ),
          Row(
            children: [
              const Icon(Icons.schedule, size: 14, color: AegisColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Timestamped now · visible to all Safe Walk users nearby',
                  style: GoogleFonts.outfit(fontSize: 11, color: AegisColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AegisSpacing.lg),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add_location_alt_outlined),
              label: const Text('Drop hazard pin'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryTile(HazardCategory c) {
    final style = HazardStyle.of(c.key);
    final selected = _category == c.key;
    return Material(
      color: selected ? style.color.withValues(alpha: 0.2) : AegisColors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AegisRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AegisRadius.md),
        onTap: () => setState(() => _category = c.key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AegisSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AegisRadius.md),
            border: Border.all(
              color: selected ? style.color : AegisColors.surfaceContainerHighest,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(style.icon, color: style.color, size: 22),
              const SizedBox(width: AegisSpacing.sm),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                            fontSize: 13, fontWeight: FontWeight.bold, color: AegisColors.textPrimary)),
                    Text(c.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(fontSize: 10, color: AegisColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DroppedPin extends StatelessWidget {
  final String category;
  const _DroppedPin({required this.category});

  @override
  Widget build(BuildContext context) {
    final style = HazardStyle.of(category);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HazardPin(category: category, size: 40, highlighted: true),
        Container(width: 3, height: 14, color: style.color),
        Container(
          width: 8,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}

class _MapHint extends StatelessWidget {
  final String text;
  final bool warning;
  const _MapHint({required this.text, this.warning = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AegisSpacing.md, vertical: AegisSpacing.sm),
      decoration: BoxDecoration(
        color: AegisColors.surfaceContainerLow.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AegisRadius.md),
        border: Border.all(
          color: warning ? AegisColors.warning.withValues(alpha: 0.6) : AegisColors.surfaceContainerHighest,
        ),
      ),
      child: Row(
        children: [
          Icon(warning ? Icons.gps_off : Icons.touch_app_outlined,
              size: 16, color: warning ? AegisColors.warning : AegisColors.textSecondary),
          const SizedBox(width: AegisSpacing.sm),
          Expanded(
            child: Text(text, style: GoogleFonts.outfit(fontSize: 12, color: AegisColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

