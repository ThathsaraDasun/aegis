import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/saved_location_model.dart';

class SavedLocationService {
  static const String _storageKey = 'saved_location';

  /// Saves the current GPS location with a label.
  Future<SavedLocation?> saveCurrentLocation(String label) async {
    try {
      // Check if services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final savedLocation = SavedLocation(
        id: const Uuid().v4(),
        label: label,
        latitude: position.latitude,
        longitude: position.longitude,
        savedAt: DateTime.now(),
      );

      await saveLocation(savedLocation);
      return savedLocation;
    } catch (e) {
      debugPrint('Error saving location: $e');
      return null;
    }
  }

  /// Saves an explicit point (e.g. a past trip's destination) as the
  /// compass target.
  Future<SavedLocation> saveLocation(SavedLocation location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, location.toJson());
    return location;
  }

  /// Saves a latitude/longitude pair with a label as the compass target.
  Future<SavedLocation> saveCoordinates({
    required String label,
    required double latitude,
    required double longitude,
  }) {
    return saveLocation(SavedLocation(
      id: const Uuid().v4(),
      label: label,
      latitude: latitude,
      longitude: longitude,
      savedAt: DateTime.now(),
    ));
  }

  /// Retrieves the currently saved location.
  Future<SavedLocation?> getSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_storageKey);
    if (jsonString != null) {
      return SavedLocation.fromJson(jsonString);
    }
    return null;
  }

  /// Clears the saved location.
  Future<void> clearSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
