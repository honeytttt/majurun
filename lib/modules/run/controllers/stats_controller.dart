import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:majurun/modules/run/domain/repositories/run_history_repository.dart';
import 'package:majurun/modules/run/data/repositories/firestore_run_history_impl.dart';
import 'package:majurun/modules/run/domain/entities/run_post.dart';

class StatsController extends ChangeNotifier {
  final RunHistoryRepository _repository;
  final FirebaseFirestore _firestore;

  StatsController({
    RunHistoryRepository? repository,
    FirebaseFirestore? firestore,
  })  : _repository = repository ?? FirestoreRunHistoryImpl(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  double historyDistance = 0.0;
  int runStreak = 0;
  int totalRuns = 0;
  String totalHistoryTimeStr = "00:00:00";

  Future<void> refreshHistoryStats() async {
    final stats = await _repository.getStats();
    totalRuns = stats.totalRuns;
    historyDistance = stats.totalDistanceKm;
    runStreak = stats.runStreak;
    totalHistoryTimeStr = stats.formattedTotalDuration;
    notifyListeners();
  }

  Future<void> saveRunHistory({
    required String planTitle,
    required double distanceKm,
    required int durationSeconds,
    required String pace,
    List<LatLng>? routePoints,
    int? avgBpm,
    int? calories,
    String? type,
    int? week,
    int? day,
    bool? completed,
    String? mapImageUrl,
    Map<String, dynamic>? extra,
  }) async {
    await _repository.saveRun(
      planTitle: planTitle,
      distanceKm: distanceKm,
      durationSeconds: durationSeconds,
      pace: pace,
      routePoints: routePoints,
      avgBpm: avgBpm,
      calories: calories,
      type: type,
      week: week,
      day: day,
      completed: completed,
      mapImageUrl: mapImageUrl,
      extra: extra,
    );

    historyDistance += distanceKm;
    runStreak += 1;

    await refreshHistoryStats();
    notifyListeners();
  }

  Future<Map<String, dynamic>?> getLastActivity() async {
    final lastRun = await _repository.getLastRun();
    if (lastRun == null) return null;

    return {
      'id': lastRun.id,
      'date': lastRun.completedAt,
      'distance': lastRun.distanceKm,
      'durationSeconds': lastRun.durationSeconds,
      'pace': lastRun.pace,
      'calories': lastRun.calories,
      'planTitle': lastRun.planTitle,
      'avgBpm': lastRun.avgBpm,
      'routePoints': lastRun.routePoints,

      // optional training metadata
      'type': lastRun.type,
      'week': lastRun.week,
      'day': lastRun.day,
      'completed': lastRun.completed,
      'mapImageUrl': lastRun.mapImageUrl,
      'extra': lastRun.extra,
    };
  }

  Future<List<Map<String, dynamic>>> getRunHistory() async {
    final runs = await _repository.getAllRuns();
    return runs
        .map((run) => {
              'id': run.id,
              'date': run.completedAt,
              'distance': run.distanceKm,
              'durationSeconds': run.durationSeconds,
              'pace': run.pace,
              'calories': run.calories,
              'planTitle': run.planTitle,
              'avgBpm': run.avgBpm,
              'routePoints': run.routePoints,

              // optional training metadata
              'type': run.type,
              'week': run.week,
              'day': run.day,
              'completed': run.completed,
              'mapImageUrl': run.mapImageUrl,
              'extra': run.extra,
            })
        .toList();
  }

  Stream<List<RunPost>> getPostStream() {
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => RunPost.fromFirestore(doc)).toList());
  }
}