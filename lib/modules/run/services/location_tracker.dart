import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:majurun/modules/run/constants/run_constants.dart';

/// Handles GPS location tracking for runs.
/// Emits position updates and calculates distance traveled.
///
/// Adaptive sampling: polls at 1 s when speed > 1.5 m/s (walking pace),
/// drops to 4 s when stationary/very slow — saves ~75 % battery in warm-up.
class LocationTracker extends ChangeNotifier {
  Position? _currentPosition;
  final List<LatLng> _routePoints = [];
  double _totalDistance = 0.0;
  bool _isTracking = false;
  bool _isInitialized = false;

  StreamSubscription<Position>? _positionStream;

  // Adaptive sampling
  static const double _fastSpeedMs   = 1.5;  // m/s (~5.4 km/h, brisk walk)
  static const int _fastIntervalSec  = 1;
  static const int _slowIntervalSec  = 4;
  int _currentIntervalSec = _fastIntervalSec;

  // ─────────────────────────────────────────────────────────────────────────
  // Getters
  // ─────────────────────────────────────────────────────────────────────────

  Position? get currentPosition => _currentPosition;

  LatLng? get currentLatLng => _currentPosition == null
      ? null
      : LatLng(_currentPosition!.latitude, _currentPosition!.longitude);

  List<LatLng> get routePoints => List.unmodifiable(_routePoints);

  double get totalDistanceMeters => _totalDistance;

  double get totalDistanceKm => _totalDistance / 1000;

  String get distanceString => totalDistanceKm.toStringAsFixed(2);

  bool get isTracking => _isTracking;

  bool get isInitialized => _isInitialized;

  // ─────────────────────────────────────────────────────────────────────────
  // Location Permission & Service Checks
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> checkAndRequestPermissions() async {
    debugPrint("📍 Checking if location service is enabled...");
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    debugPrint("📍 Location service enabled: $serviceEnabled");

    if (!serviceEnabled) {
      debugPrint("❌ Location services are DISABLED");
      throw Exception("Please enable location services to track your run");
    }

    debugPrint("🔐 Checking location permission...");
    var permission = await Geolocator.checkPermission();
    debugPrint("🔐 Current permission status: $permission");

    if (permission == LocationPermission.denied) {
      debugPrint("🔐 Permission denied — requesting now...");
      permission = await Geolocator.requestPermission();
      debugPrint("🔐 Permission after request: $permission");
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint("❌ Permission DENIED or DENIED FOREVER");
      throw Exception("Location permission is required to track your run");
    }

    debugPrint("✅ All location checks PASSED");
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Tracking Control
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> startTracking() async {
    if (_isTracking) return;

    await checkAndRequestPermissions();

    // Get initial position
    try {
      debugPrint("📍 Getting initial position...");
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: RunConstants.initialPositionTimeoutSeconds),
        ),
      );
      _routePoints.add(LatLng(_currentPosition!.latitude, _currentPosition!.longitude));
      debugPrint("✅ Initial position: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}");
      _isInitialized = true;
    } catch (e) {
      debugPrint("❌ Failed to get initial position: $e");
      throw Exception("Failed to get your location. Please try again.");
    }

    _isTracking = true;
    _startLocationStream();
    notifyListeners();
  }

  void stopTracking() {
    _isTracking = false;
    _positionStream?.cancel();
    _positionStream = null;
    notifyListeners();
  }

  void reset() {
    _totalDistance = 0.0;
    _routePoints.clear();
    _currentPosition = null;
    _isInitialized = false;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Internal
  // ─────────────────────────────────────────────────────────────────────────

  LocationSettings _buildLocationSettings() {
    if (Platform.isIOS) {
      // AppleSettings prevents iOS Core Location from auto-pausing updates
      // when the screen locks or the user appears stationary — critical for run tracking.
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: RunConstants.distanceFilterMeters,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true, // blue status bar — shows user location is active
      );
    }
    return AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: RunConstants.distanceFilterMeters,
      forceLocationManager: false,
      intervalDuration: Duration(seconds: _currentIntervalSec),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'MajuRun',
        notificationText: 'Tracking your run...',
        enableWakeLock: true,
      ),
    );
  }

  void _startLocationStream() {
    debugPrint("📍 Starting location updates");
    _positionStream?.cancel();

    _positionStream = Geolocator.getPositionStream(
      locationSettings: _buildLocationSettings(),
    ).listen(
      _onPositionUpdate,
      onError: (error) {
        debugPrint("❌ Location stream error: $error");
      },
      onDone: () {
        debugPrint("📍 Location stream closed");
      },
    );
  }

  void _onPositionUpdate(Position position) {
    if (!_isTracking) {
      debugPrint("⚠️ Location update received but not tracking");
      return;
    }

    // Calculate distance if we have a previous position
    if (_currentPosition != null && _isInitialized) {
      final distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      // Only add distance if it's reasonable - filters out GPS jumps
      if (distance < RunConstants.gpsJumpThresholdMeters) {
        _totalDistance += distance;
        debugPrint("📍 +${distance.toStringAsFixed(1)}m (Total: ${_totalDistance.toStringAsFixed(1)}m)");
      } else {
        debugPrint("⚠️ GPS jump detected: ${distance.toStringAsFixed(1)}m - ignoring");
      }
    }

    _currentPosition = position;
    _routePoints.add(LatLng(position.latitude, position.longitude));

    // Adaptive sampling: switch interval if speed tier changed (Android only)
    if (Platform.isAndroid) {
      final speedMs = position.speed.clamp(0.0, double.infinity);
      final neededInterval = speedMs >= _fastSpeedMs ? _fastIntervalSec : _slowIntervalSec;
      if (neededInterval != _currentIntervalSec) {
        _currentIntervalSec = neededInterval;
        debugPrint('📍 Adaptive GPS: switching to ${_currentIntervalSec}s interval (speed: ${speedMs.toStringAsFixed(1)} m/s)');
        _startLocationStream(); // restarts with new interval
      }
    }

    notifyListeners();
  }

  @override
  void dispose() {
    debugPrint("🗑️ Disposing LocationTracker");
    _positionStream?.cancel();
    super.dispose();
  }
}
