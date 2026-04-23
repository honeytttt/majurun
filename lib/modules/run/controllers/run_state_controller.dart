import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:majurun/core/services/background_location_service.dart';

enum RunState { idle, running, paused, autoPaused }

class ChartDataSpot {
  final double x;
  final double y;
  const ChartDataSpot(this.x, this.y);
}

class KmSplit {
  final int kmNumber;
  final int durationSeconds;
  final String pace;
  final double elevationChange;

  KmSplit({
    required this.kmNumber,
    required this.durationSeconds,
    required this.pace,
    this.elevationChange = 0,
  });
}

/// Production-grade run state controller with:
/// - Background location tracking
/// - GPS accuracy filtering
/// - Auto-pause when stationary
/// - Proper timer management (stops when paused)
/// - Memory-efficient route handling
/// - Full error handling
class RunStateController extends ChangeNotifier {
  // Services
  final BackgroundLocationService _locationService = BackgroundLocationService();

  // State
  RunState _state = RunState.idle;
  RunState get state => _state;

  // Timer (only runs when actually running)
  Timer? _timer;
  int _secondsElapsed = 0;
  int _activeRunSeconds = 0; // Only counts time while actually moving

  // Distance & Position
  double _totalDistance = 0.0;
  FilteredPosition? _currentPosition;

  LatLng? get currentLatLng => _currentPosition?.latLng;
  String get distanceString => (_totalDistance / 1000).toStringAsFixed(2);
  double get totalDistance => _totalDistance;
  int get secondsElapsed => _secondsElapsed;
  int get activeRunSeconds => _activeRunSeconds; // moving time only (excludes paused time)

  // Pace calculation
  double get averageSpeedMs => _activeRunSeconds > 0 ? _totalDistance / _activeRunSeconds : 0.0;
  String get paceString {
    if (averageSpeedMs < 0.5) return "0:00";
    final paceMinKm = 16.666666 / averageSpeedMs;
    final minutes = paceMinKm.floor();
    final seconds = ((paceMinKm - minutes) * 60).round();
    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }

  // Current pace (last 30 seconds)
  double _recentDistance = 0;
  double _recentStartDistance = 0.0; // total distance at start of current 30s window
  int _recentSeconds = 0;
  String get currentPaceString {
    if (_recentSeconds < 5 || _recentDistance < 10) return paceString;
    final recentSpeedMs = _recentDistance / _recentSeconds;
    if (recentSpeedMs < 0.5) return paceString;
    final paceMinKm = 16.666666 / recentSpeedMs;
    final minutes = paceMinKm.floor();
    final seconds = ((paceMinKm - minutes) * 60).round();
    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }

