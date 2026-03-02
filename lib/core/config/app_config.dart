/// App configuration loaded from environment at build time
///
/// Usage:
/// ```bash
/// flutter build appbundle --release \
///   --dart-define=CLOUDINARY_CLOUD_NAME=your_cloud \
///   --dart-define=CLOUDINARY_API_KEY=your_key \
///   --dart-define=CLOUDINARY_UPLOAD_PRESET=your_preset \
///   --dart-define=WEATHER_API_KEY=your_key \
///   --dart-define=GOOGLE_MAPS_KEY=your_key \
///   --dart-define=ENVIRONMENT=production
/// ```
///
/// Or use a .env file with build scripts (see scripts/build_release.sh)
class AppConfig {
  AppConfig._();

  // ==================== ENVIRONMENT ====================

  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  static bool get isProduction => environment == 'production';
  static bool get isDevelopment => environment == 'development';

  // ==================== CLOUDINARY ====================

  static const String cloudinaryCloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: '', // Must be provided at build time
  );

  static const String cloudinaryApiKey = String.fromEnvironment(
    'CLOUDINARY_API_KEY',
    defaultValue: '', // Must be provided at build time
  );

  static const String cloudinaryUploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: '', // Must be provided at build time
  );

  // ==================== WEATHER ====================

  static const String weatherApiKey = String.fromEnvironment(
    'WEATHER_API_KEY',
    defaultValue: '',
  );

  // ==================== GOOGLE MAPS ====================

  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_KEY',
    defaultValue: '', // Fallback to native config if empty
  );

  // ==================== RECAPTCHA ====================

  // ReCAPTCHA Enterprise site key (public key - safe to include default)
  static const String recaptchaSiteKey = String.fromEnvironment(
    'RECAPTCHA_KEY',
    defaultValue: '6LfJE2gsAAAAAP2xeAzsC95tz7jAzim7wAjtarF0',
  );

  // ==================== API ====================

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.majurun.com',
  );

  // ==================== VALIDATION ====================

  /// Check if all required config is provided
  static bool get isConfigured {
    return cloudinaryCloudName.isNotEmpty &&
        cloudinaryApiKey.isNotEmpty &&
        cloudinaryUploadPreset.isNotEmpty;
  }

  /// Get list of missing required configs (for debugging)
  static List<String> get missingConfigs {
    final missing = <String>[];
    if (cloudinaryCloudName.isEmpty) missing.add('CLOUDINARY_CLOUD_NAME');
    if (cloudinaryApiKey.isEmpty) missing.add('CLOUDINARY_API_KEY');
    if (cloudinaryUploadPreset.isEmpty) missing.add('CLOUDINARY_UPLOAD_PRESET');
    return missing;
  }
}
