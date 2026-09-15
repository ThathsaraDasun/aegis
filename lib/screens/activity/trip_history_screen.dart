import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/trip_model.dart';
import '../../theme/aegis_theme.dart';
import '../../widgets/trip_card.dart';

/// Toggle this to [true] to test the UI with hardcoded data without Firestore.
const bool _useDummyData = true;

/// A screen that displays a list of past trips for the current user.
/// 
/// Data is streamed live from the Firestore 'trips' collection.
class TripHistoryScreen extends StatelessWidget {
  const TripHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AegisColors.background,
      appBar: AppBar(
        title: Text(
          'Trip History',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AegisColors.surfaceContainerLow,
        elevation: 0,
        centerTitle: true,
      ),
      body: _useDummyData ? _buildDummyList() : _buildFirestoreStream(user),
    );
  }

  Widget _buildFirestoreStream(User? user) {
    if (user == null) {
      return const _EmptyState(message: "Please sign in to view your history.");
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('trips')
          .where('userId', isEqualTo: user.uid)
          .orderBy('startedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorState(
            error: snapshot.error.toString(),
            onRetry: () {
              // StreamBuilder automatically retries on rebuild
              (context as Element).markNeedsBuild();
            },
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: AegisColors.primary,
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const _EmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final trip = TripModel.fromFirestore(docs[index]);
            return TripCard(
              trip: trip,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Trip ID: ${trip.tripId}'),
                    backgroundColor: AegisColors.surfaceContainerHighest,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // TODO: remove dummy data, using Firestore stream above
  Widget _buildDummyList() {
    final now = DateTime.now();
    final List<TripModel> dummyTrips = [
      TripModel(
        tripId: 'dummy-1',
        userId: 'test-user',
        status: 'completed',
        startLocation: {'lat': 6.9271, 'lng': 79.8612},
        currentLocation: {'lat': 6.9344, 'lng': 79.8451},
        destination: {'lat': 6.9344, 'lng': 79.8451},
        startedAt: now.subtract(const Duration(hours: 2)),
        endedAt: now.subtract(const Duration(hours: 1, minutes: 30)),
      ),
      TripModel(
        tripId: 'dummy-2',
        userId: 'test-user',
        status: 'alerted',
        startLocation: {'lat': 6.9271, 'lng': 79.8612},
        currentLocation: {'lat': 6.9280, 'lng': 79.8620},
        destination: {'lat': 6.9400, 'lng': 79.8500},
        startedAt: now.subtract(const Duration(days: 1)),
        endedAt: now.subtract(const Duration(days: 1, hours: -1)),
      ),
      TripModel(
        tripId: 'dummy-3',
        userId: 'test-user',
        status: 'completed',
        startLocation: {'lat': 6.9100, 'lng': 79.8800},
        currentLocation: {'lat': 6.9200, 'lng': 79.8700},
        destination: {'lat': 6.9200, 'lng': 79.8700},
        startedAt: now.subtract(const Duration(days: 2)),
        endedAt: now.subtract(const Duration(days: 2, hours: -1)),
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: dummyTrips.length,
      itemBuilder: (context, index) {
        final trip = dummyTrips[index];
        return TripCard(
          trip: trip,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Dummy Trip ID: ${trip.tripId}'),
                backgroundColor: AegisColors.surfaceContainerHighest,
              ),
            );
          },
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({this.message = "No trips yet — start your first Safe Walk"});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_outlined,
              size: 64,
              color: AegisColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: AegisColors.textSecondary,
                fontSize: 16,
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
              size: 48,
              color: Colors.redAccent,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
