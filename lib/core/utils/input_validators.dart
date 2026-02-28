/// Input validation utilities for the MajuRun app
/// Provides password strength validation, email validation, and other input checks
class InputValidators {
  InputValidators._();

  // ============== EMAIL VALIDATION ==============

  /// Validate email format
  static ValidationResult validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Email is required',
      );
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(email)) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Please enter a valid email address',
      );
    }

    return ValidationResult(isValid: true);
  }

  // ============== PASSWORD VALIDATION ==============

  /// Password requirements
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;
  static const bool requireUppercase = true;
  static const bool requireLowercase = true;
  static const bool requireNumber = true;
  static const bool requireSpecialChar = true;

  /// Validate password strength
  static PasswordValidationResult validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return PasswordValidationResult(
        isValid: false,
        errorMessage: 'Password is required',
        strength: PasswordStrength.none,
        checks: PasswordChecks.empty(),
      );
    }

    final checks = PasswordChecks(
      hasMinLength: password.length >= minPasswordLength,
      hasMaxLength: password.length <= maxPasswordLength,
      hasUppercase: password.contains(RegExp(r'[A-Z]')),
      hasLowercase: password.contains(RegExp(r'[a-z]')),
      hasNumber: password.contains(RegExp(r'[0-9]')),
      hasSpecialChar: password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\\/`~]')),
    );

    // Calculate strength
    int score = 0;
    if (checks.hasMinLength) score++;
    if (checks.hasUppercase) score++;
    if (checks.hasLowercase) score++;
    if (checks.hasNumber) score++;
    if (checks.hasSpecialChar) score++;
    if (password.length >= 12) score++; // Bonus for longer passwords
    if (password.length >= 16) score++; // Extra bonus for very long passwords

    PasswordStrength strength;
    if (score <= 2) {
      strength = PasswordStrength.weak;
    } else if (score <= 4) {
      strength = PasswordStrength.fair;
    } else if (score <= 5) {
      strength = PasswordStrength.good;
    } else {
      strength = PasswordStrength.strong;
    }

    // Check if all required checks pass
    final List<String> errors = [];
    if (!checks.hasMinLength) {
      errors.add('At least $minPasswordLength characters');
    }
    if (!checks.hasMaxLength) {
      errors.add('Maximum $maxPasswordLength characters');
    }
    if (requireUppercase && !checks.hasUppercase) {
      errors.add('One uppercase letter');
    }
    if (requireLowercase && !checks.hasLowercase) {
      errors.add('One lowercase letter');
    }
    if (requireNumber && !checks.hasNumber) {
      errors.add('One number');
    }
    if (requireSpecialChar && !checks.hasSpecialChar) {
      errors.add('One special character (!@#\$%^&*)');
    }

    final isValid = errors.isEmpty;

    return PasswordValidationResult(
      isValid: isValid,
      errorMessage: isValid ? null : 'Password must contain: ${errors.join(", ")}',
      strength: strength,
      checks: checks,
    );
  }

  /// Validate password confirmation
  static ValidationResult validatePasswordConfirmation(
    String? password,
    String? confirmation,
  ) {
    if (confirmation == null || confirmation.isEmpty) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Please confirm your password',
      );
    }

    if (password != confirmation) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Passwords do not match',
      );
    }

    return ValidationResult(isValid: true);
  }

  // ============== USERNAME VALIDATION ==============

  static const int minUsernameLength = 3;
  static const int maxUsernameLength = 30;

  /// Validate username
  static ValidationResult validateUsername(String? username) {
    if (username == null || username.isEmpty) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Username is required',
      );
    }

    if (username.length < minUsernameLength) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Username must be at least $minUsernameLength characters',
      );
    }

    if (username.length > maxUsernameLength) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Username must be less than $maxUsernameLength characters',
      );
    }

    // Only allow alphanumeric, underscores, and periods
    final usernameRegex = RegExp(r'^[a-zA-Z0-9._]+$');
    if (!usernameRegex.hasMatch(username)) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Username can only contain letters, numbers, underscores, and periods',
      );
    }

    // Cannot start or end with period or underscore
    if (username.startsWith('.') ||
        username.startsWith('_') ||
        username.endsWith('.') ||
        username.endsWith('_')) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Username cannot start or end with . or _',
      );
    }

    // Cannot have consecutive periods or underscores
    if (username.contains('..') || username.contains('__')) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Username cannot have consecutive . or _',
      );
    }

    return ValidationResult(isValid: true);
  }

  // ============== DISPLAY NAME VALIDATION ==============

  static const int minDisplayNameLength = 1;
  static const int maxDisplayNameLength = 50;

  /// Validate display name
  static ValidationResult validateDisplayName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Display name is required',
      );
    }

    final trimmedName = name.trim();

    if (trimmedName.length < minDisplayNameLength) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Display name is too short',
      );
    }

    if (trimmedName.length > maxDisplayNameLength) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Display name must be less than $maxDisplayNameLength characters',
      );
    }

    return ValidationResult(isValid: true);
  }

  // ============== NUMERIC INPUT VALIDATION ==============

  /// Validate weight input (kg)
  static ValidationResult validateWeight(String? weight) {
    if (weight == null || weight.isEmpty) {
      return ValidationResult(isValid: true); // Weight is optional
    }

    final value = double.tryParse(weight);
    if (value == null) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Please enter a valid number',
      );
    }

    if (value < 20 || value > 500) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Weight must be between 20 and 500 kg',
      );
    }

    return ValidationResult(isValid: true);
  }

  /// Validate height input (cm)
  static ValidationResult validateHeight(String? height) {
    if (height == null || height.isEmpty) {
      return ValidationResult(isValid: true); // Height is optional
    }

    final value = double.tryParse(height);
    if (value == null) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Please enter a valid number',
      );
    }

    if (value < 50 || value > 300) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Height must be between 50 and 300 cm',
      );
    }

    return ValidationResult(isValid: true);
  }

  /// Validate age
  static ValidationResult validateAge(String? age) {
    if (age == null || age.isEmpty) {
      return ValidationResult(isValid: true); // Age is optional
    }

    final value = int.tryParse(age);
    if (value == null) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Please enter a valid number',
      );
    }

    if (value < 13 || value > 120) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Age must be between 13 and 120',
      );
    }

    return ValidationResult(isValid: true);
  }

  // ============== POST/COMMENT VALIDATION ==============

  static const int maxPostLength = 500;
  static const int maxCommentLength = 200;

  /// Validate post content
  static ValidationResult validatePostContent(String? content) {
    if (content == null || content.trim().isEmpty) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Post content is required',
      );
    }

    if (content.length > maxPostLength) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Post must be less than $maxPostLength characters',
      );
    }

    return ValidationResult(isValid: true);
  }

  /// Validate comment content
  static ValidationResult validateComment(String? content) {
    if (content == null || content.trim().isEmpty) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Comment cannot be empty',
      );
    }

    if (content.length > maxCommentLength) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Comment must be less than $maxCommentLength characters',
      );
    }

    return ValidationResult(isValid: true);
  }

  // ============== SANITIZATION ==============

  /// Sanitize string input (remove dangerous characters)
  static String sanitize(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll(RegExp(r'javascript:', caseSensitive: false), '')
        .replaceAll(RegExp(r'on\w+=', caseSensitive: false), '')
        .trim();
  }

  /// Check for potentially malicious content
  static bool containsMaliciousContent(String input) {
    final patterns = [
      RegExp(r'<script', caseSensitive: false),
      RegExp(r'javascript:', caseSensitive: false),
      RegExp(r'on\w+=', caseSensitive: false),
      RegExp(r'data:', caseSensitive: false),
      RegExp(r'vbscript:', caseSensitive: false),
    ];

    return patterns.any((pattern) => pattern.hasMatch(input));
  }
}

// ============== RESULT CLASSES ==============

/// Basic validation result
class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  ValidationResult({
    required this.isValid,
    this.errorMessage,
  });
}

/// Password validation result with strength indicator
class PasswordValidationResult extends ValidationResult {
  final PasswordStrength strength;
  final PasswordChecks checks;

  PasswordValidationResult({
    required super.isValid,
    super.errorMessage,
    required this.strength,
    required this.checks,
  });
}

/// Password strength levels
enum PasswordStrength {
  none,
  weak,
  fair,
  good,
  strong,
}

/// Extension for password strength display
extension PasswordStrengthExtension on PasswordStrength {
  String get label {
    switch (this) {
      case PasswordStrength.none:
        return '';
      case PasswordStrength.weak:
        return 'Weak';
      case PasswordStrength.fair:
        return 'Fair';
      case PasswordStrength.good:
        return 'Good';
      case PasswordStrength.strong:
        return 'Strong';
    }
  }

  double get progressValue {
    switch (this) {
      case PasswordStrength.none:
        return 0.0;
      case PasswordStrength.weak:
        return 0.25;
      case PasswordStrength.fair:
        return 0.5;
      case PasswordStrength.good:
        return 0.75;
      case PasswordStrength.strong:
        return 1.0;
    }
  }

  int get colorValue {
    switch (this) {
      case PasswordStrength.none:
        return 0xFF9E9E9E; // Grey
      case PasswordStrength.weak:
        return 0xFFF44336; // Red
      case PasswordStrength.fair:
        return 0xFFFF9800; // Orange
      case PasswordStrength.good:
        return 0xFF2196F3; // Blue
      case PasswordStrength.strong:
        return 0xFF4CAF50; // Green
    }
  }
}

/// Individual password requirement checks
class PasswordChecks {
  final bool hasMinLength;
  final bool hasMaxLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasNumber;
  final bool hasSpecialChar;

  PasswordChecks({
    required this.hasMinLength,
    required this.hasMaxLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasNumber,
    required this.hasSpecialChar,
  });

  factory PasswordChecks.empty() {
    return PasswordChecks(
      hasMinLength: false,
      hasMaxLength: true,
      hasUppercase: false,
      hasLowercase: false,
      hasNumber: false,
      hasSpecialChar: false,
    );
  }
}
