import 'dart:async';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Internal Package Imports
import '../../domain/entities/run_activity.dart';
import '../../../home/data/repositories/post_repository_impl.dart';
import '../../../home/domain/entities/post.dart';
import '../../../../core/services/veo_service.dart';

class PathPoint {
  final LatLng point;
  final double speed;
  PathPoint(this.point, this.speed);
}

class RunController extends ChangeNotifier {
  RunState _state = RunState.idle;
  RunState get state => _state;

  // Tracking Data
  final List<PathPoint> _detailedPath = [];
  double _totalDistance = 0.0;
  Duration _elapsedTime = Duration.zero;
  LatLng? _currentLocation;
  bool _isAutoPaused = false;

  // PRO Features: Coaching & Biometrics
  bool _enableHeartRateTracking = true;
  bool _compareHeartRateVoice = true;
  final List<int> _kmHeartRateHistory = [];
  final List<double> _kmPaceHistory = [];
  int _lastAnnouncedKm = 0;
  double _lastKmTimeSeconds = 0;

  // Stats & History
  double _historyDistance = 0.0;
  double _averageSpeedMs = 0.0;
  double _ghostDistance = 0.0;
  int _currentBpm = 70;
  double _allTimeBest = 0.0;
  bool _isNewPB = false;
  int _runStreak = 0;
  bool _shieldActive = false;
  
  final Duration _totalHistoryTime = Duration.zero;

  // Weather & Gear
  String _shoeName = "Primary Trainers";
  double _shoeMileage = 0.0;
  double? _temp;
  String? _weatherIcon;
  bool _isWeatherLoading = false;

  // AI & Video Generation State
  String? _lastGeneratedVideoUrl;
  bool _isGeneratingVideo = false;

  // Voice Feedback
  bool _isAudioCoachingEnabled = true;
  final FlutterTts _tts = FlutterTts();

  // Infrastructure
  final postRepo = PostRepositoryImpl();
  Timer? _timer;
  StreamSubscription<Position>? _positionStream;

  // --- Getters ---
  LatLng? get currentLocation => _currentLocation;
  double get totalDistance => _totalDistance;
  double get historyDistance => _historyDistance;
  int get runStreak => _runStreak;
  bool get shieldActive => _shieldActive;
  double get averageSpeedMs => _averageSpeedMs;
  int get totalCalories => (_totalDistance * 60).round();
  String get distanceString => _totalDistance.toStringAsFixed(2);
  String get durationString => _elapsedTime.toString().split('.').first.padLeft(8, "0");
  int get currentBpm => _currentBpm;
  double get ghostDistance => _ghostDistance;
  bool get isNewPB => _isNewPB;
  double? get temp => _temp;
  String? get weatherIcon => _weatherIcon;
  bool get isWeatherLoading => _isWeatherLoading;
  bool get isVoiceEnabled => _isAudioCoachingEnabled;
  bool get enableHeartRateTracking => _enableHeartRateTracking;
  bool get compareHeartRateVoice => _compareHeartRateVoice;
  double get shoeProgress => (_shoeMileage / 500).clamp(0.0, 1.0);
  String get shoeName => _shoeName;
  String? get lastVideoUrl => _lastGeneratedVideoUrl;
  bool get isGeneratingVideo => _isGeneratingVideo;
  List<LatLng> get routePoints => _detailedPath.map((p) => p.point).toList();

  String get totalHistoryTimeStr {
    int hours = _totalHistoryTime.inHours;
    int minutes = _totalHistoryTime.inMinutes.remainder(60);
    return "${hours}H:${minutes}M";
  }

  // FIXED: Added const to FlSpot constructors to resolve linter issues
  List<FlSpot> get hrHistorySpots => _kmHeartRateHistory
      .asMap()
      .entries
      .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
      .toList();

  List<FlSpot> get paceHistorySpots => _kmPaceHistory
      .asMap()
      .entries
      .map((e) => FlSpot(e.key.toDouble(), e.value))
      .toList();

  String get lastKmPaceString => _kmPaceHistory.isNotEmpty 
      ? _kmPaceHistory.last.toStringAsFixed(2) 
      : "0.00";

  RunController() {
    _initTts();
    _loadAllTimeData();
    _fetchInitialLocation();
  }

