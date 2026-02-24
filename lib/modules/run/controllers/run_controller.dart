import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:majurun/core/services/run_recovery_service.dart';
import 'package:majurun/core/services/wake_lock_service.dart';
import 'package:majurun/modules/run/controllers/post_controller.dart';
import 'package:majurun/modules/run/controllers/run_state_controller.dart';
import 'package:majurun/modules/run/controllers/stats_controller.dart';
import 'package:majurun/modules/run/controllers/voice_controller.dart';

class RunController extends ChangeNotifier {
  final RunStateController stateController = RunStateController();
  final VoiceController voiceController = VoiceController();
  final PostController postController = PostController();
  final StatsController statsController = StatsController();

  // Recovery properties
  Timer? _autoSaveTimer;
  bool _hasShownRecoveryDialog = false;

  // UI context for showing SnackBars
  BuildContext? _uiContext;

  // Prevent spamming UI with repeated milestone SnackBars
  int _lastMilestoneSnackKm = 0;

  RunController() {
    // Listen to state controller changes
    stateController.addListener(_onStateControllerChanged);

    // Connect idle detection callback
    stateController.onIdleDetected = _handleIdleDetected;

    // ✅ Connect full km milestone callback
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

      // Default behavior: speak immediately
      voiceController.speakKmMilestone(
        km: km,
        totalTime: totalTime,
        lastKmPace: lastKmPace,
        averagePace: averagePace,
        comparison: comparison,
      );
    };

