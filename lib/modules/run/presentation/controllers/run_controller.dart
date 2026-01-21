import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/run_activity.dart';
import '../../../home/data/repositories/post_repository_impl.dart';
import '../../../home/domain/entities/post.dart';

class PathPoint {
  final LatLng point;
  final double speed;
  PathPoint(this.point, this.speed);
}

class RunController extends ChangeNotifier {
  RunState _state = RunState.idle;
  RunState get state => _state;

  final List<PathPoint> _detailedPath = [];
  double _totalDistance = 0.0;
  Duration _elapsedTime = Duration.zero;
  LatLng? _currentLocation;
  bool _isAutoPaused = false;

  double _historyDistance = 0.0;
  double _averageSpeedMs = 0.0;
  double _ghostDistance = 0.0;
  int _currentBpm = 70;
  double _allTimeBest = 0.0;
  bool _isNewPB = false;
  int _runStreak = 0;
  bool _shieldActive = false;
  final Duration _totalHistoryTime = Duration.zero;

  String _shoeName = "Primary Trainers";
  double _shoeMileage = 0.0;
  double? _temp;
  String? _weatherIcon;
  bool _isWeatherLoading = false;

  final bool _isAudioCoachingEnabled = true;
  int _lastAnnouncedKm = 0;

  final FlutterTts _tts = FlutterTts();
  final postRepo = PostRepositoryImpl();
  Timer? _timer;
  StreamSubscription<Position>? _positionStream;

  // Getters for UI
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
  double get shoeProgress => (_shoeMileage / 500).clamp(0.0, 1.0);
  String get shoeName => _shoeName;
  
  String get totalHistoryTimeStr {
    int hours = _totalHistoryTime.inHours;
    int minutes = _totalHistoryTime.inMinutes.remainder(60);
    return "${hours}H:${minutes}M";
  }

  RunController() {
    _initTts();
    _loadAllTimeData();
    _fetchInitialLocation();
  }

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
        if (p.content.contains("Distance")) {
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

  void startRun() {
    _state = RunState.running;
    _detailedPath.clear();
    _totalDistance = 0;
    _elapsedTime = Duration.zero;
    _lastAnnouncedKm = 0;
    _isNewPB = false;
    
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

  void _onLocationUpdate(Position pos) {
    if (_state != RunState.running) return;

    // Auto-pause logic implementation
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

      // Check for New Personal Best
      if (_totalDistance > _allTimeBest && _allTimeBest > 0 && !_isNewPB) {
        _isNewPB = true;
        if (_isAudioCoachingEnabled) _tts.speak("New personal best distance!");
      }

      // Audio Coaching for split kilometers
      int currentKm = _totalDistance.floor();
      if (currentKm > _lastAnnouncedKm) {
        _lastAnnouncedKm = currentKm;
        if (_isAudioCoachingEnabled) _tts.speak("$currentKm kilometers completed.");
      }
      
      notifyListeners();
    }
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

  Future<Map<String, dynamic>?> checkMonthlySummary() async { return null; }
  void shareSummaryToFeed(Map<String, dynamic> summary) {}

  void stopRun(BuildContext context) async {
    _state = RunState.finished;
    _timer?.cancel();
    _positionStream?.cancel();
    
    final prefs = await SharedPreferences.getInstance();
    _shoeMileage += _totalDistance;
    await prefs.setDouble('shoe_mileage', _shoeMileage);
    
    if (_totalDistance > _allTimeBest) {
      await prefs.setDouble('all_time_best_dist', _totalDistance);
    }

    if (context.mounted) _finalizePost(context);
  }

  Future<void> _finalizePost(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final post = AppPost(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: user.uid,
      username: user.displayName ?? "Runner",
      content: "🏃 Distance: $distanceString km",
      createdAt: DateTime.now(),
    );
    await postRepo.createPost(post);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }
}