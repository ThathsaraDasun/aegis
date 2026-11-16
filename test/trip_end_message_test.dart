import 'package:aegis/services/alert_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Trip-end guardian message', () {
    test('arrived safely says so and does not include a location', () {
      final message = AlertService.buildTripEndMessage(
        arrivedSafely: true,
        lat: 6.9,
        lng: 79.8,
      );
      expect(message, contains('I have arrived safely'));
      expect(message, isNot(contains('maps.google.com')));
    });

    test('unconfirmed end asks guardians to check and gives last location', () {
      final message = AlertService.buildTripEndMessage(
        arrivedSafely: false,
        lat: 6.9,
        lng: 79.8,
      );
      expect(message, contains('without me confirming'));
      expect(message, contains('Please check on me'));
      expect(message, contains('https://maps.google.com/?q=6.9,79.8'));
    });

    test('unconfirmed end without a valid location omits the link', () {
      for (final (lat, lng) in [
        (null, null),
        (double.nan, 79.8),
        (95.0, 79.8),
        (6.9, 200.0),
      ]) {
        final message = AlertService.buildTripEndMessage(
          arrivedSafely: false,
          lat: lat,
          lng: lng,
        );
        expect(message, contains('Please check on me'));
        expect(message, isNot(contains('maps.google.com')));
      }
    });
  });
}
