import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rxdart/rxdart.dart';
import '../../models/alert_model.dart';
import '../../models/trip_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/aegis_theme.dart';
import 'package:intl/intl.dart';

/// Toggle this to [true] to test the UI with hardcoded data without Firestore.
const bool _useDummyData = false;

/// A screen that displays a combined feed of recent trips and safety alerts.
///
/// It merges two separate Firestore streams (trips and alerts) into a single
/// chronologically-ordered list.
class ActivityFeedScreen extends StatelessWidget {
  const ActivityFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AegisColors.background,
      body: _useDummyData
          ? _buildDummyList(context)
          : _buildCombinedStream(context, user),
    );
  }

  /// MERGE APPROACH EXPLANATION:
  /// I am using [CombineLatestStream.combine2] from the rxdart package.
  ///
  /// WHY:
  /// 1. REAL-TIME: It listens to both Firestore collections simultaneously. Whenever
  ///    either a trip or an alert is added/updated, the combined stream emits.
  /// 2. COMPLETE SORTING: Unlike [StreamGroup.merge], [CombineLatestStream] allows us
  ///    to have access to the full current snapshot of both datasets at once. This
  ///    is essential for sorting them correctly by timestamp (descending) on every
  ///    single update, ensuring the UI always shows the absolute most recent event
  ///    at the top, regardless of whether it's a trip or an alert.
  Widget _buildCombinedStream(BuildContext context, User? user) {
    if (user == null) {
      return const _EmptyState(
        message: "Please sign in to view your activity.",
      );
    }

    final tripsStream = FirestoreService.instance.streamTripHistory(user.uid);
    final alertsStream = FirestoreService.instance.streamAlerts(user.uid);

    return StreamBuilder<List<dynamic>>(
      stream: CombineLatestStream.combine2(tripsStream, alertsStream, (
        List<TripModel> trips,
        List<AlertModel> alerts,
      ) {
        // Merge into one list
        final combined = <dynamic>[...trips, ...alerts];

        // Sort by timestamp descending (most recent first)
        combined.sort((a, b) {
          final dateA = (a is TripModel)
              ? a.startedAt
              : (a as AlertModel).triggeredAt;
          final dateB = (b is TripModel)
              ? b.startedAt
              : (b as AlertModel).triggeredAt;
          return dateB.compareTo(dateA);
        });

        return combined;
      }),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorState(
            error: snapshot.error.toString(),
            onRetry: () => (context as Element).markNeedsBuild(),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AegisColors.primary),
          );
        }

        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return const _EmptyState();
        }

        return _ActivityList(
          items: items,
          onTripTap: (trip) =>
              _showPlaceholder(context, 'Trip: ${trip.tripId}'),
          onAlertTap: (alert) =>
              _showPlaceholder(context, 'Alert: ${alert.alertId}'),
        );
      },
    );
  }

  // TODO: remove dummy data
  Widget _buildDummyList(BuildContext context) {
    final now = DateTime.now();
    final List<dynamic> dummyData = [
      AlertModel(
        alertId: 'alert-1',
        tripId: 'trip-1',
        userId: 'test-user',
        type: 'manual_sos',
        location: {'lat': 6.9271, 'lng': 79.8612},
        triggeredAt: now.subtract(const Duration(minutes: 5)),
        resolved: false,
      ),
      TripModel(
        tripId: 'trip-1',
        userId: 'test-user',
        status: 'active',
        startLocation: {'lat': 6.9271, 'lng': 79.8612},
        currentLocation: {'lat': 6.9275, 'lng': 79.8615},
        destination: {'lat': 6.9344, 'lng': 79.8451},
        startedAt: now.subtract(const Duration(minutes: 15)),
      ),
      AlertModel(
        alertId: 'alert-2',
        tripId: 'trip-0',
        userId: 'test-user',
        type: 'fall_detected',
        location: {'lat': 6.9100, 'lng': 79.8800},
        triggeredAt: now.subtract(const Duration(hours: 1)),
        resolved: true,
      ),
      TripModel(
        tripId: 'trip-0',
        userId: 'test-user',
        status: 'completed',
        startLocation: {'lat': 6.9100, 'lng': 79.8800},
        currentLocation: {'lat': 6.9200, 'lng': 79.8700},
        destination: {'lat': 6.9200, 'lng': 79.8700},
        startedAt: now.subtract(const Duration(hours: 2)),
        endedAt: now.subtract(const Duration(hours: 1, minutes: 15)),
      ),
    ];

    dummyData.sort((a, b) {
      final dateA = (a is TripModel)
          ? a.startedAt
          : (a as AlertModel).triggeredAt;
      final dateB = (b is TripModel)
          ? b.startedAt
          : (b as AlertModel).triggeredAt;
      return dateB.compareTo(dateA);
    });

    return _ActivityList(
      items: dummyData,
      onTripTap: (trip) =>
          _showPlaceholder(context, 'Dummy Trip: ${trip.tripId}'),
      onAlertTap: (alert) =>
          _showPlaceholder(context, 'Dummy Alert: ${alert.alertId}'),
    );
  }

  void _showPlaceholder(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AegisColors.surfaceContainerHighest,
      ),
    );
  }
}

