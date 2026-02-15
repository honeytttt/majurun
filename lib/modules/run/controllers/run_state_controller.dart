import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum RunState { idle, running, paused }

class ChartDataSpot {
  final double x;
  final double y;
  const ChartDataSpot(this.x, this.y);
}

class KmSplit {
  final int kmNumber;
  final int durationSeconds;
  final String pace;
  
  KmSplit({
    required this.kmNumber,
    required this.durationSeconds,
    required this.pace,
  });
}

class RunStateController extends ChangeNotifier {
  RunState _state = RunState.idle;
  RunState get state => _state;

  Position? _currentPosition;
  LatLng? get currentLatLng => _currentPosition == null
      ? null
      : LatLng(_currentPosition!.latitude, _currentPosition!.longitude);

  double _totalDistance = 0.0;
  String get distanceString => (_totalDistance / 1000).toStringAsFixed(2);

  int _secondsElapsed = 0;
  String get durationString {
    final mins = _secondsElapsed ~/ 60;
    final secs = _secondsElapsed % 60;
    return "${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }

  double get averageSpeedMs =>
      _secondsElapsed > 0 ? _totalDistance / _secondsElapsed : 0.0;

  String get paceString {
    if (averageSpeedMs < 0.5) return "0:00";
    final paceMinKm = 16.666666 / averageSpeedMs;
    final minutes = paceMinKm.floor();
    final seconds = ((paceMinKm - minutes) * 60).round();
    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }

  final List<LatLng> _routePoints = [];
  List<LatLng> get routePoints => List.unmodifiable(_routePoints);

  final Set<Polyline> _polylines = {};
  Set<Polyline> get polylines => _polylines;

  final List<ChartDataSpot> hrHistorySpots = [];
  final List<ChartDataSpot> paceHistorySpots = [];

  String? lastVideoUrl;
  int currentBpm = 145;
  int totalCalories = 0;

  int _lastAnnouncedKm = 0;
  final List<KmSplit> _kmSplits = [];
  int _lastKmTime = 0; // Seconds at last km

  Timer? _timer;
  StreamSubscription<Position>? _positionStream;

  bool _isStopping = false;
  bool _isInitialized = false;

  double get totalDistance => _totalDistance;
  int get secondsElapsed => _secondsElapsed;
  int get calories => totalCalories;

  // Callback for km milestones
  Function({
    required int km,
    required String totalTime,
    required String lastKmPace,
    required String averagePace,
    String? comparison,
  })? onKmMilestone;

  Future<void> startRun() async {
    debugPrint("🏃 startRun() called. Current state: $_state");

    if (_state == RunState.running || _isStopping) {
      debugPrint("⚠️ Already running or stopping — exiting");
      return;
    }

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

    debugPrint("✅ All location checks PASSED — initializing run");

    // Reset everything for a fresh start
    _secondsElapsed = 0;
    _totalDistance = 0.0;
    _routePoints.clear();
    _polylines.clear();
    hrHistorySpots.clear();
    paceHistorySpots.clear();
    lastVideoUrl = null;
    totalCalories = 0;
    _lastAnnouncedKm = 0;
    _kmSplits.clear();
    _lastKmTime = 0;
    _isInitialized = false;

    // Get initial position before starting
    try {
      debugPrint("📍 Getting initial position...");
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      _routePoints.add(LatLng(_currentPosition!.latitude, _currentPosition!.longitude));
      debugPrint("✅ Initial position: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}");
      _isInitialized = true;
    } catch (e) {
      debugPrint("❌ Failed to get initial position: $e");
      throw Exception("Failed to get your location. Please try again.");
    }

    // NOW set state to running and start everything
    _state = RunState.running;
    _startTimer();
    _startLocationUpdates();
    
    // Force UI update
    notifyListeners();

    debugPrint("✅ Run STARTED successfully - state: $_state, initialized: $_isInitialized");
  }

  void pauseRun() {
    debugPrint("⏸️ pauseRun() called. Current state: $_state");
    if (_state != RunState.running || _isStopping) {
      debugPrint("⚠️ Cannot pause - not running or stopping");
      return;
    }
    _state = RunState.paused;
    debugPrint("✅ Run PAUSED");
    notifyListeners();
  }

  void resumeRun() {
    debugPrint("▶️ resumeRun() called. Current state: $_state");
    if (_state != RunState.paused || _isStopping) {
      debugPrint("⚠️ Cannot resume - not paused or stopping");
      return;
    }
    _state = RunState.running;
    debugPrint("✅ Run RESUMED");
    notifyListeners();
  }

  void stopRun() {
    debugPrint("⏹️ stopRun() called. Current state: $_state");
    if (_isStopping) {
      debugPrint("⚠️ Already stopping");
      return;
    }
    _isStopping = true;

    _state = RunState.idle;
    _timer?.cancel();
    _positionStream?.cancel();

    debugPrint("✅ Run STOPPED - Distance: ${distanceString}km, Time: $durationString");
    debugPrint("📊 Final stats - Calories: $totalCalories, Points: ${_routePoints.length}");

    // Don't reset here - let the controller reset after saving
    _isStopping = false;
    notifyListeners();
  }

  void resetRun() {
    debugPrint("🔄 Resetting run data");
    _secondsElapsed = 0;
    _totalDistance = 0.0;
    _routePoints.clear();
    _polylines.clear();
    hrHistorySpots.clear();
    paceHistorySpots.clear();
    lastVideoUrl = null;
    totalCalories = 0;
    _lastAnnouncedKm = 0;
    _kmSplits.clear();
    _lastKmTime = 0;
    _isInitialized = false;
    notifyListeners();
  }

  void _startTimer() {
    debugPrint("⏱️ Starting timer");
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state == RunState.running) {
        _secondsElapsed++;

        // Check for km milestones
        final currentKm = (_totalDistance / 1000).floor();
        if (currentKm > _lastAnnouncedKm && currentKm > 0) {
          _handleKmMilestone(currentKm);
          _lastAnnouncedKm = currentKm;
        }

        // Calculate calories (rough estimate: 65 cal per km)
        totalCalories = ((_totalDistance / 1000) * 65).round();

        // Record performance snapshot every 10 seconds
        if (_secondsElapsed % 10 == 0) {
          _recordPerformanceSnapshot();
          debugPrint("📊 ${_secondsElapsed}s - Distance: ${distanceString}km, Pace: $paceString, Cal: $totalCalories");
        }

        notifyListeners();
      }
    });
  }

  void _handleKmMilestone(int km) {
    debugPrint("🎯 Milestone: ${km}km completed!");

    // Calculate last km time
    final lastKmDuration = _secondsElapsed - _lastKmTime;
    
    // Calculate last km pace
    final lastKmPaceValue = lastKmDuration / 60.0; // minutes per km
    final lastKmPaceMin = lastKmPaceValue.floor();
    final lastKmPaceSec = ((lastKmPaceValue - lastKmPaceMin) * 60).round();
    final lastKmPaceString = "$lastKmPaceMin:${lastKmPaceSec.toString().padLeft(2, '0')}";

    // Store this km split
    _kmSplits.add(KmSplit(
      kmNumber: km,
      durationSeconds: lastKmDuration,
      pace: lastKmPaceString,
    ));

    // Calculate comparison with previous km (skip for first km - no reference)
    String? comparison;
    if (km >= 2 && _kmSplits.length > 1) {
      final previousKm = _kmSplits[_kmSplits.length - 2];
      final timeDiff = lastKmDuration - previousKm.durationSeconds;

      if (timeDiff.abs() < 5) {
        comparison = "Same pace as previous kilometer.";
      } else if (timeDiff < 0) {
        final diffSec = timeDiff.abs();
        comparison = "Faster by $diffSec seconds. Great job!";
      } else {
        final diffSec = timeDiff;
        comparison = "Slower by $diffSec seconds. Keep pushing!";
      }
    }

    // Trigger voice announcement callback
    if (onKmMilestone != null) {
      onKmMilestone!(
        km: km,
        totalTime: durationString,
        lastKmPace: lastKmPaceString,
        averagePace: paceString,
        comparison: comparison,
      );
    }

    // Update last km time marker
    _lastKmTime = _secondsElapsed;
  }

  void _recordPerformanceSnapshot() {
    final x = _secondsElapsed / 60.0;
    hrHistorySpots.add(ChartDataSpot(x, currentBpm.toDouble()));
    final paceValue = averageSpeedMs > 0 ? 16.666666 / averageSpeedMs : 0.0;
    paceHistorySpots.add(ChartDataSpot(x, paceValue));
  }

  void _startLocationUpdates() {
    debugPrint("📍 Starting location updates");
    _positionStream?.cancel();
    
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters
      ),
    ).listen(
      (position) {
        if (_state != RunState.running) {
          debugPrint("⚠️ Location update received but not running (state: $_state)");
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
          
          // Only add distance if it's reasonable (less than 100m between updates)
          // This filters out GPS jumps
          if (distance < 100) {
            _totalDistance += distance;
            debugPrint("📍 +${distance.toStringAsFixed(1)}m (Total: ${(_totalDistance).toStringAsFixed(1)}m)");
          } else {
            debugPrint("⚠️ GPS jump detected: ${distance.toStringAsFixed(1)}m - ignoring");
          }
        }

        _currentPosition = position;
        _routePoints.add(LatLng(position.latitude, position.longitude));
        _updatePolylines();
        
        notifyListeners();
      },
      onError: (error) {
        debugPrint("❌ Location stream error: $error");
      },
      onDone: () {
        debugPrint("📍 Location stream closed");
      },
    );
  }

  void _updatePolylines() {
    _polylines
      ..clear()
      ..add(
        Polyline(
          polylineId: const PolylineId('run_route'),
          points: List.from(_routePoints),
          color: Colors.blueAccent,
          width: 6,
        ),
      );
  }

  @override
  void dispose() {
    debugPrint("🗑️ Disposing RunStateController");
    _timer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }
}