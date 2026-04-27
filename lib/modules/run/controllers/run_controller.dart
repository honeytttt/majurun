import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:majurun/core/services/interval_training_service.dart';
import 'package:majurun/core/services/offline_database_service.dart';
import 'package:majurun/core/services/run_recovery_service.dart';
import 'package:majurun/core/services/streak_service.dart';
import 'package:majurun/core/services/wake_lock_service.dart';
import 'package:majurun/core/services/weather_service.dart';
import 'package:majurun/core/services/service_locator.dart';
import 'package:majurun/modules/run/controllers/post_controller.dart';

import 'package:majurun/modules/run/controllers/run_state_controller.dart';
import 'package:majurun/modules/run/controllers/stats_controller.dart';
import 'package:majurun/modules/run/controllers/voice_controller.dart';

/// Callback type for UI notifications - avoids storing BuildContext in controller
typedef ShowSnackBarCallback = void Function(SnackBar snackBar);

/// Production-grade run controller with full error handling,
/// background tracking support, and auto-pause functionality.
class RunController extends ChangeNotifier {
  final RunStateController stateController = RunStateController();
  final VoiceController voiceController = VoiceController();
  final PostController postController = PostController();
  final StatsController statsController = StatsController();

  // Use singleton services from ServiceLocator - NOT new instances
  final _analytics = serviceLocator.analyticsService;
  final _crashReporting = serviceLocator.crashReportingService;

  // Recovery properties
  Timer? _autoSaveTimer;
  bool _hasShownRecoveryDialog = false;

  // UI notification callbacks - avoids storing BuildContext
  ShowSnackBarCallback? _showSnackBar;
  VoidCallback? _onStopRun;

  // Prevent spamming UI with repeated milestone SnackBars
  int _lastMilestoneSnackKm = 0;

  // Error handling
  String? _lastError;
  String? get lastError => _lastError;

  // Last run achievements — read by UI to show congratulations screen
  List<String> lastRunPbs = [];
  List<String> lastRunBadges = [];
  List<Map<String, dynamic>> lastRunKmSplits = [];

  RunController() {
    _setupCallbacks();
  }

  void _setupCallbacks() {
    // Listen to state controller changes
    stateController.addListener(_onStateControllerChanged);

    // Idle detection callback
    stateController.onIdleDetected = _handleIdleDetected;

    // Auto-pause callback
    stateController.onAutoPauseChanged = (isAutoPaused) {
      if (isAutoPaused) {
        voiceController.speakTraining("Run auto-paused. Start moving to continue.");
        _showAutoPauseSnackBar();
      } else {
        voiceController.speakTraining("Run resumed.");
      }
      notifyListeners();
    };

    // GPS error callback
    stateController.onError = (error) {
      _lastError = error;
      _crashReporting.recordLocationError(errorType: 'gps_error', errorMessage: error);
      _showErrorSnackBar(error);
    };

    // GPS silent failure — stream stopped delivering updates for 30s
    stateController.onGpsSilent = () {
      _crashReporting.recordLocationError(
        errorType: 'gps_silent_failure',
        errorMessage: 'No GPS update for 30s — stream restarted',
      );
      _showErrorSnackBar('GPS signal lost — reconnecting...');
    };

    // Km milestone callback
    stateController.onKmMilestone = ({
      required int km,
      required String totalTime,
      required String lastKmPace,
      required String averagePace,
      String? comparison,
    }) {
      // iOS WebKit workaround: use tap-to-speak on Safari
      if (_shouldUseTapToSpeakForMilestone()) {
        _showMilestoneSnackBar(
          km: km,
          totalTime: totalTime,
          lastKmPace: lastKmPace,
          averagePace: averagePace,
          comparison: comparison,
        );
        return;
      }

      // Check if this km is an approaching-milestone trigger (4, 8, 9, 19, 20, 40, 41)
      // before the per-km announcement so the approaching phrase plays first.
      voiceController.checkApproachingMilestone(km.toDouble());

      // Default behavior: speak immediately
      voiceController.speakKmMilestone(
        km: km,
        totalTime: totalTime,
        lastKmPace: lastKmPace,
        averagePace: averagePace,
        comparison: comparison,
      );
    };

    // Half-km milestone callback — also check approaching milestones here
    stateController.onHalfKmMilestone = ({
      required double distanceKm,
      required String currentPace,
    }) {
      voiceController.checkApproachingMilestone(distanceKm);
      voiceController.speakHalfKmMilestone(
        distanceKm: distanceKm,
        currentPace: currentPace,
      );
    };
  }

