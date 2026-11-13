import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/activity_service.dart';
import '../../theme/aegis_theme.dart';
import '../../widgets/alert_banner.dart';
import '../../widgets/signed_in_builder.dart';
import '../../widgets/state_views.dart';
import '../../widgets/trip_card.dart';
import 'alert_detail_sheet.dart';
import 'trip_detail_screen.dart';
import 'trip_history_screen.dart';

/// Dashboard block showing any unresolved alert and the most recent trip,
/// streamed live from Firestore.
class RecentActivityPreview extends StatefulWidget {
  const RecentActivityPreview({super.key, this.service});

  final ActivityService? service;

  @override
  State<RecentActivityPreview> createState() => _RecentActivityPreviewState();
}

class _RecentActivityPreviewState extends State<RecentActivityPreview> {
  Stream<List<ActivityItem>>? _stream;
  String? _uid;

  @override
  Widget build(BuildContext context) {
    return SignedInBuilder(
      signedOut: const SizedBox.shrink(),
      signedIn: _buildFor,
    );
  }

  Widget _buildFor(BuildContext context, User user) {
    if (_stream == null || _uid != user.uid) {
      _uid = user.uid;
      _stream = (widget.service ?? ActivityService()).watchActivity(user.uid);
    }

    return StreamBuilder<List<ActivityItem>>(
      stream: _stream,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <ActivityItem>[];
        final openAlert = items
            .where((i) => i.alert != null && !i.alert!.resolved)
            .map((i) => i.alert!)
            .firstOrNull;
        final lastTrip = items.where((i) => i.trip != null).map((i) => i.trip!).firstOrNull;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (openAlert != null) ...[
              AlertBanner(alert: openAlert, onTap: () => AlertDetailSheet.show(context, openAlert)),
              const SizedBox(height: AegisSpacing.lg),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SectionHeader('Recent Trips'),
                Padding(
                  padding: const EdgeInsets.only(bottom: AegisSpacing.md),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TripHistoryScreen()),
                    ),
                    child: Text('See all', style: AegisText.caption.copyWith(color: AegisColors.primary)),
                  ),
                ),
              ],
            ),
            if (lastTrip != null)
              TripCard(trip: lastTrip, onTap: () => TripDetailScreen.open(context, lastTrip))
            else
              Text(
                snapshot.hasData ? 'No trips yet. Start your first Safe Walk above.' : 'Loading recent trips...',
                style: AegisText.bodySecondary,
              ),
          ],
        );
      },
    );
  }
}
