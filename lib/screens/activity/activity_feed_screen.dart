import 'package:flutter/material.dart';
import '../../services/activity_service.dart';
import '../../theme/aegis_theme.dart';
import '../../widgets/alert_banner.dart';
import '../../widgets/signed_in_builder.dart';
import '../../widgets/state_views.dart';
import '../../widgets/trip_card.dart';
import 'alert_detail_sheet.dart';
import 'trip_detail_screen.dart';

/// Which slice of the activity feed to show.
enum _ActivityFilter { all, trips, alerts }

/// A combined, chronologically-ordered feed of trips and safety alerts.
///
/// Trips and alerts are merged live from Firestore (see
/// [ActivityService.watchActivity]). The "Alerts" filter doubles as the alert
/// log, showing each SOS / fall event with its outcome.
class ActivityFeedScreen extends StatefulWidget {
  const ActivityFeedScreen({super.key, this.service});

  /// Injected for tests; defaults to the Firestore-backed service.
  final ActivityService? service;

  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen> {
  _ActivityFilter _filter = _ActivityFilter.all;
  Stream<List<ActivityItem>>? _stream;
  String? _streamUid;

  Stream<List<ActivityItem>> _streamFor(String uid) {
    if (_stream == null || _streamUid != uid) {
      _streamUid = uid;
      _stream = (widget.service ?? ActivityService()).watchActivity(uid);
    }
    return _stream!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: SignedInBuilder(
        signedOut: const EmptyStateView(
          icon: Icons.lock_outline,
          message: 'Please sign in to view your activity.',
        ),
        signedIn: (context, user) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AegisSpacing.lg,
                AegisSpacing.md,
                AegisSpacing.lg,
                0,
              ),
              child: SegmentedButton<_ActivityFilter>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: _ActivityFilter.all, label: Text('All')),
                  ButtonSegment(
                    value: _ActivityFilter.trips,
                    label: Text('Trips'),
                  ),
                  ButtonSegment(
                    value: _ActivityFilter.alerts,
                    label: Text('Alert Log'),
                  ),
                ],
                selected: {_filter},
                onSelectionChanged: (s) => setState(() => _filter = s.first),
              ),
            ),
            Expanded(child: _buildFeed(user.uid)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeed(String uid) {
    return StreamBuilder<List<ActivityItem>>(
      stream: _streamFor(uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorStateView(error: snapshot.error.toString());
        }
        if (!snapshot.hasData) return const LoadingView();

        final items = snapshot.data!.where((item) {
          switch (_filter) {
            case _ActivityFilter.trips:
              return item.trip != null;
            case _ActivityFilter.alerts:
              return item.alert != null;
            case _ActivityFilter.all:
              return true;
          }
        }).toList();

        if (items.isEmpty) {
          return EmptyStateView(
            icon: _filter == _ActivityFilter.alerts
                ? Icons.verified_user_outlined
                : Icons.notifications_none_outlined,
            message: _filter == _ActivityFilter.alerts
                ? 'No SOS or fall alerts recorded. Stay safe!'
                : 'No activity yet. Your trips and alerts will appear here.',
          );
        }

        return ListView.builder(
          padding: AegisSpacing.list,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            if (item.trip != null) {
              return TripCard(
                trip: item.trip!,
                onTap: () => TripDetailScreen.open(context, item.trip!),
              );
            }
            return AlertBanner(
              alert: item.alert!,
              onTap: () => AlertDetailSheet.show(context, item.alert!),
            );
          },
        );
      },
    );
  }
}
