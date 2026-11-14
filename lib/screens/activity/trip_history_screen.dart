import 'package:flutter/material.dart';
import '../../models/trip_model.dart';
import '../../services/activity_service.dart';
import '../../theme/aegis_theme.dart';
import '../../widgets/signed_in_builder.dart';
import '../../widgets/state_views.dart';
import '../../widgets/trip_card.dart';
import 'trip_detail_screen.dart';

/// A screen that displays a list of past trips for the current user.
///
/// Data is streamed live from the Firestore 'trips' collection, so new trips
/// appear without a manual refresh. Tapping a trip re-opens its route.
class TripHistoryScreen extends StatelessWidget {
  const TripHistoryScreen({super.key, this.service});

  /// Injected for tests; defaults to the Firestore-backed service.
  final ActivityService? service;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trip History')),
      body: SignedInBuilder(
        signedOut: const EmptyStateView(
          icon: Icons.lock_outline,
          message: 'Please sign in to view your trip history.',
        ),
        signedIn: (context, user) => StreamBuilder<List<TripModel>>(
          stream: (service ?? ActivityService()).watchTrips(user.uid),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorStateView(error: snapshot.error.toString());
            }
            if (!snapshot.hasData) return const LoadingView();

            final trips = snapshot.data!;
            if (trips.isEmpty) {
              return const EmptyStateView(
                icon: Icons.history_outlined,
                message: 'No trips yet. Start your first Safe Walk.',
              );
            }

            return ListView.builder(
              padding: AegisSpacing.list,
              itemCount: trips.length,
              itemBuilder: (context, index) {
                final trip = trips[index];
                return TripCard(
                  trip: trip,
                  onTap: () => TripDetailScreen.open(context, trip),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
