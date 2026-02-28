import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// GPS accuracy levels for filtering
enum GpsQuality { excellent, good, fair, poor, unusable }

/// Represents a filtered, high-quality GPS point
class FilteredPosition {
  final double latitude;
  final double longitude;
  final double altitude;
  final double accuracy;
  final double speed;
  final double heading;
  final DateTime timestamp;
  final GpsQuality quality;

  FilteredPosition({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.accuracy,
    required this.speed,
    required this.heading,
    required this.timestamp,
    required this.quality,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  factory FilteredPosition.fromPosition(Position pos) {
    return FilteredPosition(
      latitude: pos.latitude,
      longitude: pos.longitude,
      altitude: pos.altitude,
      accuracy: pos.accuracy,
      speed: pos.speed,
      heading: pos.heading,
      timestamp: pos.timestamp,
      quality: _calculateQuality(pos.accuracy, pos.speed),
    );
  }

  static GpsQuality _calculateQuality(double accuracy, double speed) {
    // Running GPS accuracy thresholds
    if (accuracy <= 5) return GpsQuality.excellent;
    if (accuracy <= 10) return GpsQuality.good;
    if (accuracy <= 20) return GpsQuality.fair;
    if (accuracy <= 50) return GpsQuality.poor;
    return GpsQuality.unusable;
  }
}

/// Kalman filter for GPS smoothing
class KalmanFilter {
  double _lat = 0;
  double _lng = 0;
  double _variance = -1; // Negative means uninitialized

  static const double _minAccuracy = 1.0;

  /// Process a new GPS reading and return the filtered position
  (double lat, double lng) process(double lat, double lng, double accuracy) {
    if (accuracy < _minAccuracy) accuracy = _minAccuracy;

    if (_variance < 0) {
      // First reading - initialize
      _lat = lat;
      _lng = lng;
      _variance = accuracy * accuracy;
    } else {
      // Kalman filter update
      final kalmanGain = _variance / (_variance + accuracy * accuracy);
      _lat = _lat + kalmanGain * (lat - _lat);
      _lng = _lng + kalmanGain * (lng - _lng);
      _variance = (1 - kalmanGain) * _variance;
    }

    return (_lat, _lng);
  }

  void reset() {
    _variance = -1;
  }
}

/// Production-grade background location service for run tracking
class BackgroundLocationService {
  static final BackgroundLocationService _instance = BackgroundLocationService._internal();
  factory BackgroundLocationService() => _instance;
  BackgroundLocationService._internal();

  // Configuration
  static const double _minAccuracyMeters = 25.0; // Discard readings worse than this
  static const double _gpsJumpThreshold = 50.0; // Max reasonable distance per update
  static const double _stationaryThreshold = 1.5; // m/s - below this is "stationary"
  static const int _stationaryTimeThreshold = 10; // seconds of no movement before auto-pause
  static const int _maxRoutePointsInMemory = 5000; // Prevent memory issues on long runs

  // State
  StreamSubscription<Position>? _positionStream;
  final _positionController = StreamController<FilteredPosition>.broadcast();
  final KalmanFilter _kalmanFilter = KalmanFilter();

  FilteredPosition? _lastPosition;
  double _totalDistance = 0;
  int _stationarySeconds = 0;
  bool _isTracking = false;
  bool _isPaused = false;
  bool _autoPaused = false;

  // Route data with memory management
  final List<FilteredPosition> _routePoints = [];
  int _discardedReadings = 0;
  int _totalReadings = 0;

  // Callbacks
  void Function(FilteredPosition position, double totalDistance)? onPositionUpdate;
  void Function(bool isAutoPaused)? onAutoPauseChanged;
  void Function(String error)? onError;
  void Function(GpsQuality quality)? onGpsQualityChanged;

  // Getters
  Stream<FilteredPosition> get positionStream => _positionController.stream;
  bool get isTracking => _isTracking;
  bool get isPaused => _isPaused;
  bool get isAutoPaused => _autoPaused;
  double get totalDistance => _totalDistance;
  List<FilteredPosition> get routePoints => List.unmodifiable(_routePoints);
  FilteredPosition? get lastPosition => _lastPosition;
  int get discardedReadings => _discardedReadings;
  int get totalReadings => _totalReadings;
  double get gpsAcceptanceRate => _totalReadings > 0
      ? ((_totalReadings - _discardedReadings) / _totalReadings * 100)
      : 100;

  /// Check and request location permissions
  Future<bool> checkPermissions() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        onError?.call('Location services are disabled. Please enable GPS.');
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        onError?.call('Location permission denied. Cannot track run.');
        return false;
      }

      if (permission == LocationPermission.deniedForever) {
        onError?.call('Location permission permanently denied. Please enable in settings.');
        return false;
      }

      // Request background location permission on Android
      if (!kIsWeb && Platform.isAndroid) {
        if (permission == LocationPermission.whileInUse) {
          // For Android 10+, we need to request background permission separately
          debugPrint('📍 Requesting background location permission...');
          permission = await Geolocator.requestPermission();
        }
      }

      return true;
    } catch (e) {
      onError?.call('Error checking permissions: $e');
      return false;
    }
  }

  /// Start tracking with background location support
  Future<bool> startTracking() async {
    if (_isTracking) {
      debugPrint('⚠️ Already tracking');
      return true;
    }

    final hasPermission = await checkPermissions();
    if (!hasPermission) return false;

    // Reset state
    _totalDistance = 0;
    _stationarySeconds = 0;
    _routePoints.clear();
    _lastPosition = null;
    _kalmanFilter.reset();
    _discardedReadings = 0;
    _totalReadings = 0;
    _isPaused = false;
    _autoPaused = false;

    // Get initial position with high accuracy
    try {
      debugPrint('📍 Getting initial GPS fix...');
      final initialPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 15),
        ),
      );

      _lastPosition = FilteredPosition.fromPosition(initialPosition);
      _routePoints.add(_lastPosition!);
      onGpsQualityChanged?.call(_lastPosition!.quality);

      debugPrint('✅ Initial position: ${initialPosition.latitude}, ${initialPosition.longitude} (accuracy: ${initialPosition.accuracy}m)');
    } catch (e) {
      onError?.call('Failed to get initial GPS position. Please ensure GPS is enabled.');
      return false;
    }

    // Start position stream with optimized settings
    _startPositionStream();
    _isTracking = true;

    debugPrint('🏃 Background location tracking started');
    return true;
  }

  void _startPositionStream() {
    _positionStream?.cancel();

    // Use platform-specific optimal settings
    late LocationSettings locationSettings;

    if (!kIsWeb && Platform.isAndroid) {
      // Android: Use foreground service for background tracking
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3, // More frequent updates for accuracy
        intervalDuration: const Duration(seconds: 1),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'MajuRun - Tracking Your Run',
          notificationText: 'GPS tracking active in background',
          notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
          enableWakeLock: true,
        ),
      );
    } else if (!kIsWeb && Platform.isIOS) {
      // iOS: Use Apple's location settings
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    } else {
      // Web/other: Basic settings
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      );
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _handlePositionUpdate,
      onError: _handleStreamError,
      onDone: () => debugPrint('📍 Position stream closed'),
    );
  }

  void _handlePositionUpdate(Position position) {
    if (!_isTracking) return;

    _totalReadings++;

    // Check GPS quality first
    final quality = FilteredPosition._calculateQuality(position.accuracy, position.speed);
    onGpsQualityChanged?.call(quality);

    // Discard unusable readings
    if (position.accuracy > _minAccuracyMeters) {
      _discardedReadings++;
      debugPrint('⚠️ Discarding poor GPS reading (accuracy: ${position.accuracy.toStringAsFixed(1)}m)');
      return;
    }

    // Apply Kalman filter for smoothing
    final (filteredLat, filteredLng) = _kalmanFilter.process(
      position.latitude,
      position.longitude,
      position.accuracy,
    );

    final filteredPosition = FilteredPosition(
      latitude: filteredLat,
      longitude: filteredLng,
      altitude: position.altitude,
      accuracy: position.accuracy,
      speed: position.speed,
      heading: position.heading,
      timestamp: position.timestamp,
      quality: quality,
    );

    // Skip if paused (but still track position for when we resume)
    if (_isPaused) {
      _lastPosition = filteredPosition;
      return;
    }

    // Calculate distance from last position
    if (_lastPosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        filteredPosition.latitude,
        filteredPosition.longitude,
      );

      // Check for GPS jump
      if (distance > _gpsJumpThreshold) {
        _discardedReadings++;
        debugPrint('⚠️ GPS jump detected: ${distance.toStringAsFixed(1)}m - discarding');
        return;
      }

      // Check for stationary state (auto-pause)
      if (position.speed < _stationaryThreshold && distance < 2) {
        _stationarySeconds++;
        if (_stationarySeconds >= _stationaryTimeThreshold && !_autoPaused) {
          _autoPaused = true;
          onAutoPauseChanged?.call(true);
          debugPrint('⏸️ Auto-paused: stationary for $_stationarySeconds seconds');
        }
      } else {
        if (_autoPaused) {
          _autoPaused = false;
          onAutoPauseChanged?.call(false);
          debugPrint('▶️ Auto-resumed: movement detected');
        }
        _stationarySeconds = 0;
      }

      // Only add distance if not auto-paused
      if (!_autoPaused) {
        _totalDistance += distance;
      }
    }

    // Memory management: compress old route points if getting too large
    if (_routePoints.length >= _maxRoutePointsInMemory) {
      _compressRoutePoints();
    }

    _routePoints.add(filteredPosition);
    _lastPosition = filteredPosition;

    // Emit update
    _positionController.add(filteredPosition);
    onPositionUpdate?.call(filteredPosition, _totalDistance);

    debugPrint('📍 Position: ${filteredLat.toStringAsFixed(6)}, ${filteredLng.toStringAsFixed(6)} | '
        'Accuracy: ${position.accuracy.toStringAsFixed(1)}m | '
        'Speed: ${position.speed.toStringAsFixed(1)}m/s | '
        'Total: ${(_totalDistance/1000).toStringAsFixed(2)}km');
  }

  void _handleStreamError(dynamic error) {
    debugPrint('❌ GPS Stream error: $error');
    onError?.call('GPS signal lost. Move to an open area.');

    // Try to restart the stream after a delay
    Future.delayed(const Duration(seconds: 3), () {
      if (_isTracking && !_isPaused) {
        debugPrint('🔄 Attempting to restart GPS stream...');
        _startPositionStream();
      }
    });
  }

  /// Compress route points to save memory (keep every 3rd point)
  void _compressRoutePoints() {
    debugPrint('🗜️ Compressing route points from ${_routePoints.length}...');
    final compressed = <FilteredPosition>[];
    for (int i = 0; i < _routePoints.length; i++) {
      if (i % 3 == 0 || i == _routePoints.length - 1) {
        compressed.add(_routePoints[i]);
      }
    }
    _routePoints.clear();
    _routePoints.addAll(compressed);
    debugPrint('🗜️ Compressed to ${_routePoints.length} points');
  }

  /// Pause tracking (manual pause)
  void pause() {
    if (!_isTracking || _isPaused) return;
    _isPaused = true;
    debugPrint('⏸️ Location tracking paused');
  }

  /// Resume tracking
  void resume() {
    if (!_isTracking || !_isPaused) return;
    _isPaused = false;
    _autoPaused = false;
    _stationarySeconds = 0;
    debugPrint('▶️ Location tracking resumed');
  }

  /// Stop tracking completely
  Future<void> stopTracking() async {
    if (!_isTracking) return;

    _isTracking = false;
    _isPaused = false;
    _autoPaused = false;

    await _positionStream?.cancel();
    _positionStream = null;

    debugPrint('⏹️ Location tracking stopped');
    debugPrint('📊 GPS Stats: $_totalReadings readings, $_discardedReadings discarded (${gpsAcceptanceRate.toStringAsFixed(1)}% acceptance rate)');
  }

  /// Clean up resources
  void dispose() {
    stopTracking();
    _positionController.close();
  }

  /// Get route as LatLng list for map display
  List<LatLng> getRouteLatLngs() {
    return _routePoints.map((p) => p.latLng).toList();
  }

  /// Calculate route statistics
  Map<String, dynamic> getRouteStats() {
    if (_routePoints.isEmpty) {
      return {
        'totalDistance': 0.0,
        'elevationGain': 0.0,
        'elevationLoss': 0.0,
        'maxSpeed': 0.0,
        'avgAccuracy': 0.0,
        'pointCount': 0,
      };
    }

    double elevationGain = 0;
    double elevationLoss = 0;
    double maxSpeed = 0;
    double totalAccuracy = 0;

    for (int i = 1; i < _routePoints.length; i++) {
      final prev = _routePoints[i - 1];
      final curr = _routePoints[i];

      // Elevation changes
      final elevDiff = curr.altitude - prev.altitude;
      if (elevDiff > 0) {
        elevationGain += elevDiff;
      } else {
        elevationLoss += elevDiff.abs();
      }

      // Max speed
      if (curr.speed > maxSpeed) {
        maxSpeed = curr.speed;
      }

      totalAccuracy += curr.accuracy;
    }

    return {
      'totalDistance': _totalDistance,
      'elevationGain': elevationGain,
      'elevationLoss': elevationLoss,
      'maxSpeed': maxSpeed,
      'avgAccuracy': totalAccuracy / _routePoints.length,
      'pointCount': _routePoints.length,
    };
  }
}
