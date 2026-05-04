import 'package:flutter_test/flutter_test.dart';
import 'package:majurun/core/services/weather_service.dart';

void main() {
  group('WeatherData', () {
    test('safetyRating should be 5 for perfect conditions', () {
      final weather = WeatherData(
        temperatureCelsius: 20.0,
        feelsLikeCelsius: 20.0,
        condition: WeatherCondition.clear,
        description: 'Clear sky',
        humidity: 50,
        windSpeedKmh: 5.0,
        windDirection: 180,
        timestamp: DateTime.now(),
        locationName: 'Test City',
        visibility: 10000,
      );

      expect(weather.safetyRating, 5);
      expect(weather.safetyRatingText, 'Perfect');
    });

    test('safetyRating should be lower for extreme heat', () {
      final weather = WeatherData(
        temperatureCelsius: 36.0,
        feelsLikeCelsius: 40.0,
        condition: WeatherCondition.clear,
        description: 'Clear sky',
        humidity: 40,
        windSpeedKmh: 5.0,
        windDirection: 180,
        timestamp: DateTime.now(),
        locationName: 'Test City',
        visibility: 10000,
      );

      expect(weather.safetyRating, lessThan(5));
    });

    test('safetyRating should be Dangerous for thunderstorms', () {
      final weather = WeatherData(
        temperatureCelsius: 20.0,
        feelsLikeCelsius: 20.0,
        condition: WeatherCondition.thunderstorm,
        description: 'Thunderstorm',
        humidity: 90,
        windSpeedKmh: 45.0,
        windDirection: 180,
        timestamp: DateTime.now(),
        locationName: 'Test City',
        visibility: 1000,
      );

      expect(weather.safetyRatingText, 'Dangerous');
    });
  });

  group('WeatherService', () {
    late WeatherService weatherService;

    setUp(() {
      weatherService = WeatherService();
    });

    test('getRunningTips should return empty list when no weather is loaded', () {
      expect(weatherService.getRunningTips(), isEmpty);
    });
  });
}
