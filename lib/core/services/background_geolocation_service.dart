import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';

/// Background Geolocation Service - Accurate GPS tracking when app is backgrounded
/// Critical for accurate run tracking when phone is in pocket/locked
class BackgroundGeolocationService extends ChangeNotifier {
  static final BackgroundGeolocationService _instance = BackgroundGeolocationService._internal();
  factory BackgroundGeolocationService() => _instance;
  BackgroundGeolocationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isInitialized = false;
  bool _isTracking = false;
  String? _currentRunId;

  String? get currentRunId => _currentRunId;

  // Location data
  final List<LocationPoint> _locationPoints = [];
  bg.Location? _lastLocation;
  double _totalDistanceMeters = 0;
  double _currentSpeed = 0; // m/s
  double _avgSpeed = 0; // m/s
  double _maxSpeed = 0; // m/s
  double _elevationGain = 0;
  double _currentAltitude = 0;

  // Callbacks
  Function(LocationPoint)? onLocationUpdate;
  Function(double totalDistance)? onDistanceUpdate;
  Function(MotionActivityType)? onActivityChange;

  // Getters
  bool get isTracking => _isTracking;
  List<LocationPoint> get locationPoints => List.unmodifiable(_locationPoints);
  double get totalDistanceMeters => _totalDistanceMeters;
  double get currentSpeedMps => _currentSpeed;
  double get avgSpeedMps => _avgSpeed;
  double get maxSpeedMps => _maxSpeed;
  double get elevationGain => _elevationGain;
  double get currentAltitude => _currentAltitude;
  bg.Location? get lastLocation => _lastLocation;

  /// Initialize the background geolocation service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Configure the plugin
      await bg.BackgroundGeolocation.ready(bg.Config(
        // Debug
        debug: kDebugMode,
        logLevel: kDebugMode ? bg.Config.LOG_LEVEL_VERBOSE : bg.Config.LOG_LEVEL_OFF,

        // Geolocation
        desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
        distanceFilter: 5.0, // meters - record every 5m
        stopOnTerminate: false,
        startOnBoot: false,
        enableHeadless: true,

        // Activity Recognition
        stopTimeout: 5, // minutes before stopping when stationary
        motionTriggerDelay: 0,
        isMoving: true,

        // Battery optimization
        preventSuspend: true,
        heartbeatInterval: 60, // seconds

        // iOS specific
        activityType: bg.Config.ACTIVITY_TYPE_FITNESS,
        pausesLocationUpdatesAutomatically: false,
        showsBackgroundLocationIndicator: true,

        // Android specific
        notification: bg.Notification(
          title: "MajuRun",
          text: "Tracking your run...",
          channelName: "Run Tracking",
          priority: bg.NotificationPriority.high,
          sticky: true,
        ),
        foregroundService: true,
      ));

      // Listen for location updates
      bg.BackgroundGeolocation.onLocation(_onLocation);

      // Listen for motion changes
      bg.BackgroundGeolocation.onMotionChange(_onMotionChange);

      // Listen for activity changes
      bg.BackgroundGeolocation.onActivityChange(_onActivityChange);

      // Listen for provider changes
      bg.BackgroundGeolocation.onProviderChange(_onProviderChange);

      // Listen for heartbeat
      bg.BackgroundGeolocation.onHeartbeat(_onHeartbeat);

