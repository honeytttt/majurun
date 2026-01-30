import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:majurun/modules/run/services/voice_announcer.dart';
import 'package:majurun/modules/run/controllers/run_state_controller.dart';
import 'package:majurun/modules/run/controllers/voice_controller.dart';
import 'package:majurun/modules/run/controllers/post_controller.dart';
import 'package:majurun/modules/run/controllers/stats_controller.dart';

enum RunState { idle, running, paused }

class ChartDataSpot {
  final double x;
  final double y;
  const ChartDataSpot(this.x, this.y);
}

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
  // Compose the split controllers
  final RunStateController stateController = RunStateController();
  final VoiceController voiceController = VoiceController();
  final PostController postController = PostController();
  final StatsController statsController = StatsController();

  // Expose key properties from stateController
  RunState get state => stateController.state;
  String get distanceString => stateController.distanceString;
  String get durationString => stateController.durationString;
  String get paceString => stateController.paceString;
  List<LatLng> get routePoints => stateController.routePoints;
  Set<Polyline> get polylines => stateController.polylines;

  // Expose voice
  bool get isVoiceEnabled => voiceController.isVoiceEnabled;
  void toggleVoice() => voiceController.toggleVoice();

  // Expose stats
  int get totalRuns => statsController.totalRuns;
  String get totalHistoryTimeStr => statsController.totalHistoryTimeStr;
  double get historyDistance => statsController.historyDistance;
  int get runStreak => statsController.runStreak;
  Future<void> refreshHistoryStats() async => await statsController.refreshHistoryStats();
  Stream<List<RunAppPost>> getPostStream() => statsController.getPostStream();

  // Expose run control (delegates to stateController and voiceController)
  Future<void> startRun() async {
    await stateController.startRun();
    await voiceController.speakRunStarted();
    notifyListeners();
  }

  void pauseRun() {
    stateController.pauseRun();
    voiceController.speakRunPaused();
    notifyListeners();
  }

  void resumeRun() {
    stateController.resumeRun();
    voiceController.speakRunResumed();
    notifyListeners();
  }

  Future<void> stopRun(BuildContext context, {String planTitle = "Free Run"}) async {
    stateController.stopRun();
    await voiceController.speakRunStopped();

    await statsController.saveRunHistory(
      planTitle: planTitle,
      distanceKm: stateController._totalDistance / 1000,
      durationSeconds: stateController._secondsElapsed,
      pace: stateController.paceString,
    );

    final aiPost = postController.generateAIPost(planTitle, stateController.distanceString, stateController.durationString, stateController.paceString, stateController.totalCalories);
    await postController.createAutoPost(aiPost, stateController.routePoints, stateController.distanceString, stateController.paceString, stateController.currentBpm, planTitle);

    notifyListeners();
  }

  // Other methods delegated similarly...

  @override
  void dispose() {
    stateController.dispose();
    super.dispose();
  }
}