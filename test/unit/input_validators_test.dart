import 'package:flutter_test/flutter_test.dart';
import 'package:majurun/core/utils/input_validators.dart';

void main() {
  group('InputValidators - Email', () {
    test('valid emails return true', () {
      expect(InputValidators.validateEmail('test@example.com').isValid, true);
      expect(InputValidators.validateEmail('user.name@domain.co.uk').isValid, true);
    });

    test('invalid emails return false', () {
      expect(InputValidators.validateEmail('invalid-email').isValid, false);
      expect(InputValidators.validateEmail('test@').isValid, false);
      expect(InputValidators.validateEmail('').isValid, false);
      expect(InputValidators.validateEmail(null).isValid, false);
    });
  });

  group('InputValidators - Password', () {
    test('strong password returns good/strong strength', () {
      final result = InputValidators.validatePassword('Complex123!');
      expect(result.isValid, true);
      expect(result.strength == PasswordStrength.good || result.strength == PasswordStrength.strong, true);
    });

    test('weak password returns weak strength and errors', () {
      final result = InputValidators.validatePassword('123');
      expect(result.isValid, false);
      expect(result.strength, PasswordStrength.weak);
    });
  });

  group('InputValidators - Username', () {
    test('valid usernames return true', () {
      expect(InputValidators.validateUsername('valid_user').isValid, true);
      expect(InputValidators.validateUsername('user.name').isValid, true);
    });

    test('invalid usernames return false', () {
      expect(InputValidators.validateUsername('ab').isValid, false); // too short
      expect(InputValidators.validateUsername('user@name').isValid, false); // invalid char
      expect(InputValidators.validateUsername('.start').isValid, false); // starts with dot
    });
  });

  group('InputValidators - Sanitization', () {
    test('sanitizes HTML tags', () {
      expect(InputValidators.sanitize('<script>alert("xss")</script>Hello'), 'alert("xss")Hello');
    });

    test('detects malicious content', () {
      expect(InputValidators.containsMaliciousContent('<script>'), true);
      expect(InputValidators.containsMaliciousContent('Safe content'), false);
    });
  });
}