  // Duration string
  String get durationString {
    final hours = _secondsElapsed ~/ 3600;
    final mins = (_secondsElapsed % 3600) ~/ 60;
    final secs = _secondsElapsed % 60;
    if (hours > 0) {
      return "${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
    }
    return "${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }

  // Route points (memory-managed by location service)
  List<LatLng> get routePoints => _locationService.getRouteLatLngs();

  // Polylines for map (single polyline, properly managed)
  Set<Polyline> _polylines = {};
  Set<Polyline> get polylines => _polylines;

  // Performance charts
  final List<ChartDataSpot> hrHistorySpots = [];
  final List<ChartDataSpot> paceHistorySpots = [];

import 'package:majurun/core/services/weather_service.dart';

// ... (other imports)

  // Stats
  String? lastVideoUrl;
  WeatherData? _startWeather;
  WeatherData? get startWeather => _startWeather;

  void setStartWeather(WeatherData weather) {
    _startWeather = weather;
    notifyListeners();
  }

  int currentBpm = 0; // Will be updated from health service
  int totalCalories = 0;
  double _lastCaloriesDistance = 0.0; // tracks distance at last calorie update
  double _calorieAccumulator = 0.0;   // fractional calories — committed as whole numbers
  GpsQuality _gpsQuality = GpsQuality.good;
  GpsQuality get gpsQuality => _gpsQuality;

  // Km splits
  int _lastAnnouncedKm = 0;
  double _lastAnnouncedHalfKm = 0.0;
  final List<KmSplit> _kmSplits = [];
  List<KmSplit> get kmSplits => List.unmodifiable(_kmSplits);
  int _lastKmTime = 0;

  // Idle detection
  int _idleSeconds = 0;
  static const int _idleThresholdSeconds = 600; // 10 minutes
  bool _hasNotifiedIdle = false;

  // Callbacks
  VoidCallback? onGpsSilent; // GPS stopped updating for 30s — show warning in UI
  VoidCallback? onIdleDetected;
  Function({
    required int km,
    required String totalTime,
    required String lastKmPace,
    required String averagePace,
    String? comparison,
  })? onKmMilestone;
  Function({
    required double distanceKm,
    required String currentPace,
  })? onHalfKmMilestone;
  Function(String error)? onError;
  Function(bool isAutoPaused)? onAutoPauseChanged;

  // Error state
  String? _lastError;
  String? get lastError => _lastError;

  RunStateController() {
    _setupLocationCallbacks();
  }

  void _setupLocationCallbacks() {
    _locationService.onPositionUpdate = (position, distance) {
      _currentPosition = position;
      _totalDistance = distance;
      _updatePolylines();
      notifyListeners();
    };

    _locationService.onAutoPauseChanged = (isAutoPaused) {
      if (isAutoPaused && _state == RunState.running) {
        _state = RunState.autoPaused;
        _stopTimer();
        onAutoPauseChanged?.call(true);
        notifyListeners();
      } else if (!isAutoPaused && _state == RunState.autoPaused) {
        _state = RunState.running;
        _startTimer();
        onAutoPauseChanged?.call(false);
        notifyListeners();
      }
    };

    _locationService.onError = (error) {
      _lastError = error;
      onError?.call(error);
      debugPrint('❌ Location error: $error');
    };

    _locationService.onGpsSilent = () {
      debugPrint('⚠️ GPS silent — notifying UI');
      onGpsSilent?.call();
    };

    _locationService.onGpsQualityChanged = (quality) {
      _gpsQuality = quality;
      notifyListeners();
    };
  }

  /// Start a new run
  /// Starts GPS early (during warmup) so iOS keeps the app alive in background.
  /// Does NOT start the timer or change run state.
  Future<void> prewarmGps() async {
    if (_locationService.isTracking) return;
    debugPrint('📡 Pre-warming GPS before warmup dialog...');
    await _locationService.startTracking();
  }

  Future<void> startRun() async {
    if (_state == RunState.running || _state == RunState.paused) {
      debugPrint('⚠️ Run already active');
      return;
    }

    debugPrint('🏃 Starting run...');
    _lastError = null;

    // Reset all state
    _secondsElapsed = 0;
    _activeRunSeconds = 0;
    _totalDistance = 0.0;
    _recentDistance = 0;
    _recentStartDistance = 0.0;
    _recentSeconds = 0;
    _polylines.clear();
    hrHistorySpots.clear();
    paceHistorySpots.clear();
    lastVideoUrl = null;
    totalCalories = 0;
    _lastCaloriesDistance = 0.0;
    _calorieAccumulator = 0.0;
    _lastAnnouncedKm = 0;
    _lastAnnouncedHalfKm = 0.0;
    _kmSplits.clear();
    _lastKmTime = 0;
    _idleSeconds = 0;
    _hasNotifiedIdle = false;
    _currentPosition = null;

    // Start location tracking — skip if already started by prewarmGps()
    if (!_locationService.isTracking) {
      final success = await _locationService.startTracking();
      if (!success) {
        _lastError = 'Failed to start GPS tracking';
        throw Exception(_lastError);
      }
    } else {
      debugPrint('📡 GPS already tracking from prewarm — skipping startTracking()');
    }

    // Set state and start timer
    _state = RunState.running;
    _startTimer();
    notifyListeners();

    debugPrint('✅ Run started successfully');
  }

  /// Pause the run (manual pause)
  void pauseRun() {
    if (_state != RunState.running && _state != RunState.autoPaused) {
      debugPrint('⚠️ Cannot pause - not running');
      return;
    }

    debugPrint('⏸️ Pausing run...');
    _state = RunState.paused;
    _stopTimer();
    _locationService.pause();
    notifyListeners();
  }

  /// Resume the run
  void resumeRun() {
    if (_state != RunState.paused && _state != RunState.autoPaused) {
      debugPrint('⚠️ Cannot resume - not paused');
      return;
    }

    debugPrint('▶️ Resuming run...');
    _state = RunState.running;
    _startTimer();
    _locationService.resume();
    notifyListeners();
  }

  /// Stop the run
  Future<void> stopRun() async {
    if (_state == RunState.idle) {
      debugPrint('⚠️ No run to stop');
      return;
    }

    debugPrint('⏹️ Stopping run...');
    _state = RunState.idle;
    _stopTimer();
    await _locationService.stopTracking();

    // Log final stats
    final stats = _locationService.getRouteStats();
    debugPrint('📊 Final run stats:');
    debugPrint('   Distance: ${(_totalDistance / 1000).toStringAsFixed(2)} km');
    debugPrint('   Duration: $durationString');
    debugPrint('   Avg Pace: $paceString');
    debugPrint('   Calories: $totalCalories');
    debugPrint('   GPS Points: ${stats['pointCount']}');
    debugPrint('   GPS Acceptance Rate: ${_locationService.gpsAcceptanceRate.toStringAsFixed(1)}%');

    notifyListeners();
  }

  /// Reset run data (call after saving)
  void resetRun() {
    debugPrint('🔄 Resetting run data');
    _secondsElapsed = 0;
    _activeRunSeconds = 0;
    _totalDistance = 0.0;
    _recentDistance = 0;
    _recentStartDistance = 0.0;
    _recentSeconds = 0;
    _polylines.clear();
    hrHistorySpots.clear();
    paceHistorySpots.clear();
    lastVideoUrl = null;
    totalCalories = 0;
    _lastCaloriesDistance = 0.0;
    _calorieAccumulator = 0.0;
    _lastAnnouncedKm = 0;
    _lastAnnouncedHalfKm = 0.0;
    _kmSplits.clear();
    _lastKmTime = 0;
    _idleSeconds = 0;
    _hasNotifiedIdle = false;
    _currentPosition = null;
    _lastError = null;
    notifyListeners();
  }

  // ============== TIMER MANAGEMENT ==============

  void _startTimer() {
    _timer?.cancel();
    debugPrint('⏱️ Timer started');
    _timer = Timer.periodic(const Duration(seconds: 1), _onTimerTick);
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    debugPrint('⏱️ Timer stopped at $_secondsElapsed seconds');
  }

  void _onTimerTick(Timer timer) {
    if (_state != RunState.running) return;

    _secondsElapsed++;
    _activeRunSeconds++;
    _recentSeconds++;

    // Update recent distance for current pace calculation.
    // Track distance covered since the start of the current 30s window.
    if (_recentSeconds >= 30) {
      _recentStartDistance = _totalDistance;
      _recentSeconds = 0;
    }
    _recentDistance = _totalDistance - _recentStartDistance;

    // Check milestones
    _checkMilestones();

    // Accumulate calories incrementally so the count never goes backwards.
    // Formula: ~1.05 kcal/kg/km for running (MET-based), default 80 kg.
    // Use a fractional accumulator — DO NOT round per-tick or tiny GPS deltas
    // round to 0 and all calories are lost (e.g. 0.0025 km × 85 = 0.21 → rounds to 0).
    final distanceDeltaKm = (_totalDistance - _lastCaloriesDistance) / 1000;
    if (distanceDeltaKm > 0) {
      final caloriesPerKm = averageSpeedMs > 3.5 ? 95 : averageSpeedMs > 2.5 ? 85 : 75;
      _calorieAccumulator += distanceDeltaKm * caloriesPerKm;
      final earned = _calorieAccumulator.floor();
      if (earned > 0) {
        totalCalories += earned;
        _calorieAccumulator -= earned;
      }
      _lastCaloriesDistance = _totalDistance;
    }

    // Record performance snapshot every 10 seconds
    if (_secondsElapsed % 10 == 0) {
      _recordPerformanceSnapshot();
    }

    // Check for idle (no GPS updates for 10 minutes while "running")
    _checkIdleStatus();

    notifyListeners();
  }

  // ============== MILESTONE CHECKING ==============

  void _checkMilestones() {
    final distanceKm = _totalDistance / 1000;

    // Full kilometer milestones
    final currentKm = distanceKm.floor();
    if (currentKm > _lastAnnouncedKm && currentKm > 0) {
      _handleKmMilestone(currentKm);
      _lastAnnouncedKm = currentKm;
      return;
    }

    // Half kilometer milestones
    final roundedHalfKm = (distanceKm * 2).floor() / 2.0;
    if (roundedHalfKm > _lastAnnouncedHalfKm &&
        (roundedHalfKm % 1.0 == 0.5) &&
        distanceKm >= roundedHalfKm - 0.05 &&
        distanceKm <= roundedHalfKm + 0.05) {
      debugPrint('🔔 Half-km milestone: ${roundedHalfKm.toStringAsFixed(1)}km');
      _handleHalfKmMilestone(roundedHalfKm);
      _lastAnnouncedHalfKm = roundedHalfKm;
    }
  }

  void _handleKmMilestone(int km) {
    debugPrint('🎯 Milestone: ${km}km completed!');

    // Calculate this km split
    final thisKmTime = _secondsElapsed - _lastKmTime;

    // Pace for this km
    final paceMinutes = thisKmTime / 60.0;
    final paceMin = paceMinutes.floor();
    final paceSec = ((paceMinutes - paceMin) * 60).round();
    final lastKmPaceString = "$paceMin:${paceSec.toString().padLeft(2, '0')}";

    // Store split
    _kmSplits.add(KmSplit(
      kmNumber: km,
      durationSeconds: thisKmTime,
      pace: lastKmPaceString,
    ));

    // Compare with previous km — only if a consecutive previous split exists
    String? comparison;
    final hasPreviousSplit = _kmSplits.length >= 2 &&
        _kmSplits[_kmSplits.length - 2].kmNumber == km - 1;
    if (hasPreviousSplit) {
      final previousKm = _kmSplits[_kmSplits.length - 2];
      final timeDiff = thisKmTime - previousKm.durationSeconds;

      if (timeDiff.abs() < 5) {
        comparison = "Same pace as previous kilometer";
      } else if (timeDiff < 0) {
        comparison = "Faster by ${timeDiff.abs()} seconds. Great job!";
      } else {
        comparison = "Slower by $timeDiff seconds. Keep pushing!";
      }
    }

    // Trigger callback
    onKmMilestone?.call(
      km: km,
      totalTime: durationString,
      lastKmPace: lastKmPaceString,
      averagePace: paceString,
      comparison: comparison,
    );

    _lastKmTime = _secondsElapsed;
  }

  void _handleHalfKmMilestone(double distanceKm) {
    onHalfKmMilestone?.call(
      distanceKm: distanceKm,
      currentPace: currentPaceString,
    );
  }

  // ============== PERFORMANCE TRACKING ==============

  void _recordPerformanceSnapshot() {
    final x = _secondsElapsed / 60.0;
    hrHistorySpots.add(ChartDataSpot(x, currentBpm.toDouble()));

    final paceValue = averageSpeedMs > 0 ? 16.666666 / averageSpeedMs : 0.0;
    paceHistorySpots.add(ChartDataSpot(x, paceValue));

    // Limit history size for memory
    if (hrHistorySpots.length > 360) {
      hrHistorySpots.removeAt(0);
      paceHistorySpots.removeAt(0);
    }
  }

  // ============== IDLE DETECTION ==============

  void _checkIdleStatus() {
    // Check if no new GPS data for extended period
    final lastPosition = _locationService.lastPosition;
    if (lastPosition == null) return;

    final timeSinceLastUpdate = DateTime.now().difference(lastPosition.timestamp).inSeconds;
    if (timeSinceLastUpdate > 60) {
      _idleSeconds++;
    } else {
      _idleSeconds = 0;
      _hasNotifiedIdle = false;
    }

    if (_idleSeconds >= _idleThresholdSeconds && !_hasNotifiedIdle) {
      _hasNotifiedIdle = true;
      debugPrint('⏰ Idle detected - no movement for 10+ minutes');
      onIdleDetected?.call();
    }
  }

  // ============== POLYLINE MANAGEMENT ==============

  void _updatePolylines() {
    final points = routePoints;
    if (points.isEmpty) return;

    // Create single polyline with gradient effect
    _polylines = {
      Polyline(
        polylineId: const PolylineId('run_route'),
        points: points,
        color: Colors.blue,
        width: 5,
        patterns: const [],
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };
  }

  // ============== GPS QUALITY INDICATOR ==============

  String get gpsQualityText {
    switch (_gpsQuality) {
      case GpsQuality.excellent:
        return 'Excellent GPS';
      case GpsQuality.good:
        return 'Good GPS';
      case GpsQuality.fair:
        return 'Fair GPS';
      case GpsQuality.poor:
        return 'Poor GPS';
      case GpsQuality.unusable:
        return 'No GPS Signal';
    }
  }

  Color get gpsQualityColor {
    switch (_gpsQuality) {
      case GpsQuality.excellent:
        return Colors.green;
      case GpsQuality.good:
        return Colors.lightGreen;
      case GpsQuality.fair:
        return Colors.orange;
      case GpsQuality.poor:
        return Colors.deepOrange;
      case GpsQuality.unusable:
        return Colors.red;
    }
  }

  // ============== ROUTE STATS ==============

  Map<String, dynamic> getRouteStats() => _locationService.getRouteStats();

  double get gpsAcceptanceRate => _locationService.gpsAcceptanceRate;

  @override
  void dispose() {
    debugPrint('🗑️ Disposing RunStateController');
    _timer?.cancel();
    _locationService.dispose();
    super.dispose();
  }
}
