import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/aegis_theme.dart';
import '../services/location_service.dart';

class LocationPermissionPrompt extends StatelessWidget {
  final LocationStatus status;
  final VoidCallback onRetry;

  const LocationPermissionPrompt({
    super.key, 
    required this.status, 
    required this.onRetry
  });

  @override
  Widget build(BuildContext context) {
    String title;
    String message;
    IconData icon;

    switch (status) {
      case LocationStatus.serviceDisabled:
        title = 'GPS is Turned Off';
        message = 'Your device location services are disabled. Please turn on GPS to start your safe walk.';
        icon = Icons.location_off;
        break;
      case LocationStatus.permissionDenied:
        title = 'Location Permission Denied';
        message = 'Aegis needs access to your location to share your journey with guardians. Please allow access.';
        icon = Icons.security_outlined;
        break;
      case LocationStatus.permissionPermanentlyDenied:
        title = 'Permission Locked';
        message = 'Location permissions are permanently denied in system settings. Please enable them manually to continue.';
        icon = Icons.lock_outline;
        break;
      default:
        title = 'Location Required';
        message = 'Something went wrong while accessing location. Please try again.';
        icon = Icons.error_outline;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 80, color: AegisColors.primary),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: AegisColors.textSecondary, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(backgroundColor: AegisColors.primary),
                child: const Text('TRY AGAIN'),
              ),
            ),
            if (status != LocationStatus.serviceDisabled)
              TextButton(
                onPressed: () => Geolocator.openAppSettings(),
                child: const Text(
                  'OPEN SYSTEM SETTINGS',
                  style: TextStyle(color: AegisColors.secondary, fontWeight: FontWeight.bold),
                ),
              ),
            if (status == LocationStatus.serviceDisabled)
              TextButton(
                onPressed: () => Geolocator.openLocationSettings(),
                child: const Text(
                  'OPEN LOCATION SETTINGS',
                  style: TextStyle(color: AegisColors.secondary, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