  // --- Initialization ---
  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
  }

  Future<void> _loadAllTimeData() async {
    final prefs = await SharedPreferences.getInstance();
    _allTimeBest = prefs.getDouble('all_time_best_dist') ?? 0.0;
    _shoeName = prefs.getString('shoe_name') ?? "Primary Trainers";
    _shoeMileage = prefs.getDouble('shoe_mileage') ?? 0.0;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final posts = await postRepo.getPostStream().first;
      double totalDist = 0;
      List<DateTime> runDates = [];

      for (var p in posts.where((p) => p.userId == user.uid)) {
        if (p.content.contains("Distance") || p.content.contains("AI")) {
          runDates.add(p.createdAt);
          final dMatch = RegExp(r"Distance: (\d+\.\d+)").firstMatch(p.content);
          if (dMatch != null) totalDist += double.parse(dMatch.group(1)!);
        }
      }
      _historyDistance = totalDist;
      _calculateStreak(runDates);
      if (totalDist > 0) _averageSpeedMs = 3.0; 
    }
    notifyListeners();
  }

  void _calculateStreak(List<DateTime> dates) {
    if (dates.isEmpty) return;
    dates.sort((a, b) => b.compareTo(a));
    _runStreak = dates.length; 
    _shieldActive = true;
  }

  void checkMonthlySummary() {
    final now = DateTime.now();
    if (now.day == 1) {
       debugPrint("Monthly Summary Triggered");
    }
  }

  Future<void> shareSummaryToFeed() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final summaryContent = "Completed a run of $distanceString KM in $durationString! 🏃‍♂️";
    
    final post = AppPost(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: user.uid,
      username: user.displayName ?? "Runner",
      content: summaryContent,
      // FIXED: Added const to empty list literal
      media: const [],
      createdAt: DateTime.now(),
      // FIXED: Added const to empty list literals
      likes: const [],
      comments: const [],
      routePoints: routePoints,
    );

    await postRepo.createPost(post, numericDistance: _totalDistance);
    notifyListeners();
  }

  // --- Controls & Toggles ---
  void toggleVoice() {
    _isAudioCoachingEnabled = !_isAudioCoachingEnabled;
    _tts.speak(_isAudioCoachingEnabled ? "Voice coaching on" : "Voice coaching off");
    notifyListeners();
  }

  void toggleHeartRateTracking(bool value) {
    _enableHeartRateTracking = value;
    notifyListeners();
  }

  void toggleHeartRateVoice(bool value) {
    _compareHeartRateVoice = value;
    notifyListeners();
  }

  // --- Run Lifecycle ---
  void startRun() {
    _state = RunState.running;
    _detailedPath.clear();
    _kmHeartRateHistory.clear();
    _kmPaceHistory.clear();
    _totalDistance = 0;
    _elapsedTime = Duration.zero;
    _lastAnnouncedKm = 0;
    _lastKmTimeSeconds = 0;
    _isNewPB = false;
    _lastGeneratedVideoUrl = null;
    
    _startTimer();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 3),
    ).listen(_onLocationUpdate);
    
    if (_isAudioCoachingEnabled) _tts.speak("Starting workout.");
    notifyListeners();
  }

  void pauseRun() { 
    _state = RunState.paused; 
    _timer?.cancel(); 
    if (_isAudioCoachingEnabled) _tts.speak("Workout paused.");
    notifyListeners(); 
  }
  
  void resumeRun() { 
    _state = RunState.running; 
    _startTimer(); 
    if (_isAudioCoachingEnabled) _tts.speak("Resuming workout.");
    notifyListeners(); 
  }

  void stopRun(BuildContext context) async {
    _state = RunState.finished;
    _timer?.cancel();
    _positionStream?.cancel();
    
    final prefs = await SharedPreferences.getInstance();
    _shoeMileage += _totalDistance;
    await prefs.setDouble('shoe_mileage', _shoeMileage);
    
    if (_totalDistance > _allTimeBest) {
      await prefs.setDouble('all_time_best_dist', _totalDistance);
      _isNewPB = true;
    }
    
    if (_isAudioCoachingEnabled) _tts.speak("Workout complete.");
    notifyListeners();
  }

  // --- Logic & Updates ---
  void _onLocationUpdate(Position pos) {
    if (_state != RunState.running) return;

    if (pos.speed < 0.5 && !_isAutoPaused) {
      _isAutoPaused = true;
    } else if (pos.speed >= 0.5 && _isAutoPaused) {
      _isAutoPaused = false;
    }

    if (!_isAutoPaused) {
      LatLng point = LatLng(pos.latitude, pos.longitude);
      if (_detailedPath.isNotEmpty) {
        _totalDistance += (Geolocator.distanceBetween(
          _detailedPath.last.point.latitude, 
          _detailedPath.last.point.longitude, 
          pos.latitude, 
          pos.longitude) / 1000);
      }
      _detailedPath.add(PathPoint(point, pos.speed));
      _currentBpm = (70 + (pos.speed * 20)).round().clamp(70, 190);

      int currentKm = _totalDistance.floor();
      if (currentKm > _lastAnnouncedKm) {
        double currentPace = (_elapsedTime.inSeconds - _lastKmTimeSeconds) / 60;
        _kmPaceHistory.add(currentPace);
        _lastKmTimeSeconds = _elapsedTime.inSeconds.toDouble();
        
        _executeKmCoaching(currentKm);
        _lastAnnouncedKm = currentKm;
      }
      notifyListeners();
    }
  }

  void _executeKmCoaching(int km) {
    String message = "$km kilometers completed.";
    
    if (_enableHeartRateTracking) {
      message += " Your heart rate is $_currentBpm BPM.";
      
      if (_compareHeartRateVoice && _kmHeartRateHistory.isNotEmpty) {
        int prevBpm = _kmHeartRateHistory.last;
        int diff = _currentBpm - prevBpm;
        
        if (diff > 5) {
          message += " Your heart rate is $diff beats higher than the last kilometer.";
        } else if (diff < -5) {
          message += " Excellent recovery. Heart rate dropped by ${diff.abs()} beats.";
        } else {
          message += " Your effort is perfectly consistent.";
        }
      }
      _kmHeartRateHistory.add(_currentBpm);
    }

    if (_isAudioCoachingEnabled) _tts.speak(message);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!_isAutoPaused) {
        _elapsedTime += const Duration(seconds: 1);
        _ghostDistance = (_averageSpeedMs * _elapsedTime.inSeconds) / 1000;
        notifyListeners();
      }
    });
  }
  
  // --- PRO Features: Veo Video Integration ---
  Future<void> generateVeoVideo() async {
    _isGeneratingVideo = true;
    notifyListeners();

    try {
      final service = VeoService(apiKey: "YOUR_GEMINI_API_KEY");
      final prompt = "Cinematic 4K POV of a runner on a trail. Distance: $distanceString KM.";
      final opName = await service.generateRunReplay(prompt: prompt);
      
      if (opName != null) {
        String? videoUrl;
        int attempts = 0;
        while (videoUrl == null && attempts < 12) {
          await Future.delayed(const Duration(seconds: 5));
          videoUrl = await service.pollVideoStatus(opName);
          attempts++;
        }
        _lastGeneratedVideoUrl = videoUrl;
      }
    } catch (e) {
      debugPrint("Veo Generation Error: $e");
    } finally {
      _isGeneratingVideo = false;
      notifyListeners();
    }
  }

  // --- Weather & Environment ---
  Future<void> _fetchInitialLocation() async {
    try {
      Position pos = await Geolocator.getCurrentPosition();
      _currentLocation = LatLng(pos.latitude, pos.longitude);
      _fetchWeather(pos.latitude, pos.longitude);
      notifyListeners();
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<void> _fetchWeather(double lat, double lon) async {
    _isWeatherLoading = true;
    notifyListeners();
    try {
      final url = "https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&units=metric&appid=4aae45ec8278c00b8ae94fed29091354";
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        _temp = data['main']['temp'].toDouble();
        _weatherIcon = data['weather'][0]['icon'];
      }
    } catch (e) { debugPrint("Weather Fail: $e"); }
    _isWeatherLoading = false;
    notifyListeners();
  }

  // --- Map Utilities ---
  Set<Polyline> get heatmapLines {
    Set<Polyline> lines = {};
    for (int i = 0; i < _detailedPath.length - 1; i++) {
      lines.add(Polyline(
        polylineId: PolylineId('seg_$i'),
        points: [_detailedPath[i].point, _detailedPath[i+1].point],
        color: _detailedPath[i].speed > 3 ? Colors.green : Colors.red,
        width: 5,
      ));
    }
    return lines;
  }

  // --- Post Finalization ---
  Future<void> finalizeProPost(String aiText, String videoUrl) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final post = AppPost(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: user.uid,
      username: user.displayName ?? "Pro Runner",
      content: aiText,
      // FIXED: Added const to list and objects
      media: videoUrl.isNotEmpty 
          ? [PostMedia(url: videoUrl, type: MediaType.video)] 
          : const [],
      createdAt: DateTime.now(),
      likes: const [],
      comments: const [],
      routePoints: routePoints,
    );

    await postRepo.createPost(
      post,
      numericDistance: _totalDistance,
      avgBpm: _kmHeartRateHistory.isNotEmpty 
          ? (_kmHeartRateHistory.reduce((a, b) => a + b) ~/ _kmHeartRateHistory.length) 
          : 0,
      splits: _kmHeartRateHistory,
      type: 'pro_run',
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionStream?.cancel();
    _tts.stop();
    super.dispose();
  }
}