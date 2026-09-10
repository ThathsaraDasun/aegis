import 'dart:async';
import '../../core/models/lat_lng.dart';
import '../../core/models/trip_model.dart';

/// Abstract interface for TripService to allow mocking by the Frontend Lead.
abstract class ITripService {
  /// Starts a new trip, creating a Firestore document at /trips/{tripId} and broadcasting location.
  Future<String> startTrip({
    required String ownerId,
    required Destination destination,
    required List<String> contactIds,
    required String routeChosen,
  });

  /// Streams live location coordinates for map marker binding.
  Stream<LatLng> liveLocationStream(String tripId);

  /// Streams Estimated Time of Arrival (ETA) duration.
  Stream<Duration> etaStream(String tripId);

  /// Streams overdue status boolean.
  Stream<bool> isOverdueStream(String tripId);

  /// Streams silent check-in prompt trigger when stationary mid-trip.
  Stream<bool> silentCheckInPromptStream(String tripId, {Duration threshold});

  /// Ends the trip, stops streaming, and saves trip summary.
  Future<void> endTrip(String tripId);

  /// Retrieves past trip history summaries for a given user ID.
  Future<List<TripSummary>> getTripHistory(String userId);
}

/// Mock implementation of [ITripService] for UI development and testing.
class MockTripService implements ITripService {
  @override
  Future<String> startTrip({
    required String ownerId,
    required Destination destination,
    required List<String> contactIds,
    required String routeChosen,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return 'mock_trip_id_123';
  }

  @override
  Stream<LatLng> liveLocationStream(String tripId) async* {
    yield const LatLng(latitude: 37.7749, longitude: -122.4194);
    await Future.delayed(const Duration(seconds: 3));
    yield const LatLng(latitude: 37.7750, longitude: -122.4190);
    await Future.delayed(const Duration(seconds: 3));
    yield const LatLng(latitude: 37.7752, longitude: -122.4185);
  }

  @override
  Stream<Duration> etaStream(String tripId) async* {
    yield const Duration(minutes: 15);
    await Future.delayed(const Duration(seconds: 5));
    yield const Duration(minutes: 12);
  }

  @override
  Stream<bool> isOverdueStream(String tripId) async* {
    yield false;
  }

  @override
  Stream<bool> silentCheckInPromptStream(String tripId, {Duration threshold = const Duration(minutes: 5)}) async* {
    yield false;
  }

  @override
  Future<void> endTrip(String tripId) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<List<TripSummary>> getTripHistory(String userId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return [
      TripSummary(
        tripId: 'trip_001',
        destinationLabel: 'Home - 42 Wallaby Way',
        date: DateTime.now().subtract(const Duration(days: 1)),
        duration: const Duration(minutes: 25),
        alertOccurred: false,
        routeChosen: 'Safe Corridor via Main St',
      ),
      TripSummary(
        tripId: 'trip_002',
        destinationLabel: 'University Library',
        date: DateTime.now().subtract(const Duration(days: 3)),
        duration: const Duration(minutes: 18),
        alertOccurred: false,
        routeChosen: 'Well-lit Park Path',
      ),
    ];
  }
}
