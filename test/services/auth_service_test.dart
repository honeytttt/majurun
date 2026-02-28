import 'package:flutter_test/flutter_test.dart';
import 'package:majurun/core/utils/input_validators.dart';

void main() {
  group('Input Validators', () {
    group('Email Validation', () {
      test('valid email should return isValid true', () {
        expect(InputValidators.validateEmail('test@example.com').isValid, true);
        expect(InputValidators.validateEmail('user.name@domain.co.uk').isValid, true);
        expect(InputValidators.validateEmail('user+tag@example.org').isValid, true);
      });

      test('invalid email should return isValid false', () {
        expect(InputValidators.validateEmail('').isValid, false);
        expect(InputValidators.validateEmail('invalid').isValid, false);
        expect(InputValidators.validateEmail('@nodomain.com').isValid, false);
      });

      test('null email should return isValid false', () {
        expect(InputValidators.validateEmail(null).isValid, false);
      });

      test('invalid email should have error message', () {
        final result = InputValidators.validateEmail('');
        expect(result.isValid, false);
        expect(result.errorMessage, isNotNull);
        expect(result.errorMessage!.isNotEmpty, true);
      });
    });

    group('Password Validation', () {
      test('strong password should return isValid true', () {
        // Strong password: 8+ chars, upper, lower, digit, special
        expect(InputValidators.validatePassword('Password1!').isValid, true);
        expect(InputValidators.validatePassword('SecureP@ss1').isValid, true);
      });

      test('weak password should return isValid false', () {
        expect(InputValidators.validatePassword('short').isValid, false);
        expect(InputValidators.validatePassword('12345678').isValid, false); // No letters
      });

      test('empty password should return isValid false', () {
        expect(InputValidators.validatePassword('').isValid, false);
        expect(InputValidators.validatePassword(null).isValid, false);
      });

      test('password validation returns strength info', () {
        final result = InputValidators.validatePassword('Password1!');
        expect(result.checks.hasMinLength, true);
        expect(result.checks.hasUppercase, true);
        expect(result.checks.hasLowercase, true);
        expect(result.checks.hasNumber, true);
      });
    });

    group('Username Validation', () {
      test('valid username should return isValid true', () {
        expect(InputValidators.validateUsername('johndoe').isValid, true);
        expect(InputValidators.validateUsername('user_123').isValid, true);
        expect(InputValidators.validateUsername('Runner2024').isValid, true);
      });

      test('short username should return isValid false', () {
        expect(InputValidators.validateUsername('ab').isValid, false);
        expect(InputValidators.validateUsername('').isValid, false);
      });
    });
  });

  group('Auth Flow Logic', () {
    test('email normalization', () {
      const email = '  Test@Example.COM  ';
      final normalized = email.trim().toLowerCase();
      expect(normalized, 'test@example.com');
    });

    test('password strength check', () {
      bool isStrongPassword(String password) {
        if (password.length < 8) return false;
        final hasUppercase = password.contains(RegExp(r'[A-Z]'));
        final hasLowercase = password.contains(RegExp(r'[a-z]'));
        final hasDigit = password.contains(RegExp(r'[0-9]'));
        return hasUppercase && hasLowercase && hasDigit;
      }

      expect(isStrongPassword('Weak'), false);
      expect(isStrongPassword('12345678'), false);
      expect(isStrongPassword('Password1'), true);
      expect(isStrongPassword('StrongP@ss123'), true);
    });
  });
}
