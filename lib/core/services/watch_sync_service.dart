import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:majurun/modules/run/controllers/stats_controller.dart';

/// Watch Sync Service - Sync data between phone and smartwatch
/// Supports Apple Watch (WatchOS) and Wear OS
class WatchSyncService extends ChangeNotifier {
  static final WatchSyncService _instance = WatchSyncService._internal();
  factory WatchSyncService() => _instance;
  WatchSyncService._internal();

  static const MethodChannel _channel = MethodChannel('com.majurun.app/watch');
  static const EventChannel _eventChannel = EventChannel('com.majurun.app/watch_events');

  bool _isWatchConnected = false;
  bool _isWatchAppInstalled = false;
  WatchPlatform? _watchPlatform;
  StreamSubscription? _eventSubscription;

  // Current run state to sync
  RunSyncData? _currentRunData;

  /// True while the watch has an active standalone run in progress.
  bool _watchRunActive = false;

  /// Injected by the app shell so that watch-originated runs are saved through
  /// the same StatsController instance that drives the UI, ensuring the run
  /// history list refreshes without a full reload.
  /// Set via [setStatsController] immediately after initialization.
  StatsController? _statsController;

  /// Called when a standalone watch run is received and saved.
  /// UI can set this to show a snackbar / navigate to the run.
  void Function(WatchCompletedRun)? onWatchRunReceived;

  bool get isWatchConnected => _isWatchConnected;
  bool get isWatchAppInstalled => _isWatchAppInstalled;
  WatchPlatform? get watchPlatform => _watchPlatform;
  RunSyncData? get currentRunData => _currentRunData;

  /// Whether the watch has an active standalone run in progress.
  bool get watchRunActive => _watchRunActive;

  /// Call this once from the app shell (after providers are ready) to inject
  /// the shared [StatsController] so watch runs trigger a UI refresh.
  void setStatsController(StatsController controller) {
    _statsController = controller;
  }