  void _onStateControllerChanged() {
    notifyListeners();
  }

  // ============== GETTERS ==============

  RunState get state => stateController.state;
  bool get isAutoPaused => stateController.state == RunState.autoPaused;

  String get distanceString => stateController.distanceString;
  String get durationString => stateController.durationString;
  String get paceString => stateController.paceString;
  String get currentPaceString => stateController.currentPaceString;

  int get currentBpm => stateController.currentBpm;
  int get totalCalories => stateController.totalCalories;
  double get totalDistance => stateController.totalDistance;
  int get secondsElapsed => stateController.secondsElapsed;

  List<LatLng> get routePoints => stateController.routePoints;
  List<ChartDataSpot> get hrHistorySpots => stateController.hrHistorySpots;
  List<ChartDataSpot> get paceHistorySpots => stateController.paceHistorySpots;

  String? get lastVideoUrl => stateController.lastVideoUrl;

  // GPS Quality
  String get gpsQualityText => stateController.gpsQualityText;
  Color get gpsQualityColor => stateController.gpsQualityColor;
  double get gpsAcceptanceRate => stateController.gpsAcceptanceRate;

  // History stats
  double get historyDistance => statsController.historyDistance;
  int get runStreak => statsController.runStreak;
  int get totalRuns => statsController.totalRuns;
  String get totalHistoryTimeStr => statsController.totalHistoryTimeStr;

  // Voice
  bool get isVoiceEnabled => voiceController.isVoiceEnabled;
  void toggleVoice() => voiceController.toggleVoice();

  // Video generation
  Future<void> generateVeoVideo() async => await postController.generateVeoVideo();

  Future<void> finalizeProPost(String aiContent, String videoUrl, {String? planTitle}) async {
    await postController.finalizeProPost(aiContent, videoUrl, planTitle: planTitle);
  }

  /// Set UI callbacks for notifications - preferred over storing BuildContext
  void setUICallbacks({
    ShowSnackBarCallback? showSnackBar,
    VoidCallback? onStopRun,
  }) {
    _showSnackBar = showSnackBar;
    _onStopRun = onStopRun;
  }

