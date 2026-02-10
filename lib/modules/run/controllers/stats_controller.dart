import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:majurun/modules/run/domain/repositories/run_history_repository.dart';
import 'package:majurun/modules/run/data/repositories/firestore_run_history_impl.dart';
import 'package:majurun/modules/run/domain/entities/run_post.dart';
import 'package:majurun/core/services/user_stats_service.dart';

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
    final uid = FirebaseAuth.instance.currentUser?.uid;

    debugPrint('📊 StatsController.saveRunHistory called');
    debugPrint('   User ID: $uid');
    debugPrint('   Distance: ${distanceKm.toStringAsFixed(2)} km');
    debugPrint('   Duration: $durationSeconds seconds');
    debugPrint('   Calories: ${calories ?? 0}');

    if (uid == null) {
      debugPrint('❌ No user logged in - cannot save stats');
      return;
    }

    // 1) Save the run using your existing repository
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

    debugPrint('✅ Run saved to history repository');

    // 2) Calculate pace in seconds per km for bestPaceSecPerKm
    final paceSecPerKm = distanceKm > 0 ? (durationSeconds / distanceKm).round() : 0;

    debugPrint('📈 Calculated paceSecPerKm: $paceSecPerKm');

    // 3) Update user stats in Firestore - DIRECT UPDATE FOR RELIABILITY
    try {
      final userRef = _firestore.collection('users').doc(uid);

      // Get current best pace to compare
      final userDoc = await userRef.get();
      final currentBestPace = userDoc.data()?['bestPaceSecPerKm'] as int?;

      debugPrint('   Current best pace: $currentBestPace');
      debugPrint('   This run pace: $paceSecPerKm');

      // Determine if this is a new best pace (lower is better)
      final newBestPace = (currentBestPace == null || (paceSecPerKm > 0 && paceSecPerKm < currentBestPace))
          ? paceSecPerKm
          : currentBestPace;

      if (newBestPace == paceSecPerKm && paceSecPerKm > 0) {
        debugPrint('🎯 NEW BEST PACE! $paceSecPerKm sec/km');
      }

      // Update user document with atomic operations
      await userRef.update({
        'totalKm': FieldValue.increment(distanceKm),
        'totalRunSeconds': FieldValue.increment(durationSeconds),
        'totalCalories': FieldValue.increment(calories ?? 0),
        'postsCount': FieldValue.increment(1),
        'bestPaceSecPerKm': newBestPace > 0 ? newBestPace : paceSecPerKm,
      });

      debugPrint('✅ User stats updated in Firestore:');
      debugPrint('   +${distanceKm.toStringAsFixed(2)} km to totalKm');
      debugPrint('   +$durationSeconds sec to totalRunSeconds');
      debugPrint('   +${calories ?? 0} cal to totalCalories');
      debugPrint('   +1 to postsCount');
      debugPrint('   bestPaceSecPerKm set to: ${newBestPace > 0 ? newBestPace : paceSecPerKm}');

    } catch (e) {
      debugPrint('❌ ERROR updating user stats in Firestore: $e');
      debugPrint('   Error type: ${e.runtimeType}');

      // Still try UserStatsService as fallback
      debugPrint('⚠️ Attempting fallback via UserStatsService...');
      try {
        await UserStatsService().addRun(
          uid: uid,
          distanceKm: distanceKm,
          durationSeconds: durationSeconds,
          calories: calories ?? 0,
          completed: completed ?? true,
        );
        debugPrint('✅ Fallback update successful');
      } catch (fallbackError) {
        debugPrint('❌ Fallback also failed: $fallbackError');
      }
    }

    // Keep your existing in-memory updates
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
        .map((snapshot) =>
            snapshot.docs.map((doc) => RunPost.fromFirestore(doc)).toList());
  }
}