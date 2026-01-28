import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:majurun/modules/run/services/voice_announcer.dart';

enum RunState { idle, running, paused }

class ChartDataSpot {
  final double x;
  final double y;
  const ChartDataSpot(this.x, this.y);
}

/// Run-specific AppPost
class RunAppPost {
  final String id;
  final String content;
  final String? videoUrl;
  final Timestamp timestamp;

  RunAppPost({
    required this.id,
    required this.content,
    this.videoUrl,
    required this.timestamp,
  });

  factory RunAppPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RunAppPost(
      id: doc.id,
      content: data['content'] ?? '',
      videoUrl: data['videoUrl'],
      timestamp: data['timestamp'] ?? Timestamp.now(),
    );
  }
}

class RunController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get postRepo =>
      _firestore.collection('feed');

  /* ================= STATE ================= */
  RunState _state = RunState.idle;
  RunState get state => _state;

  Position? _currentPosition;
  LatLng? get currentLatLng => _currentPosition == null
      ? null
      : LatLng(_currentPosition!.latitude, _currentPosition!.longitude);

  double _totalDistance = 0.0;
  int _secondsElapsed = 0;

  Timer? _timer;
  StreamSubscription<Position>? _positionStream;

  final List<LatLng> _routePoints = [];
  List<LatLng> get routePoints => List.unmodifiable(_routePoints);

  final Set<Polyline> _polylines = {};
  Set<Polyline> get polylines => _polylines;

  final List<ChartDataSpot> hrHistorySpots = [];
  final List<ChartDataSpot> paceHistorySpots = [];

  String? lastVideoUrl;
  int currentBpm = 145;
  int totalCalories = 0;
  bool isVoiceEnabled = true;

  double historyDistance = 0.0;
  int runStreak = 0;

  /* ================= GETTERS ================= */
  String get distanceString => (_totalDistance / 1000).toStringAsFixed(2);

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

  int totalRuns = 0;
  String totalHistoryTimeStr = "00:00:00";

  /* ================= FIRESTORE HELPERS ================= */
  Stream<List<RunAppPost>> getPostStream() {
    return postRepo.orderBy('timestamp', descending: true).snapshots().map(
        (snapshot) => snapshot.docs
            .map((doc) => RunAppPost.fromFirestore(doc))
            .toList());
  }

  Future<void> refreshHistoryStats() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final history = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('training_history')
        .get();

    totalRuns = history.docs.length;

    int totalSec = history.docs.fold<int>(
        0,
        (prev, doc) =>
            prev + (doc.data()['durationSeconds'] as int? ?? 0));

    final hours = totalSec ~/ 3600;
    final minutes = (totalSec % 3600) ~/ 60;
    final seconds = totalSec % 60;

    totalHistoryTimeStr =
        "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";

    notifyListeners();
  }

  /* ================= RUN CONTROL ================= */
  Future<void> startRun() async {
    if (_state == RunState.running) return;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

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

  Future<void> stopRun(BuildContext context, {String planTitle = "Free Run"}) async {
    _state = RunState.idle;
    _timer?.cancel();
    _positionStream?.cancel();

    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('training_history')
            .add({
          'planTitle': planTitle,
          'distanceKm': _totalDistance / 1000, // double
          'durationSeconds': _secondsElapsed,
          'pace': paceString,
          'completedAt': FieldValue.serverTimestamp(),
        });

        historyDistance += _totalDistance / 1000;
        runStreak += 1;

        await refreshHistoryStats();
      } catch (e) {
        debugPrint("Error saving run history: $e");
      }
    }

    notifyListeners();
  }

  /* ================= INTERNAL ================= */
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state == RunState.running) {
        _secondsElapsed++;
        totalCalories = ((_totalDistance / 1000) * 65).round();
        if (_secondsElapsed % 10 == 0) _recordPerformanceSnapshot();
        notifyListeners();
      }
    });
  }

  void _recordPerformanceSnapshot() {
    final x = _secondsElapsed / 60.0;
    hrHistorySpots.add(ChartDataSpot(x, currentBpm.toDouble()));
    final paceValue = averageSpeedMs > 0 ? 16.666666 / averageSpeedMs : 0.0;  // Changed to 0.0
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
          color: Colors.blueAccent.withValues(alpha: 1.0),  // Fixed deprecated withOpacity
          width: 6,
        ),
      );
  }

  /* ================= MEDIA ================= */
  Future<void> generateVeoVideo() async {
    await Future.delayed(const Duration(seconds: 2));
    lastVideoUrl = "https://example.com/replay.mp4";
    notifyListeners();
  }

  Future<void> finalizeProPost(
    String aiContent,
    String videoUrl, {
    String? planTitle,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await postRepo.add({
      'userId': user.uid,
      'content': aiContent,
      'videoUrl': videoUrl,
      'planTitle': planTitle ?? "Free Run",
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void toggleVoice() {
    isVoiceEnabled = !isVoiceEnabled;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }
}