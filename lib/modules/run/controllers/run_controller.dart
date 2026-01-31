import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../home/data/repositories/post_repository_impl.dart';
import '../../home/domain/entities/post.dart';
import 'voice_announcer.dart';
import 'stats_controller.dart';
import 'package:uuid/uuid.dart';

enum RunState { idle, running, paused, stopped }

class RunController extends ChangeNotifier {
  final VoiceAnnouncer _announcer = VoiceAnnouncer();
  final StatsController _stats = StatsController();
  final PostRepositoryImpl _postRepo = PostRepositoryImpl();

  RunState state = RunState.idle;
  bool isVoiceEnabled = true;

  double distance = 0.0;
  int durationSeconds = 0;
  int currentBpm = 0;
  int totalCalories = 0;
  List<LatLng> routePoints = [];

  Timer? _timer;
  StreamSubscription<Position>? _positionStream;
  Position? _lastPosition;

  List<ChartSpot> hrHistorySpots = [];
  List<ChartSpot> paceHistorySpots = [];
  String? lastVideoUrl;

  // --- UI Getters ---
  String get distanceString => distance.toStringAsFixed(2);
  String get durationString {
    int h = durationSeconds ~/ 3600;
    int m = (durationSeconds % 3600) ~/ 60;
    int s = durationSeconds % 60;
    return h > 0 
      ? "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}"
      : "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }
  String get paceString {
    if (distance <= 0.05) return "0:00";
    double pace = (durationSeconds / 60) / distance;
    int minutes = pace.toInt();
    int seconds = ((pace - minutes) * 60).toInt();
    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }

  // --- Proxied Stats ---
  double get historyDistance => _stats.historyDistance;
  int get runStreak => _stats.runStreak;
  int get totalRuns => _stats.totalRuns;
  String get totalHistoryTimeStr => _stats.totalHistoryTimeStr;

  void toggleVoice() {
    isVoiceEnabled = !isVoiceEnabled;
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> getRunHistory() => _stats.getRunHistory();
  Future<Map<String, dynamic>?> getLastActivity() => _stats.getLastActivity();

  Future<void> speakSummary() async {
    if (isVoiceEnabled) {
      await Future.delayed(const Duration(milliseconds: 500));
      await _announcer.announceSummary(distance, durationSeconds, "Run Completed");
    }
  }

  Future<void> saveRunToHistory({String? planTitle}) async {
    await _stats.saveRunHistory(
      planTitle: planTitle ?? "Free Run",
      distanceKm: distance,
      durationSeconds: durationSeconds,
      pace: paceString,
    );
    notifyListeners();
  }

  // FIXED: Only ONE definition now. Using interpolation for URL.
  Future<void> postCurrentRunToFeed({required String caption}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String mapImageUrl = "";
    if (routePoints.isNotEmpty) {
      final String path = "color:0x00E676ff|weight:5|${routePoints.take(20).map((p) => "${p.latitude},${p.longitude}").join("|")}";
      const String apiKey = "YOUR_API_KEY"; 
      mapImageUrl = "https://maps.googleapis.com/maps/api/staticmap?size=600x400&path=$path&key=$apiKey";
    }

    final post = AppPost(
      id: const Uuid().v4(),
      userId: user.uid,
      username: user.displayName ?? "Runner",
      content: caption,
      media: mapImageUrl.isNotEmpty 
          ? [PostMedia(url: mapImageUrl, type: MediaType.image)] 
          : const [], // Optimized with const
      createdAt: DateTime.now(),
      likes: const [], // Optimized with const
      comments: const [], // Optimized with const
      routePoints: routePoints,
    );

    await _postRepo.createPost(
      post, 
      numericDistance: distance,
      type: 'run_complete',
    );
    
    notifyListeners(); 
  }

  void startRun() {
    _resetData();
    state = RunState.running;
    _startTimer();
    _startLocationTracking();
    if (isVoiceEnabled) _announcer.runStarted();
    notifyListeners();
  }

  void pauseRun() {
    state = RunState.paused;
    _timer?.cancel();
    _positionStream?.pause();
    if (isVoiceEnabled) _announcer.runPaused();
    notifyListeners();
  }

  void resumeRun() {
    state = RunState.running;
    _startTimer();
    _positionStream?.resume();
    if (isVoiceEnabled) _announcer.runResumed();
    notifyListeners();
  }

  Future<void> stopRun(BuildContext context) async {
    _timer?.cancel();
    _positionStream?.cancel();
    state = RunState.stopped;
    if (isVoiceEnabled) {
       _announcer.speak("Run complete. Total distance $distanceString kilometers.");
    }
    notifyListeners();
  }

  void discardRun() {
    _resetData();
    state = RunState.idle;
    notifyListeners();
  }

  void _resetData() {
    distance = 0.0;
    durationSeconds = 0;
    totalCalories = 0;
    currentBpm = 0;
    routePoints.clear();
    hrHistorySpots.clear();
    paceHistorySpots.clear();
    lastVideoUrl = null;
    _lastPosition = null;
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      durationSeconds++;
      totalCalories = (distance * 65).toInt();
      currentBpm = 135 + (durationSeconds % 15);
      if (durationSeconds % 5 == 0) {
        hrHistorySpots.add(ChartSpot(durationSeconds.toDouble(), currentBpm.toDouble()));
        paceHistorySpots.add(ChartSpot(durationSeconds.toDouble(), 5.0));
      }
      notifyListeners();
    });
  }

  void _startLocationTracking() async {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).listen((pos) {
      if (state == RunState.running) {
        if (_lastPosition != null) {
          distance += Geolocator.distanceBetween(_lastPosition!.latitude, _lastPosition!.longitude, pos.latitude, pos.longitude) / 1000;
        }
        _lastPosition = pos;
        routePoints.add(LatLng(pos.latitude, pos.longitude));
        notifyListeners();
      }
    });
  }

  Future<void> generateVeoVideo() async {
    lastVideoUrl = "generating";
    notifyListeners();
    await Future.delayed(const Duration(seconds: 2));
    lastVideoUrl = "ready";
    notifyListeners();
  }

  Future<void> finalizeProPost(String content, String video, {String? planTitle}) async {
    _resetData();
    state = RunState.idle;
    notifyListeners();
  }
}

class ChartSpot {
  final double x, y;
  ChartSpot(this.x, this.y);
}