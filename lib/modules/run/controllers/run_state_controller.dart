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

  Timer? _timer;
  StreamSubscription<Position>? _positionStream;
  
  // Add these variables to track pause/resume
  DateTime? _runStartTime;
  DateTime? _pauseStartTime;
  int _pausedSeconds = 0; // Total seconds spent in paused state

  bool _isStopping = false; // Flag to prevent double stop

  double get totalDistance => _totalDistance; // Exposed
  int get secondsElapsed => _secondsElapsed; // Exposed
  int get calories => totalCalories; // Exposed

  Future<void> startRun() async {
    debugPrint("=== RunStateController.startRun() called ===");
    if (_state == RunState.running) {
      debugPrint("Already running, returning");
      return;
    }

    debugPrint("Checking location service...");
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint("Location service not enabled");
      return;
    }

    debugPrint("Checking permissions...");
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      debugPrint("Permission denied, requesting...");
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint("Permission still denied after request");
      return;
    }

    debugPrint("Starting run initialization...");
    _state = RunState.running;
    _secondsElapsed = 0;
    _totalDistance = 0.0;
    _routePoints.clear();
    _polylines.clear();
    hrHistorySpots.clear();
    paceHistorySpots.clear();
    lastVideoUrl = null;
    _runStartTime = DateTime.now();
    _pausedSeconds = 0;
    _pauseStartTime = null;

    _lastAnnouncedKm = 0;

    debugPrint("Starting timer and location updates...");
    _startTimer();
    _startLocationUpdates();
    
    debugPrint("Notifying listeners...");
    notifyListeners();
    debugPrint("=== RunStateController.startRun() completed ===");
  }

  void pauseRun() {
    debugPrint("=== RunStateController.pauseRun() called ===");
    if (_state != RunState.running) {
      debugPrint("Not running, returning");
      return;
    }
    
    _state = RunState.paused;
    _pauseStartTime = DateTime.now();
    _timer?.cancel();
    _positionStream?.pause();
    debugPrint("Run paused at $_pauseStartTime");
    notifyListeners();
  }

  void resumeRun() {
    debugPrint("=== RunStateController.resumeRun() called ===");
    if (_state != RunState.paused) {
      debugPrint("Not paused, returning");
      return;
    }
    
    // Calculate time spent paused
    if (_pauseStartTime != null) {
      final pauseDuration = DateTime.now().difference(_pauseStartTime!);
      _pausedSeconds += pauseDuration.inSeconds;
      debugPrint("Pause duration: ${pauseDuration.inSeconds} seconds");
      debugPrint("Total paused seconds: $_pausedSeconds");
      _pauseStartTime = null;
    }
    
    _state = RunState.running;
    _startTimer();
    _positionStream?.resume();
    debugPrint("Run resumed");
    notifyListeners();
  }

  void stopRun() {
    debugPrint("=== RunStateController.stopRun() called ===");
    if (_isStopping) {
      debugPrint("Already stopping, returning");
      return; // Prevent double call
    }
    _isStopping = true;

    _state = RunState.idle;
    _timer?.cancel();
    _positionStream?.cancel();
    _runStartTime = null;
    _pauseStartTime = null;
    _pausedSeconds = 0;

    debugPrint("Resetting run...");
    resetRun(); // Reset to initial state

    _isStopping = false;
    debugPrint("Notifying listeners...");
    notifyListeners();
    debugPrint("=== RunStateController.stopRun() completed ===");
  }

  void resetRun() {
    debugPrint("Resetting run state...");
    _secondsElapsed = 0;
    _totalDistance = 0.0;
    _routePoints.clear();
    _polylines.clear();
    hrHistorySpots.clear();
    paceHistorySpots.clear();
    lastVideoUrl = null;
    totalCalories = 0;
    _lastAnnouncedKm = 0;
    _runStartTime = null;
    _pauseStartTime = null;
    _pausedSeconds = 0;
  }

  void _startTimer() {
    debugPrint("Starting timer...");
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_state == RunState.running && _runStartTime != null) {
        // Calculate elapsed time correctly accounting for pauses
        final totalDuration = DateTime.now().difference(_runStartTime!);
        _secondsElapsed = totalDuration.inSeconds - _pausedSeconds;
        
        debugPrint("Timer tick - secondsElapsed: $_secondsElapsed");

        final currentKm = (_totalDistance / 1000).floor();
        if (currentKm > _lastAnnouncedKm && currentKm > 0) {
          _lastAnnouncedKm = currentKm;
        }

        totalCalories = ((_totalDistance / 1000) * 65).round();
        if (_secondsElapsed % 10 == 0) _recordPerformanceSnapshot();
        notifyListeners();
      }
    });
  }

  void _recordPerformanceSnapshot() {
    final x = _secondsElapsed / 60.0;
    hrHistorySpots.add(ChartDataSpot(x, currentBpm.toDouble()));
    final paceValue = averageSpeedMs > 0 ? 16.666666 / averageSpeedMs : 0.0;
    paceHistorySpots.add(ChartDataSpot(x, paceValue));
  }

  void _startLocationUpdates() {
    debugPrint("Starting location updates...");
    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((position) {
      if (_state != RunState.running) return;

      if (_currentPosition != null) {
        final distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        _totalDistance += distance;
        debugPrint("Position update - distance added: $distance, total: $_totalDistance");
      }

      _currentPosition = position;
      _routePoints.add(LatLng(position.latitude, position.longitude));
      _updatePolylines();
      notifyListeners();
    }, onError: (error) {
      debugPrint("Location error: $error");
    });
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
    debugPrint("RunStateController disposing...");
    _timer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }
}