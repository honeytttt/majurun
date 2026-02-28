/// App configuration loaded from environment at build time
/// Use: flutter build --dart-define=RECAPTCHA_KEY=your_key
class AppConfig {
  AppConfig._();

  // ReCAPTCHA Enterprise site key (public key - safe to include)
  static const String recaptchaSiteKey = String.fromEnvironment(
    'RECAPTCHA_KEY',
    defaultValue: '6LfJE2gsAAAAAP2xeAzsC95tz7jAzim7wAjtarF0',
  );

  // OpenWeatherMap API key
  static const String weatherApiKey = String.fromEnvironment(
    'WEATHER_API_KEY',
    defaultValue: '',
  );

  // Environment
  static const bool isProduction = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  ) == 'production';

  // API base URL
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.majurun.app',
  );
}