/// Filters for the Activity page. `null` means "All".
enum ActivityFilter { active, alerts, trips }

/// Whether [item] (a [TripModel] or [AlertModel]) is still active:
/// an unresolved alert, or a trip that is still in progress.
bool isActiveActivity(dynamic item) {
  if (item is AlertModel) return !item.resolved;
  if (item is TripModel) return item.status.toLowerCase() == 'active';
  return false;
}

/// Returns only the items matching [filter]; `null` returns everything.
/// The original order (newest first) is kept.
List<dynamic> filterActivity(List<dynamic> items, ActivityFilter? filter) =>
    switch (filter) {
      null => items,
      ActivityFilter.active => items.where(isActiveActivity).toList(),
      ActivityFilter.alerts => items.whereType<AlertModel>().toList(),
      ActivityFilter.trips => items.whereType<TripModel>().toList(),
    };

/// Grouped, reference-style list of trips and alerts (newest first), with
/// filter boxes for Active, Alerts and Trips.
class _ActivityList extends StatefulWidget {
  final List<dynamic> items;
  final ValueChanged<TripModel> onTripTap;
  final ValueChanged<AlertModel> onAlertTap;

  const _ActivityList({
    required this.items,
    required this.onTripTap,
    required this.onAlertTap,
  });

  @override
  State<_ActivityList> createState() => _ActivityListState();
}

class _ActivityListState extends State<_ActivityList> {
  /// Selected filter; `null` shows all activity.
  ActivityFilter? _filter;

  static DateTime _dateOf(dynamic item) =>
      item is TripModel ? item.startedAt : (item as AlertModel).triggeredAt;