  /// Legacy method for backwards compatibility - extracts callbacks from context
  void setUiContext(BuildContext context) {
    _showSnackBar = (snackBar) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(snackBar);
      }
    };
  }

  // ============== IDLE & AUTO-PAUSE HANDLING ==============

  void _handleIdleDetected() {
    final callback = _showSnackBar;
    if (callback == null) {
      debugPrint("⚠️ No UI callback for idle notification");
      return;
    }

    callback(
      SnackBar(
        duration: const Duration(seconds: 30),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.orange[800],
        content: const Row(
          children: [
            Icon(Icons.timer_off, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "No movement for 10 minutes. Are you done?",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: "END RUN",
          textColor: Colors.white,
          onPressed: () => _onStopRun?.call(),
        ),
      ),
    );

    voiceController.speakTraining("No movement detected for 10 minutes. Tap end run if you're done.");
  }

  void _showAutoPauseSnackBar() {
    _showSnackBar?.call(
      SnackBar(
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.blue[700],
        content: const Row(
          children: [
            Icon(Icons.pause_circle, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Auto-paused: No movement detected",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: "RESUME",
          textColor: Colors.white,
          onPressed: resumeRun,
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    _showSnackBar?.call(
      SnackBar(
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red[700],
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                // Sanitize error message - don't expose stack traces to user
                message.split('\n').first,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============== iOS SAFARI WORKAROUND ==============

  bool _shouldUseTapToSpeakForMilestone() {
    if (!kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS;
  }

  void _showMilestoneSnackBar({
    required int km,
    required String totalTime,
    required String lastKmPace,
    required String averagePace,
    String? comparison,
  }) {
    if (!voiceController.isVoiceEnabled) return;
    if (km <= _lastMilestoneSnackKm) return;
    _lastMilestoneSnackKm = km;

    final callback = _showSnackBar;
    if (callback == null) {
      voiceController.speakKmMilestone(
        km: km,
        totalTime: totalTime,
        lastKmPace: lastKmPace,
        averagePace: averagePace,
        comparison: comparison,
      );
      return;
    }

    callback(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
        content: Text("${km}km reached - Tap PLAY to hear update"),
        action: SnackBarAction(
          label: "PLAY",
          onPressed: () {
            voiceController.speakKmMilestone(
              km: km,
              totalTime: totalTime,
              lastKmPace: lastKmPace,
              averagePace: averagePace,
              comparison: comparison,
            );
          },
        ),
      ),
    );
  }

  // ============== RECOVERY ==============

  Future<void> checkForRecoverableRun(BuildContext context) async {
    if (_hasShownRecoveryDialog) return;

    setUiContext(context);

    final recovery = await RunRecoveryService.getRecoverableRun();
    if (recovery == null) return;

    _hasShownRecoveryDialog = true;

    if (!context.mounted) return;

    final shouldRecover = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Continue Previous Run?'),
        content: Text(
          'You have an incomplete run from ${_formatDateTime(recovery['startTime'])}.\n\n'
          'Distance: ${(recovery['distance'] as double).toStringAsFixed(2)} km\n'
          'Duration: ${_formatDuration(recovery['durationSeconds'] as int)}\n\n'
          'Would you like to continue where you left off?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Start Fresh'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (shouldRecover == true) {
      _showSnackBar?.call(
        const SnackBar(
          content: Text('Run recovery is being improved. Starting fresh run.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    await RunRecoveryService.clearRecoverableRun();
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  void _showRunSavedNotification(double distanceKm, int durationSeconds) {
    final distanceStr = distanceKm.toStringAsFixed(2);
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    final durationStr = "$minutes:${seconds.toString().padLeft(2, '0')}";

    _showSnackBar?.call(
      SnackBar(
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Run saved! ${distanceStr}km in $durationStr",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============== AUTO-SAVE ==============

  void startAutoSave(String planTitle) {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _saveCurrentRunState(planTitle);
    });
    debugPrint('🔄 Auto-save started (every 10 seconds)');
  }

  void stopAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    debugPrint('⏹️ Auto-save stopped');
  }

  Future<void> _saveCurrentRunState(String planTitle) async {
    try {
      await RunRecoveryService.saveActiveRun(
        distance: stateController.totalDistance / 1000,
        durationSeconds: stateController.secondsElapsed,
        routePoints: stateController.routePoints
            .map((p) => {'lat': p.latitude, 'lng': p.longitude})
            .toList(),
        startTime: DateTime.now().subtract(Duration(seconds: stateController.secondsElapsed)),
        planTitle: planTitle,
        additionalData: {
          'pace': stateController.paceString,
          'calories': stateController.totalCalories,
          'avgBpm': stateController.currentBpm,
          'gpsAcceptanceRate': stateController.gpsAcceptanceRate,
        },
      );
      debugPrint('💾 Run state auto-saved');
    } catch (e) {
      debugPrint('⚠️ Error auto-saving run state: $e');
      _crashReporting.recordError(e, StackTrace.current, reason: 'Auto-save failed');
    }
  }

  // ============== RUN CONTROL ==============

  /// Call this immediately when the user taps START — before the warmup dialog.
  /// Starts GPS so iOS keeps the app alive in background even if the screen is
  /// locked during the warmup countdown.
  Future<void> prewarmGps() async {
    await WakeLockService.enable();
    await voiceController.ensureInitialized();
    await stateController.prewarmGps();
  }

  Future<void> startRun({String planTitle = "Free Run", BuildContext? context}) async {
    try {
      debugPrint("🎬 RunController: Starting run");
      _lastError = null;

      if (context != null) {
        setUiContext(context);
      }

      // Ensure voice is initialized (fixes iOS Safari issue)
      await voiceController.ensureInitialized();

      // Load user's nickname/first name for personalized voice announcements
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          final data = doc.data() ?? {};
          final callName = (data['nickname'] as String?)?.trim().isNotEmpty == true
              ? data['nickname'] as String
              : (data['firstName'] as String?)?.trim() ?? '';
          voiceController.setUserName(callName);
        }
      } catch (_) {}

      // Enable wake lock to keep screen on
      await WakeLockService.enable();
      debugPrint("🔒 Screen wake lock enabled");

      // Start tracking
      await stateController.startRun();

      // Fetch weather for the start location
      try {
        final pos = stateController.lastPosition;
        if (pos != null) {
          final weatherService = WeatherService();
          // Ensure API key is set from RemoteConfig or Secret
          final apiKey = serviceLocator.remoteConfigService.getString('openweather_api_key');
          if (apiKey.isNotEmpty) {
            weatherService.setApiKey(apiKey);
            final weather = await weatherService.fetchWeather(pos.latitude, pos.longitude);
            if (weather != null) {
              stateController.setStartWeather(weather);
              unawaited(voiceController.speak(weatherService.getWeatherAnnouncement()));
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ Weather fetch failed: $e');
      }

      // Log analytics
      _analytics.logRunStarted();

      // Announce start — fire-and-forget so Navigator.push(ActiveRunScreen)
      // is not blocked by TTS duration. If the user locks the screen during
      // the ~2s "Run started!" phrase, they were still on RunTrackerScreen
      // and never saw ActiveRunScreen. Now navigation happens immediately.
      unawaited(voiceController.speakRunStarted());

      // Start interval training if one was selected
      final intervalService = IntervalTrainingService();
      final pending = intervalService.pendingWorkout;
      if (pending != null) {
        intervalService.pendingWorkout = null;
        try {
          await intervalService.initialize();
          await intervalService.startWorkout(pending);
          debugPrint('🏃 Interval workout started: ${pending.name}');
        } catch (e) {
          debugPrint('⚠️ Could not start interval workout: $e');
        }
      }

      // Start auto-save
      startAutoSave(planTitle);
      notifyListeners();

      debugPrint("✅ RunController: Run started successfully");
    } catch (e) {
      debugPrint("❌ RunController: Error starting run: $e");
      _lastError = e.toString();
      _crashReporting.recordRunTrackingError(phase: 'start', errorMessage: e.toString());
      await WakeLockService.disable();
      rethrow;
    }
  }

  void pauseRun() {
    debugPrint("🎬 RunController: Pausing run");
    stateController.pauseRun();
    voiceController.speakRunPaused();
    _analytics.logRunPaused();
    notifyListeners();
  }

  void resumeRun() {
    debugPrint("🎬 RunController: Resuming run");
    stateController.resumeRun();
    voiceController.speakRunResumed();
    _analytics.logRunResumed();
    notifyListeners();
  }

  Future<void> stopRun(
    BuildContext context, {
    String planTitle = "Free Run",
    Uint8List? mapImageBytes,
  }) async {
    try {
      setUiContext(context);

      debugPrint("🎬 RunController: Stopping run");
      debugPrint("📸 Map image provided: ${mapImageBytes != null ? '${mapImageBytes.length} bytes' : 'null'}");

      // Capture final stats before stopping
      final finalDistance = stateController.totalDistance / 1000;
      final finalDuration = stateController.secondsElapsed;
      final finalMovingTime = stateController.activeRunSeconds; // excludes paused time
      final finalPace = stateController.paceString;
      final finalCalories = stateController.totalCalories;
      final finalRoutePoints = List<LatLng>.from(stateController.routePoints);
      final finalBpm = stateController.currentBpm;
      final routeStats = stateController.getRouteStats();
      // Real per-km splits for split display in RunDetailScreen
      final finalKmSplits = stateController.kmSplits.map((s) => {
        'kmNumber': s.kmNumber,
        'durationSeconds': s.durationSeconds,
        'pace': s.pace,
        'elevationChange': s.elevationChange,
      }).toList();

      // Cancel auto-save timer before stopping run state to prevent a timer
      // firing between stopRun() and the later stopAutoSave() call with zeroed data.
      stopAutoSave();

      // Stop tracking
      await stateController.stopRun();
      await voiceController.speakRunStopped();

      debugPrint("📊 Final stats - Distance: ${finalDistance}km, Duration: ${finalDuration}s, Pace: $finalPace");
      debugPrint("📍 Route points: ${finalRoutePoints.length} points");
      debugPrint("📊 GPS Acceptance Rate: ${stateController.gpsAcceptanceRate.toStringAsFixed(1)}%");
      debugPrint("📊 Elevation gain: ${routeStats['elevationGain']?.toStringAsFixed(0) ?? '0'}m");

      // Log analytics — includes GPS health so silent failures show up in Firebase
      _analytics.logRunCompleted(
        distanceKm: finalDistance,
        durationSeconds: finalDuration,
        avgPaceMinPerKm: _paceStringToMinutes(finalPace),
        routePointCount: finalRoutePoints.length,
        gpsAcceptanceRate: stateController.gpsAcceptanceRate,
      );

      // Save to history and capture achievements
      ({List<String> pbs, List<String> badges}) runResult;
      try {
        runResult = await statsController.saveRunHistory(
          planTitle: planTitle,
          distanceKm: finalDistance,
          durationSeconds: finalDuration,
          pace: finalPace,
          routePoints: finalRoutePoints,
          avgBpm: finalBpm,
          calories: finalCalories,
          extra: {
            'elevationGain': routeStats['elevationGain'] ?? 0.0,
            'elevationLoss': routeStats['elevationLoss'] ?? 0.0,
            'movingTimeSeconds': finalMovingTime,
            'kmSplits': finalKmSplits,
            if (stateController.startWeather != null)
              'weather': {
                'temp': stateController.startWeather!.temperatureCelsius,
                'condition': stateController.startWeather!.condition.name,
                'description': stateController.startWeather!.description,
                'humidity': stateController.startWeather!.humidity,
                'windSpeed': stateController.startWeather!.windSpeedKmh,
                'location': stateController.startWeather!.locationName,
              },
          },
        );
      } catch (saveError) {
        // Firestore unavailable — save locally for later sync
        debugPrint('⚠️ Firestore save failed, saving offline: $saveError');
        runResult = (pbs: [], badges: []);
        try {
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid != null && !kIsWeb) {
            await OfflineDatabaseService().savePendingRun(PendingRun(
              id: const Uuid().v4(),
              userId: uid,
              distanceMeters: finalDistance * 1000,
              durationSeconds: finalDuration,
              startTime: DateTime.now().subtract(Duration(seconds: finalDuration)),
              endTime: DateTime.now(),
              routePoints: finalRoutePoints
                  .map((p) => {'lat': p.latitude, 'lng': p.longitude})
                  .toList(),
              avgHeartRate: finalBpm > 0 ? finalBpm : null,
              calories: finalCalories,
              elevationGain: (routeStats['elevationGain'] as num?)?.toDouble(),
              createdAt: DateTime.now(),
            ));
            debugPrint('📥 Run saved offline for later sync');
          }
        } catch (offlineError) {
          debugPrint('❌ Offline save also failed: $offlineError');
        }
      }
      lastRunPbs = runResult.pbs;
      lastRunBadges = runResult.badges;
      lastRunKmSplits = finalKmSplits;

      // Auto-post a badge achievement card to the feed for each badge earned.
      // Fires in the background so it doesn't block the UI transition.
      for (final badge in lastRunBadges) {
        final imageUrl = PostController.badgeImageForName(badge);
        if (imageUrl != null) {
          postController.createBadgePost(
            badgeName: badge,
            badgeImageUrl: imageUrl,
          ).catchError((e) => debugPrint('⚠️ Badge post failed: $e'));
        }
      }

      // Update run streak and post milestone cards (3/7/14/30/60/90/180/365 days).
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        _updateStreakAndPost(uid).catchError((e) => debugPrint('⚠️ Streak update failed: $e'));

        // Weekly recap — post on Monday after finishing a run (once per week).
        if (DateTime.now().weekday == DateTime.monday) {
          _maybePostWeeklyRecap(uid).catchError((e) => debugPrint('⚠️ Weekly recap failed: $e'));
        }
      }

      debugPrint("✅ Run saved to history — PBs: $lastRunPbs, Badges: $lastRunBadges");

      // Clean up
      await RunRecoveryService.clearRecoverableRun();
      try { IntervalTrainingService().stop(); } catch (_) {}
      stopAutoSave();
      debugPrint("✅ Recovery data cleared");

      await WakeLockService.disable();
      debugPrint("🔓 Screen wake lock disabled");

      stateController.resetRun();
      debugPrint("✅ Run data reset");

      _lastMilestoneSnackKm = 0;

      _showRunSavedNotification(finalDistance, finalDuration);

      notifyListeners();
      debugPrint("✅ RunController: Stop complete");
    } catch (e, stack) {
      debugPrint("❌ RunController: Error stopping run: $e");
      _crashReporting.recordRunTrackingError(phase: 'stop', errorMessage: e.toString());
      _crashReporting.recordError(e, stack, reason: 'Error stopping run');
      stopAutoSave();
      await WakeLockService.disable();
      stateController.resetRun();
      _lastMilestoneSnackKm = 0;
      notifyListeners();
      rethrow;
    }
  }

  /// Updates the user's run streak and creates a streak milestone post if a
  /// milestone (3/7/14/30/60/90/180/365 days) was just crossed.
  Future<void> _updateStreakAndPost(String uid) async {
    final result = await StreakService().updateStreak(uid);
    final prev = (result['previousStreak'] as int?) ?? 0;
    final current = (result['currentStreak'] as int?) ?? 0;
    for (final milestone in [3, 7, 14, 30, 60, 90, 180, 365]) {
      if (prev < milestone && current >= milestone) {
        await postController.createStreakPost(streakDays: milestone);
        debugPrint('🔥 Streak milestone post: $milestone days');
      }
    }
  }

  /// Posts a weekly recap summary on Monday, at most once per calendar week.
  Future<void> _maybePostWeeklyRecap(String uid) async {
    final now = DateTime.now();
    // ISO week number: a simple but consistent key per week
    final weekKey = '${now.year}_${now.month}_${(now.day / 7).ceil()}';
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final userSnap = await userRef.get();
    if ((userSnap.data()?['lastWeeklyRecap'] as String?) == weekKey) return;

    final stats = await statsController.getLastWeekStats();
    if (stats.totalRuns == 0) return; // nothing to recap

    await postController.createWeeklyRecapPost(
      totalRuns: stats.totalRuns,
      totalKm: stats.totalKm,
      totalSeconds: stats.totalSeconds,
    );

    await userRef.set({'lastWeeklyRecap': weekKey}, SetOptions(merge: true));
    debugPrint('📊 Weekly recap posted for week $weekKey');
  }

  double _paceStringToMinutes(String pace) {
    final parts = pace.split(':');
    if (parts.length != 2) return 0;
    final minutes = int.tryParse(parts[0]) ?? 0;
    final seconds = int.tryParse(parts[1]) ?? 0;
    return minutes + (seconds / 60);
  }

  // ============== STATS & HISTORY ==============

  Stream<List<dynamic>> getPostStream() => statsController.getPostStream();
  Future<void> refreshHistoryStats() async => await statsController.refreshHistoryStats();
  Future<Map<String, dynamic>?> getLastActivity() async => await statsController.getLastActivity();
  Future<List<Map<String, dynamic>>> getRunHistory() async => await statsController.getRunHistory();
  Future<List<Map<String, dynamic>>> getRunHistoryPage({required int pageSize, DateTime? before}) async =>
      await statsController.getRunHistoryPage(pageSize: pageSize, before: before);

  /// Generates a suggested post caption. Call after stopRun() to pre-fill the editor.
  String generatePostText({
    required String planTitle,
    required String distance,
    required String duration,
    required String pace,
    required int calories,
  }) {
    return postController.generateAIPost(planTitle, distance, duration, pace, calories);
  }

  @override
  void dispose() {
    debugPrint("🗑️ Disposing RunController");
    stopAutoSave();
    unawaited(WakeLockService.disable()); // fire-and-forget; dispose() can't be async
    stateController.removeListener(_onStateControllerChanged);
    stateController.dispose();
    super.dispose();
  }
}
