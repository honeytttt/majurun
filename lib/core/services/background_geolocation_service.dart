import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Background Geolocation Service - STUB VERSION
/// The Transistorsoft plugin requires a paid license for release builds.
/// Run tracking uses geolocator with foreground service instead.
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
  double _totalDistanceMeters = 0;
  double _currentSpeed = 0;
  double _avgSpeed = 0;
  double _maxSpeed = 0;
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

  /// Initialize - stub, does nothing
  Future<void> initialize() async {
    if (_isInitialized) return;
    debugPrint('BackgroundGeolocation: Using geolocator foreground service instead (stub)');
    _isInitialized = true;
  }

  /// Start tracking - stub
  Future<bool> startTracking({String? runId}) async {
    debugPrint('BackgroundGeolocation: startTracking stub called');
    return false;
  }

  /// Stop tracking - stub
  Future<void> stopTracking() async {
    _isTracking = false;
    _currentRunId = null;
  }

  /// Pause tracking - stub
  Future<void> pauseTracking() async {}

  /// Resume tracking - stub
  Future<void> resumeTracking() async {}

  /// Get current location - stub
  Future<dynamic> getCurrentLocation() async {
    return null;
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
    notifyListeners();
  }

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
