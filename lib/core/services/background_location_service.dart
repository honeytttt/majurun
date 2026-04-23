import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:majurun/modules/run/constants/run_constants.dart';

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
    if (accuracy <= RunConstants.gpsExcellentThreshold) return GpsQuality.excellent;
    if (accuracy <= RunConstants.gpsGoodThreshold) return GpsQuality.good;
    if (accuracy <= RunConstants.gpsFairThreshold) return GpsQuality.fair;
    if (accuracy <= RunConstants.gpsPoorThreshold) return GpsQuality.poor;
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

  // State
  StreamSubscription<Position>? _positionStream;
  final _positionController = StreamController<FilteredPosition>.broadcast();
  final KalmanFilter _kalmanFilter = KalmanFilter();

  FilteredPosition? _lastPosition;
  Position? _lastRawPosition; // Track raw position for accurate distance calculation
  double _totalDistance = 0;
  int _stationarySeconds = 0;
  bool _isTracking = false;
  bool _isPaused = false;
  bool _autoPaused = false;
  bool _isAutoPauseEnabled = true;

  // Route data with memory management
  final List<FilteredPosition> _routePoints = [];
  int _discardedReadings = 0;
  int _totalReadings = 0;

  // GPS watchdog — detects when iOS/Android silently stops delivering updates
  Timer? _watchdogTimer;
  DateTime? _lastUpdateTime;
  static const int _watchdogSilenceSeconds = 30; // alert after 30s with no GPS

  // Callbacks
  void Function(FilteredPosition position, double totalDistance)? onPositionUpdate;
  void Function(bool isAutoPaused)? onAutoPauseChanged;
  void Function(String error)? onError;
  void Function(GpsQuality quality)? onGpsQualityChanged;
  void Function()? onGpsSilent; // fired when GPS stops updating for 30s

  // Getters
  Stream<FilteredPosition> get positionStream => _positionController.stream;
  bool get isTracking => _isTracking;
  bool get isPaused => _isPaused;
  bool get isAutoPaused => _autoPaused;
  bool get isAutoPauseEnabled => _isAutoPauseEnabled;
  set isAutoPauseEnabled(bool value) => _isAutoPauseEnabled = value;

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
    _lastRawPosition = null;
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

      _lastRawPosition = initialPosition;
      debugPrint('✅ Initial position: ${initialPosition.latitude}, ${initialPosition.longitude} (accuracy: ${initialPosition.accuracy}m)');
    } catch (e) {
      onError?.call('Failed to get initial GPS position. Please ensure GPS is enabled.');
      return false;
    }

    // Start position stream with optimized settings
    _startPositionStream();
    _startWatchdog();
    _isTracking = true;

    debugPrint('🏃 Background location tracking started');
    return true;
  }

  void _startPositionStream() {
    _positionStream?.cancel();

    late LocationSettings locationSettings;

    if (!kIsWeb && Platform.isAndroid) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: RunConstants.distanceFilterMeters,
        intervalDuration: const Duration(milliseconds: RunConstants.androidGpsIntervalMs),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'MajuRun - Tracking Your Run',
          notificationText: 'GPS tracking active in background',
          notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
          enableWakeLock: true,
        ),
      );
    } else if (!kIsWeb && Platform.isIOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: RunConstants.distanceFilterMeters,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      );
    }

    try {
      _positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        _handlePositionUpdate,
        onError: _handleStreamError,
        onDone: () => debugPrint('📍 Position stream closed'),
      );
    } catch (e) {
      debugPrint('⚠️ Foreground service blocked, falling back to basic stream: $e');
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 3,
        ),
      ).listen(
        _handlePositionUpdate,
        onError: _handleStreamError,
      );
    }
  }

  void _handlePositionUpdate(Position position) {
    if (!_isTracking) return;

    _lastUpdateTime = DateTime.now();
    _totalReadings++;

    final quality = FilteredPosition._calculateQuality(position.accuracy, position.speed);
    onGpsQualityChanged?.call(quality);

    if (position.accuracy > RunConstants.maxAccuracyMeters) {
      _discardedReadings++;
      debugPrint('⚠️ Discarding poor GPS reading (accuracy: ${position.accuracy.toStringAsFixed(1)}m)');
      return;
    }

    if (_lastPosition != null) {
      final distFromFiltered = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      if (distFromFiltered > 30) {
        _kalmanFilter.reset();
      }
    }
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

    if (_isPaused) {
      _lastPosition = filteredPosition;
      return;
    }

    if (_lastRawPosition != null) {
      final rawDistance = Geolocator.distanceBetween(
        _lastRawPosition!.latitude,
        _lastRawPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      if (rawDistance > RunConstants.gpsJumpThresholdMeters) {
        _discardedReadings++;
        _lastRawPosition = position;
        _kalmanFilter.reset();
        debugPrint('⚠️ GPS jump detected: ${rawDistance.toStringAsFixed(1)}m — resetting reference');
        return;
      }

      // Check for stationary state (auto-pause) using raw distance
      if (_isAutoPauseEnabled) {
        if (position.speed < RunConstants.stationarySpeedThreshold && rawDistance < 2) {
          _stationarySeconds++;
          if (_stationarySeconds >= RunConstants.autoPauseDelaySeconds && !_autoPaused) {
            _autoPaused = true;
            onAutoPauseChanged?.call(true);
            debugPrint('⏸️ Auto-paused: stationary for $_stationarySeconds seconds');
          }
        } else {
          if (_autoPaused && _stationarySeconds >= RunConstants.autoResumeDelaySeconds) {
            _autoPaused = false;
            onAutoPauseChanged?.call(false);
            debugPrint('▶️ Auto-resumed: movement detected');
          }
          if (!_autoPaused) {
            _stationarySeconds = 0;
          }
        }
      } else {
        _autoPaused = false;
        _stationarySeconds = 0;
      }

      if (!_autoPaused) {
        _totalDistance += rawDistance;
      }
    }

    _lastRawPosition = position;

    if (_lastPosition != null) {
      final distFromLast = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        filteredPosition.latitude,
        filteredPosition.longitude,
      );
      if (distFromLast < 3.0) {
        _lastPosition = filteredPosition;
        _positionController.add(filteredPosition);
        onPositionUpdate?.call(filteredPosition, _totalDistance);
        return;
      }
    }

    if (_routePoints.length >= RunConstants.maxRoutePointsInMemory) {
      _compressRoutePoints();
    }

    _routePoints.add(filteredPosition);
    _lastPosition = filteredPosition;

    _positionController.add(filteredPosition);
    onPositionUpdate?.call(filteredPosition, _totalDistance);

    assert(() {
      debugPrint('📍 Pos: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)} | '
          'Acc: ${position.accuracy.toStringAsFixed(1)}m | '
          'Spd: ${(position.speed * 3.6).toStringAsFixed(1)}km/h | '
          'Dist: ${(_totalDistance/1000).toStringAsFixed(3)}km');
      return true;
    }());
  }

  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _lastUpdateTime = DateTime.now();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!_isTracking || _isPaused) return;
      final last = _lastUpdateTime;
      if (last == null) return;
      final silentSeconds = DateTime.now().difference(last).inSeconds;
      if (silentSeconds >= _watchdogSilenceSeconds) {
        debugPrint('⚠️ GPS watchdog: no update for ${silentSeconds}s — attempting stream restart');
        onGpsSilent?.call();
        _startPositionStream();
        _lastUpdateTime = DateTime.now();
      }
    });
  }

  void _handleStreamError(dynamic error) {
    debugPrint('❌ GPS Stream error: $error');
    onError?.call('GPS signal lost. Move to an open area.');

    Future.delayed(const Duration(seconds: 3), () {
      if (_isTracking && !_isPaused) {
        debugPrint('🔄 Attempting to restart GPS stream...');
        _startPositionStream();
      }
    });
  }

  void _compressRoutePoints() {
    debugPrint('🗜️ Compressing route points from ${_routePoints.length}...');
    final compressed = <FilteredPosition>[];
    for (int i = 0; i < _routePoints.length; i++) {
      if (i % RunConstants.routeCompressionRatio == 0 || i == _routePoints.length - 1) {
        compressed.add(_routePoints[i]);
      }
    }
    _routePoints.clear();
    _routePoints.addAll(compressed);
    debugPrint('🗜️ Compressed to ${_routePoints.length} points');
  }

  void pause() {
    if (!_isTracking || _isPaused) return;
    _isPaused = true;
    debugPrint('⏸️ Location tracking paused');
  }

  void resume() {
    if (!_isTracking || !_isPaused) return;
    _isPaused = false;
    _autoPaused = false;
    _stationarySeconds = 0;
    debugPrint('▶️ Location tracking resumed');
  }

  Future<void> stopTracking() async {
    if (!_isTracking) return;

    _isTracking = false;
    _isPaused = false;
    _autoPaused = false;

    _watchdogTimer?.cancel();
    _watchdogTimer = null;

    await _positionStream?.cancel();
    _positionStream = null;

    debugPrint('⏹️ Location tracking stopped');
  }

  void dispose() {
    stopTracking();
    _positionController.close();
  }

  List<LatLng> getRouteLatLngs() {
    return _routePoints.map((p) => p.latLng).toList();
  }

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

      final elevDiff = curr.altitude - prev.altitude;
      if (elevDiff > 0) {
        elevationGain += elevDiff;
      } else {
        elevationLoss += elevDiff.abs();
      }

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

