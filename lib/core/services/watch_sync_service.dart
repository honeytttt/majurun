import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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

  bool get isWatchConnected => _isWatchConnected;
  bool get isWatchAppInstalled => _isWatchAppInstalled;
  WatchPlatform? get watchPlatform => _watchPlatform;
  RunSyncData? get currentRunData => _currentRunData;

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

      // Listen for watch events
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
    // Notify the app to sync state
  }

  void _onWatchRunPaused() {
    debugPrint('Run paused from watch');
  }

  void _onWatchRunResumed() {
    debugPrint('Run resumed from watch');
  }

  void _onWatchRunStopped(Map<dynamic, dynamic> event) {
    debugPrint('Run stopped from watch');
    // Get final run data from watch
    final distance = event['distance'] as double?;
    final duration = event['duration'] as int?;
    debugPrint('Watch run: ${distance}m in ${duration}s');
  }

  void _onHeartRateUpdate(int? heartRate) {
    if (heartRate != null) {
      // Could trigger a callback or notifyListeners
      debugPrint('Heart rate update: $heartRate bpm');
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
