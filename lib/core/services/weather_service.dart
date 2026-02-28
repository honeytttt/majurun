import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Weather Service - Show conditions during run
/// Displays temperature, humidity, wind, and weather-appropriate tips
class WeatherService extends ChangeNotifier {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();

  WeatherData? _currentWeather;
  bool _isLoading = false;
  String? _error;

  WeatherData? get currentWeather => _currentWeather;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // OpenWeatherMap API - Set via environment or configure before use
  // Get free API key at: https://openweathermap.org/api
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';

  String? _apiKey;

  /// Set the OpenWeatherMap API key
  void setApiKey(String key) {
    _apiKey = key;
  }

  /// Fetch current weather for coordinates
  Future<WeatherData?> fetchWeather(double latitude, double longitude) async {
    // Skip if no API key configured
    if (_apiKey == null || _apiKey!.isEmpty) {
      debugPrint('Weather: No API key configured');
      _error = 'Weather not configured';
      return null;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final url = '$_baseUrl/weather?lat=$latitude&lon=$longitude&units=metric&appid=$_apiKey';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _currentWeather = WeatherData.fromOpenWeatherMap(data);
        _isLoading = false;
        notifyListeners();
        return _currentWeather;
      } else {
        _error = 'Failed to fetch weather';
        _isLoading = false;
        notifyListeners();
        return null;
      }
    } catch (e) {
      debugPrint('Weather fetch error: $e');
      _error = 'Weather unavailable';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Get weather-based running tips
  List<String> getRunningTips() {
    if (_currentWeather == null) return [];

    List<String> tips = [];
    final weather = _currentWeather!;

    // Temperature tips
    if (weather.temperatureCelsius < 5) {
      tips.add('Layer up! Consider gloves and a hat.');
      tips.add('Warm up indoors before heading out.');
    } else if (weather.temperatureCelsius < 10) {
      tips.add('Cool weather - great for running!');
      tips.add('Light layers that you can remove.');
    } else if (weather.temperatureCelsius > 25) {
      tips.add('Hot weather - hydrate before and during!');
      tips.add('Consider running early morning or evening.');
    } else if (weather.temperatureCelsius > 30) {
      tips.add('Extreme heat warning! Consider indoor workout.');
      tips.add('If running, take water and seek shade.');
    }

    // Humidity tips
    if (weather.humidity > 80) {
      tips.add('High humidity - pace yourself.');
      tips.add('Your body will work harder to cool down.');
    }

    // Wind tips
    if (weather.windSpeedKmh > 30) {
      tips.add('Strong winds - start into the wind, finish with it.');
      tips.add('Wind resistance will slow you down.');
    }

    // Condition tips
    switch (weather.condition) {
      case WeatherCondition.rain:
      case WeatherCondition.drizzle:
        tips.add('Wear water-resistant gear.');
        tips.add('Watch for slippery surfaces.');
        break;
      case WeatherCondition.snow:
        tips.add('Icy conditions - consider trail shoes.');
        tips.add('Shorten your stride for stability.');
        break;
      case WeatherCondition.thunderstorm:
        tips.add('Lightning danger! Run indoors instead.');
        break;
      case WeatherCondition.fog:
        tips.add('Wear bright/reflective clothing.');
        tips.add('Stay visible to traffic.');
        break;
      default:
        break;
    }

    // UV tips
    if (weather.uvIndex != null && weather.uvIndex! > 6) {
      tips.add('High UV - wear sunscreen and sunglasses.');
    }

    return tips;
  }

  /// Get a simple weather summary for voice announcement
  String getWeatherAnnouncement() {
    if (_currentWeather == null) return '';

    final weather = _currentWeather!;
    return 'Current conditions: ${weather.temperatureCelsius.round()} degrees, ${weather.description}. ${_getQuickTip()}';
  }

  String _getQuickTip() {
    if (_currentWeather == null) return '';

    final weather = _currentWeather!;
    if (weather.temperatureCelsius > 28) return 'Stay hydrated!';
    if (weather.temperatureCelsius < 5) return 'Stay warm!';
    if (weather.condition == WeatherCondition.rain) return 'Watch for puddles!';
    if (weather.windSpeedKmh > 25) return 'Windy conditions ahead!';
    return 'Great conditions for running!';
  }

  /// Calculate feels-like temperature considering wind chill and heat index
  double calculateFeelsLike(double temp, double humidity, double windSpeed) {
    if (temp < 10 && windSpeed > 5) {
      // Wind chill formula
      return 13.12 + 0.6215 * temp - 11.37 * pow(windSpeed, 0.16) + 0.3965 * temp * pow(windSpeed, 0.16);
    } else if (temp > 26 && humidity > 40) {
      // Heat index formula (simplified)
      return temp + 0.33 * (humidity / 100 * 6.105 * exp(17.27 * temp / (237.7 + temp))) - 4;
    }
    return temp;
  }

  double pow(double base, double exponent) {
    return _pow(base, exponent);
  }

  static double _pow(double base, double exponent) {
    double result = 1;
    for (int i = 0; i < exponent.floor(); i++) {
      result *= base;
    }
    return result;
  }

  double exp(double x) {
    return _exp(x);
  }

  static double _exp(double x) {
    double result = 1;
    double term = 1;
    for (int i = 1; i <= 20; i++) {
      term *= x / i;
      result += term;
    }
    return result;
  }
}

// Data classes

enum WeatherCondition {
  clear,
  clouds,
  rain,
  drizzle,
  thunderstorm,
  snow,
  fog,
  other,
}

extension WeatherConditionExtension on WeatherCondition {
  String get icon {
    switch (this) {
      case WeatherCondition.clear:
        return '☀️';
      case WeatherCondition.clouds:
        return '☁️';
      case WeatherCondition.rain:
        return '🌧️';
      case WeatherCondition.drizzle:
        return '🌦️';
      case WeatherCondition.thunderstorm:
        return '⛈️';
      case WeatherCondition.snow:
        return '❄️';
      case WeatherCondition.fog:
        return '🌫️';
      case WeatherCondition.other:
        return '🌡️';
    }
  }
}

class WeatherData {
  final double temperatureCelsius;
  final double feelsLikeCelsius;
  final int humidity;
  final double windSpeedKmh;
  final int windDirection;
  final WeatherCondition condition;
  final String description;
  final int? uvIndex;
  final int visibility;
  final DateTime timestamp;
  final String locationName;

