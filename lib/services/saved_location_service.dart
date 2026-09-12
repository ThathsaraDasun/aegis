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
        desiredAccuracy: LocationAccuracy.high,
      );

      final savedLocation = SavedLocation(
        id: const Uuid().v4(),
        label: label,
        latitude: position.latitude,
        longitude: position.longitude,
        savedAt: DateTime.now(),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, savedLocation.toJson());

      return savedLocation;
    } catch (e) {
      print('Error saving location: $e');
      return null;
    }
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
