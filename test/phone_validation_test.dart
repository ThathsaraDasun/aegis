import 'package:aegis/services/contacts_service.dart';
import 'package:aegis/services/phone_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PhoneValidation', () {
    test('Sri Lankan numbers in any common format are accepted and '
        'normalised to +94', () {
      for (final input in [
        '0771234567',
        '077 123 4567',
        '077-123-4567',
        '(077) 1234567',
        '+94771234567',
        '+94 77 123 4567',
        '0094771234567',
        '94771234567',
      ]) {
        expect(PhoneValidation.validate(input), isNull, reason: input);
        expect(PhoneValidation.normalize(input), '+94771234567', reason: input);
      }
    });

    test('a Sri Lankan mobile saved without its leading 0 is understood', () {
      // e.g. an older guardian saved as 763358267
      expect(PhoneValidation.normalize('763358267'), '+94763358267');
      expect(PhoneValidation.validate('763358267'), isNull);
      expect(ContactsService.validatePhone('763358267'), isNull);
    });

    test('other countries need the international form', () {
      expect(PhoneValidation.validate('+447911123456'), isNull);
      expect(PhoneValidation.validate('+14155552671'), isNull);
      expect(PhoneValidation.validate('447911123456'), isNotNull);
    });

    test('invalid numbers explain the problem', () {
      expect(PhoneValidation.validate('abc'), contains('digits only'));
      expect(PhoneValidation.validate('077123'), contains('10 digits'));
      expect(PhoneValidation.validate('07712345678'), contains('10 digits'));
      expect(PhoneValidation.validate('+9477123'), contains('9 digits'));
      expect(PhoneValidation.validate('+94071234567'), isNotNull);
      expect(PhoneValidation.validate('12345'), isNotNull);
      expect(PhoneValidation.validate('+12'), isNotNull);
    });

    test('empty is allowed only when the field is optional', () {
      expect(PhoneValidation.validate('', required: false), isNull);
      expect(PhoneValidation.validate('  ', required: false), isNull);
      expect(PhoneValidation.validate(''), isNotNull);
    });

    test('guardians must be mobiles so SMS alerts can be delivered', () {
      expect(ContactsService.validatePhone('0771234567'), isNull);
      expect(ContactsService.validatePhone('0112345678'), contains('mobile'));
      expect(ContactsService.validatePhone(''), isNotNull);
      // Landlines are fine for the user's own optional profile number.
      expect(PhoneValidation.validate('0112345678', required: false), isNull);
    });
  });
}