  const WeatherData({
    required this.temperatureCelsius,
    required this.feelsLikeCelsius,
    required this.humidity,
    required this.windSpeedKmh,
    required this.windDirection,
    required this.condition,
    required this.description,
    this.uvIndex,
    required this.visibility,
    required this.timestamp,
    required this.locationName,
  });

  factory WeatherData.fromOpenWeatherMap(Map<String, dynamic> data) {
    final main = data['main'] as Map<String, dynamic>;
    final wind = data['wind'] as Map<String, dynamic>?;
    final weather = (data['weather'] as List).isNotEmpty
        ? data['weather'][0] as Map<String, dynamic>
        : <String, dynamic>{};

    WeatherCondition condition;
    final mainCondition = (weather['main'] as String?)?.toLowerCase() ?? '';
    switch (mainCondition) {
      case 'clear':
        condition = WeatherCondition.clear;
        break;
      case 'clouds':
        condition = WeatherCondition.clouds;
        break;
      case 'rain':
        condition = WeatherCondition.rain;
        break;
      case 'drizzle':
        condition = WeatherCondition.drizzle;
        break;
      case 'thunderstorm':
        condition = WeatherCondition.thunderstorm;
        break;
      case 'snow':
        condition = WeatherCondition.snow;
        break;
      case 'mist':
      case 'fog':
      case 'haze':
        condition = WeatherCondition.fog;
        break;
      default:
        condition = WeatherCondition.other;
    }

    return WeatherData(
      temperatureCelsius: (main['temp'] as num?)?.toDouble() ?? 0,
      feelsLikeCelsius: (main['feels_like'] as num?)?.toDouble() ?? 0,
      humidity: (main['humidity'] as num?)?.toInt() ?? 0,
      windSpeedKmh: ((wind?['speed'] as num?)?.toDouble() ?? 0) * 3.6, // m/s to km/h
      windDirection: (wind?['deg'] as num?)?.toInt() ?? 0,
      condition: condition,
      description: weather['description'] as String? ?? '',
      visibility: (data['visibility'] as num?)?.toInt() ?? 10000,
      timestamp: DateTime.now(),
      locationName: data['name'] as String? ?? '',
    );
  }

  String get temperatureString => '${temperatureCelsius.round()}°C';
  String get feelsLikeString => 'Feels like ${feelsLikeCelsius.round()}°C';
  String get humidityString => 'Humidity: $humidity%';
  String get windString => 'Wind: ${windSpeedKmh.round()} km/h ${_windDirectionString()}';

  String _windDirectionString() {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    return directions[((windDirection + 22.5) / 45).floor() % 8];
  }

  /// Get running safety rating (1-5)
  int get safetyRating {
    int rating = 5;

    // Temperature penalties
    if (temperatureCelsius < 0 || temperatureCelsius > 35) rating -= 2;
    else if (temperatureCelsius < 5 || temperatureCelsius > 30) rating -= 1;

    // Weather condition penalties
    if (condition == WeatherCondition.thunderstorm) rating -= 3;
    if (condition == WeatherCondition.snow) rating -= 1;
    if (condition == WeatherCondition.rain) rating -= 1;

    // Wind penalties
    if (windSpeedKmh > 40) rating -= 2;
    else if (windSpeedKmh > 25) rating -= 1;

    return rating.clamp(1, 5);
  }

  String get safetyRatingText {
    switch (safetyRating) {
      case 5:
        return 'Perfect';
      case 4:
        return 'Good';
      case 3:
        return 'Fair';
      case 2:
        return 'Poor';
      default:
        return 'Dangerous';
    }
  }
}
