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

  // Voice announcement tracking
  final VoiceAnnouncer _voice = VoiceAnnouncer();
  int _lastAnnouncedKm = 0;
  double _previousKmPace = 0.0; // in min/km

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
              .toList(),
        );
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
      (prev, doc) => prev + (doc.data()['durationSeconds'] as int? ?? 0),
    );

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

    // Reset voice tracking
    _lastAnnouncedKm = 0;
    _previousKmPace = 0.0;

    // Prime TTS with a welcome message (helps on iOS Safari/web)
    if (isVoiceEnabled) {
      await _voice.speak("Run started! Good luck. I'll announce every kilometer.");
    }

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
    if (user == null) {
      debugPrint("No authenticated user - cannot save or post");
      return;
    }

    try {
      // Save run history
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('training_history')
          .add({
        'planTitle': planTitle,
        'distanceKm': _totalDistance / 1000,
        'durationSeconds': _secondsElapsed,
        'pace': paceString,
        'completedAt': FieldValue.serverTimestamp(),
      });

      historyDistance += _totalDistance / 1000;
      runStreak += 1;

      await refreshHistoryStats();

      // Auto-post with AI text + motivational visual
      final motivationalPost = _generateAutoPostText(planTitle);
      final motivationalVisualUrl = _getMotivationalVisual();

      await finalizeProPost(
        motivationalPost,
        motivationalVisualUrl,
        planTitle: planTitle,
      );

      // Success feedback
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Run auto-shared! ${distanceString}KM posted 🔥"),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint("Error in stopRun: $e");
      debugPrint("Stack trace: $stackTrace");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save/share run: $e")),
        );
      }
    }

    // Reset voice & tracking
    _lastAnnouncedKm = 0;
    _previousKmPace = 0.0;

    notifyListeners();
  }

  /* ================= AUTO-POST HELPERS ================= */
  String _generateAutoPostText(String planTitle) {
    final distance = distanceString;
    final time = durationString;
    final pace = paceString;
    final calories = totalCalories;

    final templates = [
      "Just smashed $distance KM in $time at $pace pace! Burned $calories kcal 🔥 Another win for the grind.",
      "Run complete: $distance KM conquered in $time. Avg pace $pace. Feeling unstoppable 💪 #MajurunPro",
      "From start line to finish — $distance KM done! $time total, $pace pace, $calories kcal torched. Keep pushing!",
      "Today's mission accomplished: $distance KM @ $pace pace in $time. Body tired, soul on fire 🏃‍♂️✨",
      "Logged another solid one: $distance KM, $time, $pace avg. Progress is progress. #RunStrong",
    ];

    final randomIndex = DateTime.now().millisecond % templates.length;
    String text = templates[randomIndex];

    if (planTitle != "Free Run") {
      text += "\nCrushed the $planTitle workout today!";
    }

    text += "\n\n#Majurun #Running #FitnessJourney #${distance.replaceAll('.', '')}KM";

    return text;
  }

  String _getMotivationalVisual() {
    final motivationalGifs = [
      "https://media.giphy.com/media/3oEjI6SIIHBdRxXI40/giphy.gif", // running celebration
      "https://media.giphy.com/media/l0HlRnAWXxn0MhKLK/giphy.gif", // runner finish line joy
      "https://media.giphy.com/media/26ufnwz3wDUli7GU0/giphy.gif", // animated runner silhouette
      "https://media.giphy.com/media/3o7btPCcdNniyf0ArS/giphy.gif", // motivational achievement vibe
      "https://media.giphy.com/media/l41lLuYtK4J8tXb8Q/giphy.gif", // running with energy
    ];

    final index = DateTime.now().millisecond % motivationalGifs.length;
    return motivationalGifs[index];
  }

  /* ================= INTERNAL ================= */
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_state == RunState.running) {
        _secondsElapsed++;

        // Announce every full kilometer
        final currentKm = (_totalDistance / 1000).floor();
        if (currentKm > _lastAnnouncedKm && currentKm > 0 && isVoiceEnabled) {
          debugPrint("Announcing $currentKm km");
          await _voice.announceKm(currentKm);

          // Pace comparison & advice
          final currentPaceMinKm = averageSpeedMs > 0 ? 16.666666 / averageSpeedMs : 0.0;

          if (_previousKmPace > 0) {
            String advice;
            final paceDiff = currentPaceMinKm - _previousKmPace;

            if (paceDiff < -0.15) {
              advice = "You're getting faster! Excellent work!";
            } else if (paceDiff > 0.15) {
              advice = "Try to pick up the pace a little.";
            } else {
              advice = "Solid steady pace. Keep it up!";
            }

            debugPrint("Pace advice: $advice");
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
          color: Colors.blueAccent.withValues(alpha: 1.0),
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
    debugPrint("finalizeProPost called | Auth user: ${user?.uid ?? 'NULL - not signed in'}");
    debugPrint("Auth currentUser exists: ${user != null}");

    if (user == null) {
      debugPrint("Cannot post: No authenticated user");
      return;
    }

    final data = {
      'userId': user.uid,
      'content': aiContent,
      'videoUrl': videoUrl,
      'planTitle': planTitle ?? "Free Run",
      'timestamp': FieldValue.serverTimestamp(),
    };

    debugPrint("Posting to collection: ${postRepo.path}");
    debugPrint("Data payload: $data");

    try {
      await postRepo.add(data);
      debugPrint("Post SUCCESS");
    } catch (e, stackTrace) {
      debugPrint("Post FAILED: $e");
      debugPrint("Full stack: $stackTrace");
      rethrow;
    }
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