  /// Initialize watch connection
  Future<void> initialize() async {
    try {
      // Check if watch is connected
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('checkWatchStatus');
      if (result != null) {
        _isWatchConnected = result['connected'] as bool? ?? false;
        _isWatchAppInstalled = result['appInstalled'] as bool? ?? false;
        final platform = result['platform'] as String?;
        _watchPlatform = platform == 'watchos'
            ? WatchPlatform.appleWatch
            : platform == 'wearos'
                ? WatchPlatform.wearOS
                : null;
      }

      // Listen for watch events — cancel any prior subscription first so a
      // second initialize() call (e.g. hot restart in dev) doesn't double-fire.
      await _eventSubscription?.cancel();
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        _handleWatchEvent,
        onError: (error) => debugPrint('Watch event error: $error'),
      );

      notifyListeners();
    } catch (e) {
      debugPrint('Watch initialization error: $e');
    }
  }

  void _handleWatchEvent(dynamic event) {
    if (event is Map) {
      final eventType = event['type'] as String?;

      switch (eventType) {
        case 'connection_changed':
          _isWatchConnected = event['connected'] as bool? ?? false;
          notifyListeners();
          break;
        case 'run_started':
          // Watch started a run - sync to phone
          _onWatchRunStarted();
          break;
        case 'run_paused':
          _onWatchRunPaused();
          break;
        case 'run_resumed':
          _onWatchRunResumed();
          break;
        case 'run_stopped':
          _onWatchRunStopped(event);
          break;
        case 'heart_rate_update':
          _onHeartRateUpdate(event['heartRate'] as int?);
          break;
        case 'watch_run_completed':
          _onWatchRunCompleted(event);
          break;
      }
    }
  }

  /// Start run on watch
  Future<bool> startRunOnWatch() async {
    if (!_isWatchConnected) return false;

    try {
      final result = await _channel.invokeMethod<bool>('startRun');
      return result ?? false;
    } catch (e) {
      debugPrint('Error starting run on watch: $e');
      return false;
    }
  }

  /// Stop run on watch
  Future<bool> stopRunOnWatch() async {
    if (!_isWatchConnected) return false;

    try {
      final result = await _channel.invokeMethod<bool>('stopRun');
      return result ?? false;
    } catch (e) {
      debugPrint('Error stopping run on watch: $e');
      return false;
    }
  }

  /// Sync run data to watch
  Future<void> syncRunData(RunSyncData data) async {
    if (!_isWatchConnected) return;

    _currentRunData = data;

    try {
      await _channel.invokeMethod('syncRunData', {
        'distance': data.distanceMeters,
        'duration': data.durationSeconds,
        'pace': data.currentPaceSecondsPerKm,
        'heartRate': data.heartRate,
        'calories': data.calories,
        'isRunning': data.isRunning,
        'isPaused': data.isPaused,
      });
    } catch (e) {
      debugPrint('Error syncing run data to watch: $e');
    }
  }

  /// Sync workout to watch for standalone use
  Future<bool> syncWorkoutToWatch(WatchWorkout workout) async {
    if (!_isWatchConnected || !_isWatchAppInstalled) return false;

    try {
      final result = await _channel.invokeMethod<bool>('syncWorkout', {
        'id': workout.id,
        'name': workout.name,
        'type': workout.type.name,
        'targetDistance': workout.targetDistanceMeters,
        'targetDuration': workout.targetDurationSeconds,
        'intervals': workout.intervals?.map((i) => {
          'type': i.type,
          'duration': i.durationSeconds,
          'instruction': i.instruction,
        }).toList(),
      });
      return result ?? false;
    } catch (e) {
      debugPrint('Error syncing workout to watch: $e');
      return false;
    }
  }

  /// Get heart rate from watch
  Future<int?> getCurrentHeartRate() async {
    if (!_isWatchConnected) return null;

    try {
      final result = await _channel.invokeMethod<int>('getHeartRate');
      return result;
    } catch (e) {
      debugPrint('Error getting heart rate: $e');
      return null;
    }
  }

  /// Request permissions on watch
  Future<bool> requestWatchPermissions() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestPermissions');
      return result ?? false;
    } catch (e) {
      debugPrint('Error requesting watch permissions: $e');
      return false;
    }
  }

  /// Open companion app on watch
  Future<void> openWatchApp() async {
    try {
      await _channel.invokeMethod('openWatchApp');
    } catch (e) {
      debugPrint('Error opening watch app: $e');
    }
  }

  // Event handlers for watch-initiated events
  void _onWatchRunStarted() {
    debugPrint('Run started from watch');
    _watchRunActive = true;
    notifyListeners();
  }

  void _onWatchRunPaused() {
    debugPrint('Run paused from watch');
  }

  void _onWatchRunResumed() {
    debugPrint('Run resumed from watch');
  }

  void _onWatchRunStopped(Map<dynamic, dynamic> event) {
    debugPrint('Run stopped from watch');
    _watchRunActive = false;
    notifyListeners();
  }

  void _onHeartRateUpdate(int? heartRate) {
    if (heartRate != null) {
      debugPrint('Heart rate update: $heartRate bpm');
    }
  }

  Future<void> _onWatchRunCompleted(Map<dynamic, dynamic> event) async {
    final durationSeconds = event['durationSeconds'] as int? ?? 0;
    final distanceMeters = (event['distanceMeters'] as num?)?.toDouble() ?? 0.0;
    final avgHeartRate = event['avgHeartRate'] as int?;
    final caloriesVal = event['calories'] as int?;

    if (durationSeconds <= 0 || distanceMeters <= 0) {
      debugPrint('Watch run ignored: insufficient data');
      return;
    }

    final distanceKm = distanceMeters / 1000.0;
    final paceSecsPerKm = durationSeconds / distanceKm;
    final paceMin = paceSecsPerKm ~/ 60;
    final paceSec = paceSecsPerKm.toInt() % 60;
    final paceString = '$paceMin:${paceSec.toString().padLeft(2, '0')} /km';

    // Convert route [[lat,lon],...] to LatLng list
    List<LatLng>? routePoints;
    final rawRoute = event['route'];
    if (rawRoute is List && rawRoute.isNotEmpty) {
      routePoints = rawRoute.whereType<List>().map((pt) {
        final lat = (pt[0] as num).toDouble();
        final lon = (pt[1] as num).toDouble();
        return LatLng(lat, lon);
      }).toList();
    }

    final run = WatchCompletedRun(
      distanceKm: distanceKm,
      durationSeconds: durationSeconds,
      pace: paceString,
      avgHeartRate: avgHeartRate,
      calories: caloriesVal,
      routePoints: routePoints,
    );

    try {
      // Use the injected shared instance so the run history UI refreshes;
      // fall back to a local instance only if injection hasn't happened yet.
      final controller = _statsController ?? StatsController();
      await controller.saveRunHistory(
        planTitle: 'Watch Run',
        distanceKm: distanceKm,
        durationSeconds: durationSeconds,
        pace: paceString,
        routePoints: routePoints,
        avgBpm: avgHeartRate,
        calories: caloriesVal,
        extra: {'source': 'apple_watch'},
      );
      debugPrint('✅ Watch run saved: ${distanceKm.toStringAsFixed(2)} km');
      _watchRunActive = false;
      notifyListeners();
      onWatchRunReceived?.call(run);
    } catch (e) {
      debugPrint('❌ Failed to save watch run: $e');
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}

// Data classes

enum WatchPlatform {
  appleWatch,
  wearOS,
}

extension WatchPlatformExtension on WatchPlatform {
  String get name {
    switch (this) {
      case WatchPlatform.appleWatch:
        return 'Apple Watch';
      case WatchPlatform.wearOS:
        return 'Wear OS';
    }
  }

  String get icon {
    switch (this) {
      case WatchPlatform.appleWatch:
        return 'watch';
      case WatchPlatform.wearOS:
        return 'watch';
    }
  }
}

class RunSyncData {
  final double distanceMeters;
  final int durationSeconds;
  final double currentPaceSecondsPerKm;
  final int? heartRate;
  final int calories;
  final bool isRunning;
  final bool isPaused;

  const RunSyncData({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.currentPaceSecondsPerKm,
    this.heartRate,
    required this.calories,
    required this.isRunning,
    required this.isPaused,
  });
}

enum WatchWorkoutType {
  freeRun,
  distanceGoal,
  timeGoal,
  intervalTraining,
}

class WatchWorkout {
  final String id;
  final String name;
  final WatchWorkoutType type;
  final double? targetDistanceMeters;
  final int? targetDurationSeconds;
  final List<WatchInterval>? intervals;

  const WatchWorkout({
    required this.id,
    required this.name,
    required this.type,
    this.targetDistanceMeters,
    this.targetDurationSeconds,
    this.intervals,
  });
}

class WatchInterval {
  final String type;
  final int durationSeconds;
  final String instruction;

  const WatchInterval({
    required this.type,
    required this.durationSeconds,
    required this.instruction,
  });
}

/// Data for a run recorded entirely on the Apple Watch (no phone).
class WatchCompletedRun {
  final double distanceKm;
  final int durationSeconds;
  final String pace;
  final int? avgHeartRate;
  final int? calories;
  final List<LatLng>? routePoints;

  const WatchCompletedRun({
    required this.distanceKm,
    required this.durationSeconds,
    required this.pace,
    this.avgHeartRate,
    this.calories,
    this.routePoints,
  });
}