      _isInitialized = true;
      debugPrint('Background geolocation service initialized');
    } catch (e) {
      debugPrint('Error initializing background geolocation: $e');
    }
  }

  /// Start tracking a run
  Future<bool> startTracking({String? runId}) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      _currentRunId = runId;
      _locationPoints.clear();
      _totalDistanceMeters = 0;
      _currentSpeed = 0;
      _avgSpeed = 0;
      _maxSpeed = 0;
      _elevationGain = 0;
      _lastLocation = null;

      // Update notification
      await bg.BackgroundGeolocation.setConfig(bg.Config(
        notification: bg.Notification(
          title: "MajuRun - Running",
          text: "0.00 km | 00:00",
          channelName: "Run Tracking",
          priority: bg.NotificationPriority.high,
          sticky: true,
        ),
      ));

      // Start tracking
      final state = await bg.BackgroundGeolocation.start();
      _isTracking = state.enabled;

      debugPrint('Background tracking started: $_isTracking');
      notifyListeners();
      return _isTracking;
    } catch (e) {
      debugPrint('Error starting background tracking: $e');
      return false;
    }
  }

  /// Stop tracking
  Future<void> stopTracking() async {
    try {
      await bg.BackgroundGeolocation.stop();
      _isTracking = false;
      _currentRunId = null;

      debugPrint('Background tracking stopped');
      notifyListeners();
    } catch (e) {
      debugPrint('Error stopping background tracking: $e');
    }
  }

  /// Pause tracking (keeps service running but doesn't record)
  Future<void> pauseTracking() async {
    try {
      await bg.BackgroundGeolocation.changePace(false);

      await bg.BackgroundGeolocation.setConfig(bg.Config(
        notification: bg.Notification(
          title: "MajuRun - Paused",
          text: "${(_totalDistanceMeters / 1000).toStringAsFixed(2)} km | Paused",
          channelName: "Run Tracking",
          priority: bg.NotificationPriority.high,
          sticky: true,
        ),
      ));

      debugPrint('Background tracking paused');
    } catch (e) {
      debugPrint('Error pausing background tracking: $e');
    }
  }

  /// Resume tracking
  Future<void> resumeTracking() async {
    try {
      await bg.BackgroundGeolocation.changePace(true);

      await bg.BackgroundGeolocation.setConfig(bg.Config(
        notification: bg.Notification(
          title: "MajuRun - Running",
          text: "${(_totalDistanceMeters / 1000).toStringAsFixed(2)} km",
          channelName: "Run Tracking",
          priority: bg.NotificationPriority.high,
          sticky: true,
        ),
      ));

      debugPrint('Background tracking resumed');
    } catch (e) {
      debugPrint('Error resuming background tracking: $e');
    }
  }

  /// Handle location update
  void _onLocation(bg.Location location) {
    debugPrint('Location: ${location.coords.latitude}, ${location.coords.longitude}');

    // Filter out low accuracy points
    if (location.coords.accuracy > 30) {
      debugPrint('Skipping low accuracy point: ${location.coords.accuracy}m');
      return;
    }

    final point = LocationPoint(
      latitude: location.coords.latitude,
      longitude: location.coords.longitude,
      altitude: location.coords.altitude,
      accuracy: location.coords.accuracy,
      speed: location.coords.speed,
      heading: location.coords.heading,
      timestamp: DateTime.parse(location.timestamp),
    );

    // Calculate distance from last point
    if (_lastLocation != null) {
      final distance = _calculateDistance(
        _lastLocation!.coords.latitude,
        _lastLocation!.coords.longitude,
        location.coords.latitude,
        location.coords.longitude,
      );

      // Filter out GPS jumps (>100m in one reading is suspicious)
      if (distance > 100) {
        debugPrint('Filtering GPS jump: ${distance}m');
        return;
      }

      _totalDistanceMeters += distance;

      // Calculate elevation gain
      final altitudeDiff = location.coords.altitude - _lastLocation!.coords.altitude;
      if (altitudeDiff > 0) {
        _elevationGain += altitudeDiff;
      }
    }

    // Update speed
    _currentSpeed = location.coords.speed;
    if (_currentSpeed > _maxSpeed) {
      _maxSpeed = _currentSpeed;
    }

    // Calculate average speed
    if (_locationPoints.isNotEmpty) {
      final totalSpeed = _locationPoints.fold<double>(0, (acc, p) => acc + p.speed) + _currentSpeed;
      _avgSpeed = totalSpeed / (_locationPoints.length + 1);
    }

    _currentAltitude = location.coords.altitude;
    _lastLocation = location;
    _locationPoints.add(point);

    // Update notification
    _updateNotification();

    // Trigger callbacks
    onLocationUpdate?.call(point);
    onDistanceUpdate?.call(_totalDistanceMeters);

    notifyListeners();
  }

  /// Update the foreground notification
  Future<void> _updateNotification() async {
    final distanceKm = _totalDistanceMeters / 1000;

    await bg.BackgroundGeolocation.setConfig(bg.Config(
      notification: bg.Notification(
        title: "MajuRun - Running",
        text: "${distanceKm.toStringAsFixed(2)} km",
        channelName: "Run Tracking",
        priority: bg.NotificationPriority.high,
        sticky: true,
      ),
    ));
  }

  /// Handle motion change
  void _onMotionChange(bg.Location location) {
    debugPrint('Motion change: isMoving=${location.isMoving}');
  }

  /// Handle activity change
  void _onActivityChange(bg.ActivityChangeEvent event) {
    debugPrint('Activity change: ${event.activity}');

    MotionActivityType activityType;
    switch (event.activity) {
      case 'running':
        activityType = MotionActivityType.running;
        break;
      case 'walking':
        activityType = MotionActivityType.walking;
        break;
      case 'on_bicycle':
        activityType = MotionActivityType.cycling;
        break;
      case 'still':
        activityType = MotionActivityType.stationary;
        break;
      default:
        activityType = MotionActivityType.unknown;
    }

    onActivityChange?.call(activityType);
  }

  /// Handle provider change
  void _onProviderChange(bg.ProviderChangeEvent event) {
    debugPrint('Provider change: enabled=${event.enabled}, gps=${event.gps}');
  }

  /// Handle heartbeat
  void _onHeartbeat(bg.HeartbeatEvent event) {
    debugPrint('Heartbeat: ${event.location?.coords.latitude}');
  }

  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const distance = Distance();
    return distance.as(
      LengthUnit.Meter,
      LatLng(lat1, lon1),
      LatLng(lat2, lon2),
    );
  }

  /// Get current location
  Future<bg.Location?> getCurrentLocation() async {
    try {
      final location = await bg.BackgroundGeolocation.getCurrentPosition(
        samples: 3,
        timeout: 30,
        maximumAge: 5000,
        desiredAccuracy: 10,
      );
      return location;
    } catch (e) {
      debugPrint('Error getting current location: $e');
      return null;
    }
  }

  /// Save run data to Firestore
  Future<void> saveRunToFirestore({
    required String runId,
    required int durationSeconds,
    String? title,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final routePoints = _locationPoints.map((p) => {
        'lat': p.latitude,
        'lng': p.longitude,
        'alt': p.altitude,
        'speed': p.speed,
        'timestamp': p.timestamp.toIso8601String(),
      }).toList();

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('runHistory')
          .doc(runId)
          .update({
        'routePoints': routePoints,
        'distanceMeters': _totalDistanceMeters,
        'elevationGain': _elevationGain,
        'maxSpeed': _maxSpeed,
        'avgSpeed': _avgSpeed,
        'pointCount': _locationPoints.length,
      });

      debugPrint('Run data saved to Firestore: $runId');
    } catch (e) {
      debugPrint('Error saving run data: $e');
    }
  }

  /// Export route as GPX
  String exportAsGPX({String? name}) {
    final gpx = StringBuffer();
    gpx.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    gpx.writeln('<gpx version="1.1" creator="MajuRun">');
    gpx.writeln('  <trk>');
    gpx.writeln('    <name>${name ?? "MajuRun Activity"}</name>');
    gpx.writeln('    <trkseg>');

    for (final point in _locationPoints) {
      gpx.writeln('      <trkpt lat="${point.latitude}" lon="${point.longitude}">');
      gpx.writeln('        <ele>${point.altitude}</ele>');
      gpx.writeln('        <time>${point.timestamp.toIso8601String()}</time>');
      gpx.writeln('      </trkpt>');
    }

    gpx.writeln('    </trkseg>');
    gpx.writeln('  </trk>');
    gpx.writeln('</gpx>');

    return gpx.toString();
  }

  /// Get route bounds for map display
  Map<String, double>? getRouteBounds() {
    if (_locationPoints.isEmpty) return null;

    double minLat = _locationPoints.first.latitude;
    double maxLat = _locationPoints.first.latitude;
    double minLng = _locationPoints.first.longitude;
    double maxLng = _locationPoints.first.longitude;

    for (final point in _locationPoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return {
      'minLat': minLat,
      'maxLat': maxLat,
      'minLng': minLng,
      'maxLng': maxLng,
    };
  }

  /// Clear tracking data
  void clearData() {
    _locationPoints.clear();
    _totalDistanceMeters = 0;
    _currentSpeed = 0;
    _avgSpeed = 0;
    _maxSpeed = 0;
    _elevationGain = 0;
    _lastLocation = null;
    notifyListeners();
  }

  /// Dispose service
  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}

/// Location point data
class LocationPoint {
  final double latitude;
  final double longitude;
  final double altitude;
  final double accuracy;
  final double speed;
  final double heading;
  final DateTime timestamp;

  const LocationPoint({
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.accuracy,
    required this.speed,
    required this.heading,
    required this.timestamp,
  });
}

/// Motion activity types
enum MotionActivityType {
  running,
  walking,
  cycling,
  stationary,
  unknown,
}
