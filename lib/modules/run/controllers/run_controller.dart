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
      _firestore.collection('posts');

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

  // Voice
  final VoiceAnnouncer _voice = VoiceAnnouncer();
  int _lastAnnouncedKm = 0;
  double _previousKmPace = 0.0;

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
        (prev, doc) => prev + (doc.data()['durationSeconds'] as int? ?? 0));

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

    _lastAnnouncedKm = 0;
    _previousKmPace = 0.0;

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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Not signed in – run not saved")),
        );
      }
      return;
    }

    try {
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

      final aiPost = _generateAIPost(planTitle);
      final gifUrl = _getRandomMotivationalGif();

      await finalizeProPost(aiPost, gifUrl, planTitle: planTitle);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Run complete & auto-shared! $distanceString KM posted 🔥"),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e, stack) {
      debugPrint("Error in stopRun: $e\n$stack");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving/posting run: $e")),
        );
      }
    }

    _lastAnnouncedKm = 0;
    _previousKmPace = 0.0;
    notifyListeners();
  }

  /* ================= AI POST GENERATION ================= */
  String _generateAIPost(String planTitle) {
    final distance = distanceString;
    final time = durationString;
    final pace = paceString;
    final calories = totalCalories;

    final templates = [
      "Crushed $distance KM in $time at $pace pace! Torched $calories kcal 🔥 Beast mode activated.",
      "Run complete: $distance KM conquered in $time. Avg pace $pace. Feeling unstoppable 💪",
      "Another solid session: $distance KM done in $time with $pace pace. $calories kcal burned. Progress never stops!",
      "From start to finish — $distance KM smashed! Time $time, pace $pace. The grind continues 🏃‍♂️✨",
      "Logged $distance KM today at $pace pace in $time. $calories kcal down. Keep stacking wins!",
    ];

    final index = DateTime.now().millisecond % templates.length;
    String post = templates[index];

    if (planTitle != "Free Run") {
      post += "\nCrushed the $planTitle session!";
    }

    post += "\n\n#MajurunPro #RunStrong #FitnessJourney #${distance.replaceAll('.', '')}KM";

    return post;
  }

  String _getRandomMotivationalGif() {
    final gifs = [
      "https://media.giphy.com/media/3oEjI6SIIHBdRxXI40/giphy.gif",
      "https://media.giphy.com/media/l0HlRnAWXxn0MhKLK/giphy.gif",
      "https://media.giphy.com/media/26ufnwz3wDUli7GU0/giphy.gif",
      "https://media.giphy.com/media/3o7btPCcdNniyf0ArS/giphy.gif",
      "https://media.giphy.com/media/l41lLuYtK4J8tXb8Q/giphy.gif",
    ];
    return gifs[DateTime.now().millisecond % gifs.length];
  }

  /* ================= INTERNAL ================= */
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
          color: Colors.blueAccent,  // FIXED: Replaced deprecated withOpacity(1.0)
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
  if (user == null) {
    debugPrint("finalizeProPost: No authenticated user");
    return;
  }

  // FIXED: Write full structure that matches PostRepositoryImpl mapper
  final data = {
    'userId': user.uid,
    'username': user.displayName ?? 'Runner',  // Required for display
    'content': aiContent,
    'media': [
      {
        'url': videoUrl,
        'type': 'image',  // GIF/video treated as image
      }
    ],
    'createdAt': FieldValue.serverTimestamp(),  // Mapper looks for this
    'likes': [],  // Required field
    'planTitle': planTitle ?? "Free Run",
    // Optional but helpful for future feed display
    'distance': double.tryParse(distanceString) ?? 0.0,
    'avgBpm': currentBpm,
    // 'timestamp' can stay if you want it, but 'createdAt' is what mapper uses
    'timestamp': FieldValue.serverTimestamp(),
  };

  debugPrint("finalizeProPost writing full post data: $data");

  try {
    await postRepo.add(data);
    debugPrint("Auto-post SUCCESS to 'posts' collection");
  } catch (e, stack) {
    debugPrint("Auto-post FAILED: $e");
    debugPrint("Stack: $stack");
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