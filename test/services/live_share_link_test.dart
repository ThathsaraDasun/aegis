import 'package:aegis/services/live_share_link.dart';
import 'package:aegis/services/share_token.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final token = ShareToken.generate();

  test('builds aegis://live/<token>', () {
    expect(LiveShareLink.build(token), 'aegis://live/$token');
  });

  test('parses every form Android can hand to Flutter', () {
    expect(LiveShareLink.tokenFromRoute('aegis://live/$token'), token);
    expect(LiveShareLink.tokenFromRoute('/live/$token'), token);
    expect(LiveShareLink.tokenFromRoute('/$token'), token);
    expect(
      LiveShareLink.tokenFromRoute(LiveShareLink.build(token)),
      token,
    );
  });

  test('ignores routes that are not live links', () {
    for (final route in <String?>[
      null,
      '',
      '/',
      '/live',
      '/live/',
      'aegis://other/$token',
      'aegis://live/',
      'aegis://live/$token/extra',
      'https://example.com/$token',
      '/a/b/c',
    ]) {
      expect(LiveShareLink.tokenFromRoute(route), isNull, reason: '$route');
    }
  });
}
