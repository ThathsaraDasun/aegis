import 'package:flutter/material.dart';
import '../../theme/aegis_theme.dart';

class TripSummaryScreen extends StatelessWidget {
  final String tripId;
  final bool arrivedSafely;

  const TripSummaryScreen({
    super.key,
    required this.tripId,
    required this.arrivedSafely,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AegisColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                arrivedSafely ? Icons.verified_user : Icons.warning_amber_rounded,
                size: 100,
                color: arrivedSafely ? AegisColors.tertiary : AegisColors.primary,
              ),
              const SizedBox(height: 32),
              Text(
                arrivedSafely ? 'Arrived Safely!' : 'Trip Ended (Timeout)',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                arrivedSafely
                    ? 'Your contacts have been notified of your safe arrival. Thank you for using Aegis.'
                    : 'The trip was ended automatically due to a timeout. If you are in danger, use the SOS features.',
                style: const TextStyle(color: AegisColors.textSecondary, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                  child: const Text('RETURN HOME'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
