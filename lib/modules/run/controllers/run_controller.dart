import 'dart:async';

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

  // ✅ NEW: store a context for showing SnackBars (optional, safe)
  BuildContext? _uiContext;

  // ✅ NEW: prevent spamming the UI with repeated milestone SnackBars
  int _lastMilestoneSnackKm = 0;

  RunController() {
    // Listen to state controller changes and propagate them
    stateController.addListener(_onStateControllerChanged);

    // Connect km milestone callback to voice announcements
    stateController.onKmMilestone = ({
      required int km,
      required String totalTime,
      required String lastKmPace,
      required String averagePace,
      String? comparison,
    }) {
      // ✅ iOS WebKit: speech from timers can be blocked unless triggered by user gesture
      // Workaround: show SnackBar with action button to trigger speech by tap. [2](https://community.flutterflow.io/ask-the-community/post/tts-audio-tested-on-web-laptop-browser-is-good-but-no-sound-on-mobile-2EborMncDWqyt92)[3](https://necms-my.sharepoint.com/personal/hanumaiah_ta_nec_com_sg/Documents/Microsoft%20Copilot%20Chat%20Files/feb6.txt)
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

      // Default behavior (native + non-iOS web): speak immediately
      voiceController.speakKmMilestone(
        km: km,
        totalTime: totalTime,
        lastKmPace: lastKmPace,
        averagePace: averagePace,
        comparison: comparison,
      );
    };
  }

  void _onStateControllerChanged() {
    notifyListeners();
  }

  // ---- Getters (unchanged) ----
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

  // ✅ NEW: set context safely for SnackBars (optional)
  // You can call this from any screen build/init (e.g., ActiveRunScreen build)
  void setUiContext(BuildContext context) {
    _uiContext = context;
  }

  // ✅ Use tap-to-speak strategy only on Flutter Web + iOS platform
  bool _shouldUseTapToSpeakForMilestone() {
    if (!kIsWeb) return false;
    // On web, defaultTargetPlatform indicates the browser's platform.
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

    // Avoid duplicates if the callback is triggered multiple times quickly
    if (km <= _lastMilestoneSnackKm) return;
    _lastMilestoneSnackKm = km;

    final ctx = _uiContext;
    if (ctx == null) {
      // If we have no context, fallback to best-effort immediate speak (may be blocked on iOS web)
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
      // Same fallback as above
      voiceController.speakKmMilestone(
        km: km,
        totalTime: totalTime,
        lastKmPace: lastKmPace,
        averagePace: averagePace,
        comparison: comparison,
      );
      return;
    }

    // Clear any prior snack to keep the UX clean
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
        content: Text("🎯 ${km}km reached • Tap PLAY to hear update"),
        action: SnackBarAction(
          label: "PLAY",
          onPressed: () {
            // ✅ User gesture triggers speech (works better on iOS WebKit). [2](https://community.flutterflow.io/ask-the-community/post/tts-audio-tested-on-web-laptop-browser-is-good-but-no-sound-on-mobile-2EborMncDWqyt92)[3](https://necms-my.sharepoint.com/personal/hanumaiah_ta_nec_com_sg/Documents/Microsoft%20Copilot%20Chat%20Files/feb6.txt)
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

  // ---- Recovery (mostly unchanged) ----
  Future<void> checkForRecoverableRun(BuildContext context) async {
    if (_hasShownRecoveryDialog) return;

    // ✅ store context so iOS web milestone snackbars can show
    setUiContext(context);

    final hasRecoverable = await RunRecoveryService.hasRecoverableRun();
    if (!hasRecoverable) return;

    final runData = await RunRecoveryService.getRecoverableRun();
    if (runData == null) return;

    final timeSince = RunRecoveryService.timeSinceLastSave(runData);

    // ✅ FIX: keep your original intention (discard if missing or too old)
    if (timeSince == null || timeSince.inHours > 24) {
      await RunRecoveryService.clearRecoverableRun();
      return;
    }

    // Auto-recover training runs (no dialog)
    if (runData['type'] == 'training') {
      debugPrint('🔄 Auto-recovering training run...');
      await _saveRecoveredRun(runData);

      try {
        final distance = (runData['distance'] ?? 0.0).toDouble();
        final duration = runData['durationSeconds'] ?? 0;
        final planTitle = runData['planTitle'] ?? 'Training';

        final pace = runData['pace'] ?? _calculatePace(distance, duration);
        final calories = runData['calories'] ?? _estimateCalories(distance);
        final planImageUrl = runData['planImageUrl'];

        final aiContent = postController.generateAIPost(
          planTitle,
          distance.toStringAsFixed(2),
          _formatDuration(duration),
          pace,
          calories,
        );

        await postController.createAutoPost(
          aiContent: "$aiContent\nRecovered session: $planTitle",
          routePoints: const [],
          distance: distance.toStringAsFixed(2),
          pace: pace,
          bpm: 0,
          planTitle: planTitle,
          mapImageUrlOverride: planImageUrl,
        );

        debugPrint('✅ Auto-posted recovered training run');
      } catch (e) {
        debugPrint('⚠️ Error auto-posting recovered run: $e');
      }

      await RunRecoveryService.clearRecoverableRun();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Recovered and posted your interrupted training run!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return;
    }

    _hasShownRecoveryDialog = true;
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.restore, color: Colors.orange),
            SizedBox(width: 8),
            Text('Recover Run?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'We found an incomplete run from your last session:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            _buildRecoveryDetail('Distance', '${runData['distance']?.toStringAsFixed(2) ?? 0} km'),
            _buildRecoveryDetail('Duration', _formatDuration(runData['durationSeconds'] ?? 0)),
            _buildRecoveryDetail('Started', _formatStartTime(runData['startTime'])),
            const SizedBox(height: 16),
            const Text(
              'Would you like to save this run to your history?',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await RunRecoveryService.clearRecoverableRun();
              navigator.pop();
            },
            child: const Text('Discard'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              await _saveRecoveredRun(runData);
              await RunRecoveryService.clearRecoverableRun();

              navigator.pop();
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('✅ Run recovered and saved to history!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Save Run'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecoveryDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  String _formatStartTime(String? isoString) {
    if (isoString == null) return 'Unknown';
    try {
      final dateTime = DateTime.parse(isoString);
      final now = DateTime.now();
      final diff = now.difference(dateTime);

      if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
      if (diff.inHours < 24) return '${diff.inHours} hours ago';
      return '${diff.inDays} days ago';
    } catch (_) {
      return 'Unknown';
    }
  }

  Future<void> _saveRecoveredRun(Map<String, dynamic> runData) async {
    try {
      final List<dynamic> rawPoints = runData['routePoints'] ?? [];
      final routePoints = rawPoints
          .map((p) {
            if (p is Map) {
              return LatLng(
                (p['lat'] ?? p['latitude'] ?? 0.0).toDouble(),
                (p['lng'] ?? p['longitude'] ?? 0.0).toDouble(),
              );
            }
            return null;
          })
          .whereType<LatLng>()
          .toList();

      final distance = (runData['distance'] ?? 0.0).toDouble();
      final durationSeconds = runData['durationSeconds'] ?? 0;
      final pace = runData['pace'] ?? _calculatePace(distance, durationSeconds);
      final calories = runData['calories'] ?? _estimateCalories(distance);
      final planTitle = runData['planTitle'] ?? 'Free Run';
      final avgBpm = runData['avgBpm'] ?? 145;

      await statsController.saveRunHistory(
        planTitle: planTitle,
        distanceKm: distance,
        durationSeconds: durationSeconds,
        pace: pace,
        routePoints: routePoints,
        avgBpm: avgBpm,
        calories: calories,
      );

      debugPrint('✅ Recovered run saved successfully');
    } catch (e) {
      debugPrint('❌ Error saving recovered run: $e');
    }
  }

  String _calculatePace(double distanceKm, int durationSeconds) {
    if (distanceKm <= 0) return '0:00';
    final paceSeconds = durationSeconds / distanceKm;
    final minutes = paceSeconds ~/ 60;
    final seconds = (paceSeconds % 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  int _estimateCalories(double distanceKm) {
    return (distanceKm * 60).round();
  }

  // ---- Auto-save (unchanged) ----
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

  // ✅ UPDATED signature: optional context does NOT break existing calls
  Future<void> startRun({String planTitle = "Free Run", BuildContext? context}) async {
    try {
      debugPrint("🎬 RunController: Starting run");

      if (context != null) {
        setUiContext(context);
      }

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
      // ✅ store context for snackbars
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

      // reset snack guard for next run
      _lastMilestoneSnackKm = 0;

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