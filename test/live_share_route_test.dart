import 'package:aegis/screens/trip/live_share_route.dart';
import 'package:aegis/services/share_token.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final token = ShareToken.generate();

  test('live links get a viewer route; normal routes do not', () {
    for (final link in ['aegis://live/$token', '/live/$token', '/$token']) {
      final route = liveShareRoute(link);
      expect(route, isNotNull, reason: link);
      expect(route!.settings.name, link);
    }
    expect(liveShareRoute(Navigator.defaultRouteName), isNull);
    expect(liveShareRoute(null), isNull);
  });

  test('unknown routes fall back to the invalid-link viewer', () {
    final route = invalidLiveShareRoute(const RouteSettings(name: '/x/y'));
    expect(route.settings.name, '/x/y');
  });
}
