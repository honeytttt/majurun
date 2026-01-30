import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum RunState { idle, running, paused }

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

  Timer? _timer;
  StreamSubscription<Position>? _positionStream;

  int currentBpm = 145;
  int totalCalories = 0;

  int _lastAnnouncedKm = 0;
  double _previousKmPace = 0.0;

  Future<void> startRun() async {
    if (_state == RunState.running) return;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    _state = RunState.running;
    _secondsElapsed = 0;
    _totalDistance = 0.0;
    _routePoints.clear();
    _polylines.clear();
    hrHistorySpots.clear();
    paceHistorySpots.clear();
    lastVideoUrl = null;

    _lastAnnouncedKm = 0;
    _previousKmPace = 0.0;

    _startTimer();
    _startLocationUpdates();
    notifyListeners();
  }

  void pauseRun() {
    if (_state != RunState.running) return;
    _state = RunState.paused;
    notifyListeners();
  }

  void resumeRun() {
    if (_state != RunState.paused) return;
    _state = RunState.running;
    notifyListeners();
  }

  void stopRun() {
    _state = RunState.idle;
    _timer?.cancel();
    _positionStream?.cancel();
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_state == RunState.running) {
        _secondsElapsed++;

        final currentKm = (_totalDistance / 1000).floor();
        if (currentKm > _lastAnnouncedKm && currentKm > 0 && isVoiceEnabled) {
          await Future.delayed(const Duration(milliseconds: 300));
          await _voice.announceKm(currentKm);

          final currentPaceMinKm = averageSpeedMs > 0 ? 16.666666 / averageSpeedMs : 0.0;
          if (_previousKmPace > 0) {
            String advice;
            final diff = currentPaceMinKm - _previousKmPace;
            if (diff < -0.15) {
              advice = "You're getting faster! Excellent work!";
            } else if (diff > 0.15) {
              advice = "Try to pick up the pace a little.";
            } else {
              advice = "Solid steady pace. Keep it up!";
            }
            await Future.delayed(const Duration(milliseconds: 300));
            await _voice.speak(advice);
          }
          _previousKmPace = currentPaceMinKm;
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
    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((position) {
      if (_state != RunState.running) return;

      if (_currentPosition != null) {
        _totalDistance += Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          position.latitude,
          position.longitude,
        );
      }

      _currentPosition = position;
      _routePoints.add(LatLng(position.latitude, position.longitude));
      _updatePolylines();
      notifyListeners();
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
    _timer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }
}