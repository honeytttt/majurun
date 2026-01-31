import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:majurun/modules/run/controllers/run_state_controller.dart';
import 'package:majurun/modules/run/controllers/voice_controller.dart';
import 'package:majurun/modules/run/controllers/post_controller.dart';
import 'package:majurun/modules/run/controllers/stats_controller.dart';

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
  final RunStateController stateController = RunStateController();
  final VoiceController voiceController = VoiceController();
  final PostController postController = PostController();
  final StatsController statsController = StatsController();

  RunController() {
    // Listen to state controller changes and propagate them
    stateController.addListener(_onStateControllerChanged);
  }

  void _onStateControllerChanged() {
    // When RunStateController changes, notify RunController listeners
    notifyListeners();
  }

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

  Future<void> startRun() async {
    try {
      debugPrint("🎬 RunController: Starting run");
      await stateController.startRun();
      await voiceController.speakRunStarted();
      notifyListeners(); // Ensure UI updates
      debugPrint("✅ RunController: Run started successfully");
    } catch (e) {
      debugPrint("❌ RunController: Error starting run: $e");
      rethrow; // Let the UI handle the error
    }
  }

  void pauseRun() {
    debugPrint("🎬 RunController: Pausing run");
    stateController.pauseRun();
    voiceController.speakRunPaused();
    notifyListeners(); // Ensure UI updates
  }

  void resumeRun() {
    debugPrint("🎬 RunController: Resuming run");
    stateController.resumeRun();
    voiceController.speakRunResumed();
    notifyListeners(); // Ensure UI updates
  }

  Future<void> stopRun(BuildContext context, {
    String planTitle = "Free Run",
    Uint8List? mapImageBytes,
  }) async {
    try {
      debugPrint("🎬 RunController: Stopping run");
      debugPrint("📸 Map image provided: ${mapImageBytes != null ? '${mapImageBytes.length} bytes' : 'null'}");
      
      // Stop the run first (this keeps the data)
      stateController.stopRun();
      await voiceController.speakRunStopped();

      // Get the final stats before resetting
      final finalDistance = stateController.totalDistance / 1000; // in km
      final finalDuration = stateController.secondsElapsed;
      final finalPace = stateController.paceString;
      final finalCalories = stateController.totalCalories;
      final finalDistanceString = stateController.distanceString;
      final finalRoutePoints = List<LatLng>.from(stateController.routePoints);

      debugPrint("📊 Final stats - Distance: ${finalDistance}km, Duration: ${finalDuration}s, Pace: $finalPace");
      debugPrint("📍 Route points: ${finalRoutePoints.length}");

      // Save to history
      await statsController.saveRunHistory(
        planTitle: planTitle,
        distanceKm: finalDistance,
        durationSeconds: finalDuration,
        pace: finalPace,
      );
      debugPrint("✅ Run saved to history");

      // Generate AI post content
      final aiPost = postController.generateAIPost(
        planTitle,
        finalDistanceString,
        stateController.durationString,
        finalPace,
        finalCalories,
      );
      debugPrint("✅ AI post generated: $aiPost");

      // Create auto post WITH map image
      debugPrint("📝 Creating auto post with map image...");
      await postController.createAutoPost(
        aiContent: aiPost,
        routePoints: finalRoutePoints,
        distance: finalDistanceString,
        pace: finalPace,
        bpm: stateController.currentBpm,
        planTitle: planTitle,
        mapImageBytes: mapImageBytes, // Pass the map image bytes
      );
      debugPrint("✅ Auto post created");

      // NOW reset the run data
      stateController.resetRun();
      debugPrint("✅ Run data reset");

      notifyListeners(); // Ensure UI updates
      debugPrint("✅ RunController: Stop complete");
    } catch (e) {
      debugPrint("❌ RunController: Error stopping run: $e");
      debugPrint("Stack trace: ${StackTrace.current}");
      // Still reset even if there's an error
      stateController.resetRun();
      notifyListeners();
      rethrow;
    }
  }

  Stream<List<RunAppPost>> getPostStream() => statsController.getPostStream();

  Future<void> refreshHistoryStats() async => await statsController.refreshHistoryStats();

  Future<Map<String, dynamic>?> getLastActivity() async => await statsController.getLastActivity();

  Future<List<Map<String, dynamic>>> getRunHistory() async => await statsController.getRunHistory();

  @override
  void dispose() {
    debugPrint("🗑️ Disposing RunController");
    stateController.removeListener(_onStateControllerChanged);
    stateController.dispose();
    super.dispose();
  }
}