    // ✅ NEW: Connect half-km milestone callback
    stateController.onHalfKmMilestone = ({
      required double distanceKm,
      required String currentPace,
    }) {
      // No tap-to-speak needed for half-km (shorter, less critical)
      voiceController.speakHalfKmMilestone(
        distanceKm: distanceKm,
        currentPace: currentPace,
      );
    };
  }

  void _onStateControllerChanged() {
    notifyListeners();
  }

  /// Handle idle detection - show dialog asking if user is done
  void _handleIdleDetected() {
    final ctx = _uiContext;
    if (ctx == null || !ctx.mounted) {
      debugPrint("⚠️ No UI context for idle notification");
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(ctx);
    if (messenger == null) return;

    messenger.showSnackBar(
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
                "No movement for 10 minutes. Are you done for today?",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: "END RUN",
          textColor: Colors.white,
          onPressed: () {
            if (ctx.mounted) {
              stopRun(ctx);
            }
          },
        ),
      ),
    );

    voiceController.speakTraining("No movement detected for 10 minutes. Tap end run if you're done.");
  }

  // ---- Getters ----
  RunState get state => stateController.state;

  String get distanceString => stateController.distanceString;
  String get durationString => stateController.durationString;
  String get paceString => stateController.paceString;

  int get currentBpm => stateController.currentBpm;
  int get totalCalories => stateController.totalCalories;
  double get totalDistance => stateController.totalDistance;
  int get secondsElapsed => stateController.secondsElapsed;

  List<LatLng> get routePoints => stateController.routePoints;
  List<ChartDataSpot> get hrHistorySpots => stateController.hrHistorySpots;
  List<ChartDataSpot> get paceHistorySpots => stateController.paceHistorySpots;

  String? get lastVideoUrl => stateController.lastVideoUrl;

  double get historyDistance => statsController.historyDistance;
  int get runStreak => statsController.runStreak;
  int get totalRuns => statsController.totalRuns;
  String get totalHistoryTimeStr => statsController.totalHistoryTimeStr;

  bool get isVoiceEnabled => voiceController.isVoiceEnabled;
  void toggleVoice() => voiceController.toggleVoice();

  Future<void> generateVeoVideo() async => await postController.generateVeoVideo();

  Future<void> finalizeProPost(String aiContent, String videoUrl, {String? planTitle}) async {
    await postController.finalizeProPost(aiContent, videoUrl, planTitle: planTitle);
  }

  /// Set context for SnackBars
  void setUiContext(BuildContext context) {
    _uiContext = context;
  }

  /// Check if we should use tap-to-speak (iOS Safari workaround)
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

    // Avoid duplicates
    if (km <= _lastMilestoneSnackKm) return;
    _lastMilestoneSnackKm = km;

    final ctx = _uiContext;
    if (ctx == null) {
      voiceController.speakKmMilestone(
        km: km,
        totalTime: totalTime,
        lastKmPace: lastKmPace,
        averagePace: averagePace,
        comparison: comparison,
      );
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(ctx);
    if (messenger == null) {
      voiceController.speakKmMilestone(
        km: km,
        totalTime: totalTime,
        lastKmPace: lastKmPace,
        averagePace: averagePace,
        comparison: comparison,
      );
      return;
    }

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
        content: Text("🎯 ${km}km reached • Tap PLAY to hear update"),
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

  // ---- Recovery ----
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

    if (shouldRecover == true && context.mounted) {
      // ✅ FIXED: Just show message that recovery is not fully implemented yet
      // The recovery code was trying to access private members
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Run recovery is being improved. Starting fresh run.'),
          backgroundColor: Colors.orange,
        ),
      );
      await RunRecoveryService.clearRecoverableRun();
    } else {
      await RunRecoveryService.clearRecoverableRun();
    }
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
    final ctx = _uiContext;
    if (ctx == null || !ctx.mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(ctx);
    if (messenger == null) return;

    final distanceStr = distanceKm.toStringAsFixed(2);
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    final durationStr = "$minutes:${seconds.toString().padLeft(2, '0')}";

    messenger.showSnackBar(
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

  // ---- Auto-save ----
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
            .map((p) => {
                  'lat': p.latitude,
                  'lng': p.longitude,
                })
            .toList(),
        startTime: DateTime.now().subtract(Duration(seconds: stateController.secondsElapsed)),
        planTitle: planTitle,
        additionalData: {
          'pace': stateController.paceString,
          'calories': stateController.totalCalories,
          'avgBpm': stateController.currentBpm,
        },
      );
      debugPrint('💾 Run state auto-saved');
    } catch (e) {
      debugPrint('⚠️ Error auto-saving run state: $e');
    }
  }

  // ---- Run control ----
  Future<void> startRun({String planTitle = "Free Run", BuildContext? context}) async {
    try {
      debugPrint("🎬 RunController: Starting run");

      if (context != null) {
        setUiContext(context);
      }

      // ✅ CRITICAL FIX: Ensure voice is initialized (fixes iOS Safari issue)
      await voiceController.ensureInitialized();

      await WakeLockService.enable();
      debugPrint("🔒 Screen wake lock enabled");

      await stateController.startRun();
      await voiceController.speakRunStarted();

      startAutoSave(planTitle);
      notifyListeners();

      debugPrint("✅ RunController: Run started successfully");
    } catch (e) {
      debugPrint("❌ RunController: Error starting run: $e");
      await WakeLockService.disable();
      rethrow;
    }
  }

  void pauseRun() {
    debugPrint("🎬 RunController: Pausing run");
    stateController.pauseRun();
    voiceController.speakRunPaused();
    notifyListeners();
  }

  void resumeRun() {
    debugPrint("🎬 RunController: Resuming run");
    stateController.resumeRun();
    voiceController.speakRunResumed();
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

      stateController.stopRun();
      await voiceController.speakRunStopped();

      final finalDistance = stateController.totalDistance / 1000;
      final finalDuration = stateController.secondsElapsed;
      final finalPace = stateController.paceString;
      final finalCalories = stateController.totalCalories;
      final finalDistanceString = stateController.distanceString;
      final finalRoutePoints = List<LatLng>.from(stateController.routePoints);
      final finalBpm = stateController.currentBpm;

      debugPrint("📊 Final stats - Distance: ${finalDistance}km, Duration: ${finalDuration}s, Pace: $finalPace");
      debugPrint("📍 Route points: ${finalRoutePoints.length} points");

      await statsController.saveRunHistory(
        planTitle: planTitle,
        distanceKm: finalDistance,
        durationSeconds: finalDuration,
        pace: finalPace,
        routePoints: finalRoutePoints,
        avgBpm: finalBpm,
        calories: finalCalories,
      );

      debugPrint("✅ Run saved to history with route points");

      final aiPost = postController.generateAIPost(
        planTitle,
        finalDistanceString,
        stateController.durationString,
        finalPace,
        finalCalories,
      );

      debugPrint("✅ AI post generated");

      await postController.createAutoPost(
        aiContent: aiPost,
        routePoints: finalRoutePoints,
        distance: finalDistanceString,
        pace: finalPace,
        bpm: finalBpm,
        planTitle: planTitle,
        mapImageBytes: mapImageBytes,
      );

      debugPrint("✅ Auto post created");

      await RunRecoveryService.clearRecoverableRun();
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
    } catch (e) {
      debugPrint("❌ RunController: Error stopping run: $e");
      stopAutoSave();
      await WakeLockService.disable();
      stateController.resetRun();
      _lastMilestoneSnackKm = 0;
      notifyListeners();
      rethrow;
    }
  }

  Stream<List<dynamic>> getPostStream() => statsController.getPostStream();
  Future<void> refreshHistoryStats() async => await statsController.refreshHistoryStats();
  Future<Map<String, dynamic>?> getLastActivity() async => await statsController.getLastActivity();
  Future<List<Map<String, dynamic>>> getRunHistory() async => await statsController.getRunHistory();

  @override
  void dispose() {
    debugPrint("🗑️ Disposing RunController");
    stopAutoSave();
    WakeLockService.disable();
    stateController.removeListener(_onStateControllerChanged);
    stateController.dispose();
    super.dispose();
  }
}