import 'dart:math';

import 'package:aegis/services/alert_service.dart';
import 'package:aegis/services/trip_share_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Trip live sharing', () {
    test('tokens are 64 lowercase hex characters and unique', () {
      final a = TripShareService.newToken();
      final b = TripShareService.newToken();
      expect(a, matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(b, matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(a, isNot(b));
    });

    test('token generation is deterministic for a seeded generator', () {
      expect(
        TripShareService.newToken(Random(1)),
        TripShareService.newToken(Random(1)),
      );
    });

    test('guardian link is an https trip-viewer link with the token in the '
        'fragment', () {
      final token = TripShareService.newToken(Random(7));
      final link = TripShareService.linkFor(token);
      final uri = Uri.parse(link);
      expect(uri.scheme, 'https');
      expect(uri.host, 'aegis-45002.web.app');
      expect(uri.path, '/trip/');
      // The token is in the fragment, so it is never sent to the web server.
      expect(uri.fragment, token);
    });

    test('trip-start message to guardians includes the live trip link', () {
      final link = TripShareService.linkFor(
        TripShareService.newToken(Random(3)),
      );
      expect(
        AlertService.buildTripStartMessage(
          lat: 6.9,
          lng: 79.8,
          liveLocationUrl: link,
        ),
        'I started a Safe Walk. Follow my live location: $link',
      );
    });

    test('sharing is not started where Firebase is not initialised', () async {
      expect(TripShareService.supported, isFalse);
      final link = await TripShareService.instance.start(
        tripId: 'trip-1',
        lat: 6.9,
        lng: 79.8,
        destination: const {'lat': 6.91, 'lng': 79.81},
      );
      expect(link, isNull);
      expect(TripShareService.instance.isSharing('trip-1'), isFalse);
    });

    test('a trip auto-ends before its link can expire', () {
      // LiveMapScreen auto-ends a trip after 90 minutes; the link must stay
      // valid at least that long and within the 12-hour rule limit.
      expect(TripShareService.maxAge, greaterThan(const Duration(minutes: 90)));
      expect(
        TripShareService.maxAge,
        lessThanOrEqualTo(const Duration(hours: 12)),
      );
    });
  });
}
