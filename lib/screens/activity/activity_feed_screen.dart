import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rxdart/rxdart.dart';
import '../../models/alert_model.dart';
import '../../models/trip_model.dart';
import '../../theme/aegis_theme.dart';
import '../../widgets/alert_banner.dart';
import '../../widgets/trip_card.dart';

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
      appBar: AppBar(
        title: const Text('Activity'),
      ),
      body: _useDummyData ? _buildDummyList(context) : _buildCombinedStream(context, user),
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
      return const _EmptyState(message: "Please sign in to view your activity.");
    }

    final tripsStream = FirebaseFirestore.instance
        .collection('trips')
        .where('userId', isEqualTo: user.uid)
        .snapshots();

    final alertsStream = FirebaseFirestore.instance
        .collection('alerts')
        .where('userId', isEqualTo: user.uid)
        .snapshots();

    return StreamBuilder<List<dynamic>>(
      stream: CombineLatestStream.combine2(
        tripsStream,
        alertsStream,
        (QuerySnapshot tripsSnap, QuerySnapshot alertsSnap) {
          // Convert Firestore docs to Model objects
          final trips = tripsSnap.docs.map((d) => TripModel.fromFirestore(d)).toList();
          final alerts = alertsSnap.docs.map((d) => AlertModel.fromFirestore(d)).toList();

          // Merge into one list
          final combined = [...trips, ...alerts];

          // Sort by timestamp descending (most recent first)
          // Trip uses 'startedAt', Alert uses 'triggeredAt'
          combined.sort((a, b) {
            final dateA = (a is TripModel) ? a.startedAt : (a as AlertModel).triggeredAt;
            final dateB = (b is TripModel) ? b.startedAt : (b as AlertModel).triggeredAt;
            return dateB.compareTo(dateA);
          });

          return combined;
        },
      ),
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

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            if (item is TripModel) {
              return TripCard(
                trip: item,
                onTap: () => _showPlaceholder(context, 'Trip: ${item.tripId}'),
              );
            } else if (item is AlertModel) {
              return AlertBanner(
                alert: item,
                onTap: () => _showPlaceholder(context, 'Alert: ${item.alertId}'),
              );
            }
            return const SizedBox.shrink();
          },
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
      final dateA = (a is TripModel) ? a.startedAt : (a as AlertModel).triggeredAt;
      final dateB = (b is TripModel) ? b.startedAt : (b as AlertModel).triggeredAt;
      return dateB.compareTo(dateA);
    });

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: dummyData.length,
      itemBuilder: (context, index) {
        final item = dummyData[index];
        if (item is TripModel) {
          return TripCard(
            trip: item,
            onTap: () => _showPlaceholder(context, 'Dummy Trip: ${item.tripId}'),
          );
        } else if (item is AlertModel) {
          return AlertBanner(
            alert: item,
            onTap: () => _showPlaceholder(context, 'Dummy Alert: ${item.alertId}'),
          );
        }
        return const SizedBox.shrink();
      },
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

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({this.message = "No activity yet. Your trips and alerts will appear here."});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none_outlined,
              size: 64,
              color: AegisColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
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
              style: GoogleFonts.inter(
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
