import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum RunState { idle, running, paused }

class ChartDataSpot {
  final double x;
  final double y;
  ChartDataSpot(this.x, this.y);
}

class RunController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- STATE ---
  RunState _state = RunState.idle;
  RunState get state => _state;

  Position? _currentPosition;
  LatLng? get currentLocation => _currentPosition != null
      ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
      : null;

  double _totalDistance = 0.0; 
  int _secondsElapsed = 0;
  Timer? _timer;
  StreamSubscription<Position>? _positionStream;

  // --- PRO FEATURES & METRICS ---
  double? temp = 27.0; 
  bool isVoiceEnabled = true;
  int currentBpm = 145;
  int totalCalories = 0;
  double historyDistance = 0.0;
  int runStreak = 0;
  String totalHistoryTimeStr = "15H:30M";
  String? lastVideoUrl;

  // --- ANALYSIS DATA ---
  List<double> kmSplits = [];
  double _lastKmDistance = 0.0;
  int _lastKmTime = 0;
  String postRunAnalysis = "";
  
  final List<LatLng> _routePoints = [];
  List<LatLng> get routePoints => List.unmodifiable(_routePoints);
  final Set<Polyline> _polylines = {};
  Set<Polyline> get polylines => _polylines;

  List<ChartDataSpot> hrHistorySpots = [];
  List<ChartDataSpot> paceHistorySpots = [];

  // --- GETTERS ---
  String get distanceString => (_totalDistance / 1000).toStringAsFixed(2);
  double get totalDistanceKm => _totalDistance / 1000;
  String get durationString {
    int mins = _secondsElapsed ~/ 60;
    int secs = _secondsElapsed % 60;
    return "${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }
  double get averageSpeedMs => _secondsElapsed > 0 ? _totalDistance / _secondsElapsed : 0.0;
  String get paceString {
    if (averageSpeedMs < 0.5) return "0:00";
    double paceMinKm = 16.666666 / averageSpeedMs;
    int minutes = paceMinKm.floor();
    int seconds = ((paceMinKm - minutes) * 60).round();
    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }

  // --- MISSING METHODS FIXED HERE ---

  /// Requirement: Fixes the error in run_history_screen.dart
  Stream<QuerySnapshot> getPostStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return _firestore
        .collection('feed')
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Requirement: Fixes the error in run_summary_screen.dart
  Future<void> finalizeProPost(String aiContent, String videoUrl, {String? planTitle}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('feed').add({
      'userId': user.uid,
      'content': aiContent,
      'videoUrl': videoUrl,
      'planTitle': planTitle ?? "Free Run",
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // --- CORE LOGIC ---

  Future<void> startRun() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    _state = RunState.running;
    _secondsElapsed = 0;
    _totalDistance = 0.0;
    _lastKmDistance = 0.0;
    _lastKmTime = 0;
    kmSplits.clear();
    _routePoints.clear();
    _polylines.clear();
    hrHistorySpots.clear();
    paceHistorySpots.clear();
    _startTimer();
    _startLocationUpdates();
    notifyListeners();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_state == RunState.running) {
        _secondsElapsed++;
        totalCalories = ((_totalDistance / 1000) * 65).round();
        if (_secondsElapsed % 30 == 0) _runAICoaching();
        if (_secondsElapsed % 10 == 0) _recordPerformanceSnapshot();
        notifyListeners();
      }
    });
  }

  void _runAICoaching() {
    if (!isVoiceEnabled) return;
    if (currentBpm > 175) {
      debugPrint("AI: Slow down!");
    } else if (totalDistanceKm > 0.5 && averageSpeedMs < 2.0) {
      debugPrint("AI: Increase pace!");
    }
  }

  void _recordPerformanceSnapshot() {
    double xValue = _secondsElapsed / 60.0;
    hrHistorySpots.add(ChartDataSpot(xValue, currentBpm.toDouble()));
    double currentPaceValue = averageSpeedMs > 0 ? 16.666666 / averageSpeedMs : 0;
    paceHistorySpots.add(ChartDataSpot(xValue, currentPaceValue));
  }

  void _startLocationUpdates() {
    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).listen((Position position) {
      if (_state == RunState.running) {
        if (_currentPosition != null) {
          final distance = Geolocator.distanceBetween(
            _currentPosition!.latitude, _currentPosition!.longitude,
            position.latitude, position.longitude,
          );
          _totalDistance += distance;
          if ((_totalDistance - _lastKmDistance) >= 1000) {
            kmSplits.add((_secondsElapsed - _lastKmTime).toDouble());
            _lastKmDistance = _totalDistance;
            _lastKmTime = _secondsElapsed;
          }
        }
        _currentPosition = position;
        _routePoints.add(LatLng(position.latitude, position.longitude));
        _updatePolylines();
        notifyListeners();
      }
    });
  }

  void _updatePolylines() {
    _polylines.clear();
    _polylines.add(Polyline(
      polylineId: const PolylineId('run_route'),
      points: List.from(_routePoints),
      color: Colors.blueAccent,
      width: 6,
    ));
  }

  void pauseRun() { _state = RunState.paused; notifyListeners(); }
  void resumeRun() { _state = RunState.running; notifyListeners(); }

  Future<void> stopRun(BuildContext context, {String? planTitle}) async {
    _generatePostRunAnalysis();
    _state = RunState.idle;
    _timer?.cancel();
    _positionStream?.cancel();
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).collection('training_history').add({
          'planTitle': planTitle ?? "Free Run",
          'distanceKm': double.parse(distanceString),
          'durationSeconds': _secondsElapsed,
          'pace': paceString,
          'completedAt': FieldValue.serverTimestamp(),
          'analysis': postRunAnalysis,
        });
        historyDistance += (_totalDistance / 1000);
        runStreak += 1;
      } catch (e) {
        debugPrint("Error: $e");
      }
    }
    notifyListeners();
  }

  void _generatePostRunAnalysis() {
    if (kmSplits.isEmpty) {
      postRunAnalysis = "Keep pushing next time!";
      return;
    }
    double fastSplit = kmSplits.reduce((a, b) => a < b ? a : b);
    double slowSplit = kmSplits.reduce((a, b) => a > b ? a : b);
    postRunAnalysis = "Fastest KM: ${(fastSplit/60).toStringAsFixed(2)} min/km. Slowest KM: ${(slowSplit/60).toStringAsFixed(2)} min/km.";
  }

  Future<void> generateVeoVideo() async {
    await Future.delayed(const Duration(seconds: 2));
    lastVideoUrl = "https://example.com/video.mp4";
    notifyListeners();
  }

  void toggleVoice() { isVoiceEnabled = !isVoiceEnabled; notifyListeners(); }
  void toggleHeartRateVoice(bool v) {}
  void toggleHeartRateTracking(bool v) {}
  void checkMonthlySummary() {}

  @override
  void dispose() {
    _timer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }
}