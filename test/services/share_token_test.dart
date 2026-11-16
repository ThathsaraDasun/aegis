import 'dart:math';

import 'package:aegis/services/share_token.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShareToken', () {
    test('is 64 lowercase hex characters (32 random bytes)', () {
      final token = ShareToken.generate();
      expect(token.length, ShareToken.length);
      expect(token.length, greaterThanOrEqualTo(32));
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(token), isTrue);
      expect(ShareToken.isValid(token), isTrue);
    });

    test('does not repeat across many generations', () {
      final tokens = {for (var i = 0; i < 2000; i++) ShareToken.generate()};
      expect(tokens.length, 2000);
    });

    test('is deterministic only when a seeded RNG is injected', () {
      expect(ShareToken.generate(Random(7)), ShareToken.generate(Random(7)));
      expect(ShareToken.generate(Random(7)), isNot(ShareToken.generate(Random(8))));
    });

    test('rejects empty, short, uppercase, UUID-shaped and null tokens', () {
      final valid = ShareToken.generate();
      for (final bad in <String?>[
        null,
        '',
        valid.substring(1),
        '${valid}0',
        valid.toUpperCase(),
        '00000000-0000-4000-8000-000000000000',
        '${valid.substring(0, 63)}g',
      ]) {
        expect(ShareToken.isValid(bad), isFalse, reason: '$bad');
      }
    });
  });
}