  static String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('EEE, MMM d, yyyy').format(d);
  }

  void _toggle(ActivityFilter filter) =>
      setState(() => _filter = _filter == filter ? null : filter);

  String get _showingLabel => switch (_filter) {
    null => 'Showing all activity',
    ActivityFilter.active => 'Showing active only',
    ActivityFilter.alerts => 'Showing alerts only',
    ActivityFilter.trips => 'Showing trips only',
  };

  String get _emptyLabel => switch (_filter) {
    null => 'No activity yet.',
    ActivityFilter.active => 'Nothing active right now. You\'re all clear.',
    ActivityFilter.alerts => 'No alerts yet.',
    ActivityFilter.trips => 'No trips yet.',
  };

  @override
  Widget build(BuildContext context) {
    final all = widget.items;
    final activeCount = all.where(isActiveActivity).length;
    final alertCount = all.whereType<AlertModel>().length;
    final tripCount = all.whereType<TripModel>().length;
    final visible = filterActivity(all, _filter);

    // Build rows with a day header whenever the date changes.
    final rows = <Widget>[];
    String? lastDay;
    for (final item in visible) {
      final label = _dayLabel(_dateOf(item));
      if (label != lastDay) {
        rows.add(_DayHeader(label));
        lastDay = label;
      }
      rows.add(
        item is TripModel
            ? _ActivityTile.trip(item, onTap: () => widget.onTripTap(item))
            : _ActivityTile.alert(
                item as AlertModel,
                onTap: () => widget.onAlertTap(item),
              ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(
          'Activity',
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AegisColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Your trips and safety alerts',
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: AegisColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _FilterBox(
                icon: Icons.notifications_active_outlined,
                count: activeCount,
                label: 'Active',
                selected: _filter == ActivityFilter.active,
                onTap: () => _toggle(ActivityFilter.active),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _FilterBox(
                icon: Icons.shield_outlined,
                count: alertCount,
                label: 'Alerts',
                selected: _filter == ActivityFilter.alerts,
                onTap: () => _toggle(ActivityFilter.alerts),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _FilterBox(
                icon: Icons.directions_walk_rounded,
                count: tripCount,
                label: 'Trips',
                selected: _filter == ActivityFilter.trips,
                onTap: () => _toggle(ActivityFilter.trips),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Icon(
              _filter == null
                  ? Icons.view_list_rounded
                  : Icons.filter_alt_rounded,
              size: 16,
              color: AegisColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '$_showingLabel  ·  ${visible.length}',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AegisColors.textSecondary,
                ),
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: _filter == null ? 0 : 1,
              child: TextButton.icon(
                onPressed: _filter == null
                    ? null
                    : () => setState(() => _filter = null),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Show all'),
                style: TextButton.styleFrom(
                  foregroundColor: AegisColors.azure,
                  visualDensity: VisualDensity.compact,
                  textStyle: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AegisColors.azure.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.inbox_outlined,
                    size: 38,
                    color: AegisColors.azure,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _emptyLabel,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: AegisColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          ...rows,
      ],
    );
  }
}

/// A tappable filter box: icon, count and label. Selected boxes are filled
/// with the blue gradient; tapping a selected box clears the filter.
class _FilterBox extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterBox({
    required this.icon,
    required this.count,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '$label filter, $count',
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        gradient: selected
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AegisColors.azure, AegisColors.dodgerBlue],
              )
            : null,
        color: selected ? null : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? Colors.transparent
              : AegisColors.surfaceContainerHighest,
        ),
        boxShadow: [
          BoxShadow(
            color: AegisColors.azure.withValues(alpha: selected ? 0.30 : 0.06),
            blurRadius: selected ? 18 : 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.20)
                            : AegisColors.azure.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        size: 18,
                        color: selected ? Colors.white : AegisColors.azure,
                      ),
                    ),
                    const Spacer(),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: selected ? 1 : 0,
                      child: const Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '$count',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    color: selected ? Colors.white : AegisColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.white.withValues(alpha: 0.9)
                        : AegisColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _DayHeader extends StatelessWidget {
  final String label;
  const _DayHeader(this.label);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
    child: Text(
      label.toUpperCase(),
      style: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: AegisColors.azure,
      ),
    ),
  );
}

enum _Tone { info, done, danger, success }

/// One activity row: round icon, title + subtitle, and a status pill.
class _ActivityTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final _Tone tone;
  final VoidCallback onTap;

  const _ActivityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.tone,
    required this.onTap,
  });

  static final _time = DateFormat('hh:mm a');

  factory _ActivityTile.alert(AlertModel alert, {required VoidCallback onTap}) {
    final isSos = alert.type.toLowerCase() == 'manual_sos';
    return _ActivityTile(
      icon: isSos ? Icons.sos_rounded : Icons.personal_injury_outlined,
      title: isSos ? 'Manual SOS' : 'Fall Detected',
      subtitle: 'Triggered at ${_time.format(alert.triggeredAt)}',
      status: alert.resolved ? 'Resolved' : 'Active',
      tone: alert.resolved ? _Tone.success : _Tone.danger,
      onTap: onTap,
    );
  }

  factory _ActivityTile.trip(TripModel trip, {required VoidCallback onTap}) {
    final status = trip.status.toLowerCase();
    String? duration;
    if (trip.endedAt != null) {
      final d = trip.endedAt!.difference(trip.startedAt);
      duration = d.inMinutes < 60
          ? '${d.inMinutes}m'
          : '${d.inHours}h ${d.inMinutes % 60}m';
    }
    final name = trip.destinationName?.trim();
    final destination = (name != null && name.isNotEmpty)
        ? name
        : '${trip.destination['lat']?.toStringAsFixed(4)}, '
              '${trip.destination['lng']?.toStringAsFixed(4)}';
    final parts = <String>[_time.format(trip.startedAt), ?duration];
    return _ActivityTile(
      icon: Icons.directions_walk_rounded,
      title: 'Trip to $destination',
      subtitle: parts.join('  ·  '),
      status: switch (status) {
        'completed' => 'Completed',
        'alerted' => 'Alerted',
        _ => 'Active',
      },
      tone: switch (status) {
        'completed' => _Tone.done,
        'alerted' => _Tone.danger,
        _ => _Tone.info,
      },
      onTap: onTap,
    );
  }

  static const Color _danger = Color(0xFFD93025);
  static const Color _success = Color(0xFF1E8E5A);

  (Color fg, Color bg) get _pillColors => switch (tone) {
    _Tone.info => (Colors.white, AegisColors.azure),
    _Tone.done => (AegisColors.azure, AegisColors.surfaceContainerHigh),
    _Tone.danger => (_danger, _danger.withValues(alpha: 0.10)),
    _Tone.success => (_success, _success.withValues(alpha: 0.10)),
  };

  Color get _iconColor => switch (tone) {
    _Tone.danger => _danger,
    _ => AegisColors.azure,
  };

  @override
  Widget build(BuildContext context) {
    final (pillFg, pillBg) = _pillColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AegisColors.surfaceContainerHigh),
          boxShadow: [
            BoxShadow(
              color: AegisColors.azure.withValues(alpha: 0.07),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _iconColor.withValues(alpha: 0.08),
                      border: Border.all(
                        color: _iconColor.withValues(alpha: 0.18),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(icon, color: _iconColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AegisColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 14,
                              color: AegisColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: AegisColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: pillBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: pillFg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({
    this.message = "No activity yet. Your trips and alerts will appear here.",
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AegisColors.azure.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 48,
                color: AegisColors.azure,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: AegisColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AegisColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              "Oops! Something went wrong.",
              style: GoogleFonts.outfit(
                color: AegisColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: AegisColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AegisColors.primary,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
