import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class UserStatsService {
  final FirebaseFirestore _db;
  UserStatsService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  /// workouts = all runs (training + main run)
  /// PB thresholds: >= qualifies
  /// Returns ({pbs: [...], badges: [...]}) for notifications.
  Future<({List<String> pbs, List<String> badges})> addRun({
    required String uid,
    required double distanceKm,
    required int durationSeconds,
    required int calories,
    bool completed = true,
  }) async {
    if (!completed) return (pbs: <String>[], badges: <String>[]);

    debugPrint('📊 UserStatsService.addRun: uid=$uid, dist=${distanceKm}km, dur=${durationSeconds}s, cal=$calories');

    final userRef = _db.collection('users').doc(uid);

    // Badge increments
    final int inc5k = distanceKm >= 5.0 ? 1 : 0;
    final int inc10k = distanceKm >= 10.0 ? 1 : 0;
    final int incHalf = distanceKm >= 21.0975 ? 1 : 0;
    final int incFull = distanceKm >= 42.195 ? 1 : 0;

    // Best pace = best average pace (sec per km). Lower is better.
    final int paceSecPerKm =
        distanceKm > 0 ? (durationSeconds / distanceKm).round() : durationSeconds;

    final detectedPBs = <String>[];
    final newBadges = <String>[];

    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(userRef);
        final data = snap.data() ?? <String, dynamic>{};

        // Get current values with defaults of 0
        final currentWorkouts = (data['workoutsCount'] as int?) ?? 0;
        final currentKm = (data['totalKm'] as num?)?.toDouble() ?? 0.0;
        final currentSeconds = (data['totalRunSeconds'] as int?) ?? 0;
        final currentCalories = (data['totalCalories'] as int?) ?? 0;
        final currentBadge5k = (data['badge5k'] as int?) ?? 0;
        final currentBadge10k = (data['badge10k'] as int?) ?? 0;
        final currentBadgeHalf = (data['badgeHalf'] as int?) ?? 0;
        final currentBadgeFull = (data['badgeFull'] as int?) ?? 0;

        // Detect first-time badge completion (from 0 → 1)
        if (currentBadge5k == 0 && inc5k > 0) newBadges.add('5K');
        if (currentBadge10k == 0 && inc10k > 0) newBadges.add('10K');
        if (currentBadgeHalf == 0 && incHalf > 0) newBadges.add('Half Marathon');
        if (currentBadgeFull == 0 && incFull > 0) newBadges.add('Marathon');

        int? bestPace = data['bestPaceSecPerKm'] as int?;
        int? best5k = data['best5kSeconds'] as int?;
        int? best10k = data['best10kSeconds'] as int?;
        int? bestHalf = data['bestHalfSeconds'] as int?;
        int? bestFull = data['bestFullSeconds'] as int?;

        // Update best pace
        final int newBestPace = bestPace == null
            ? paceSecPerKm
            : (paceSecPerKm < bestPace ? paceSecPerKm : bestPace);
        if (bestPace != null && paceSecPerKm < bestPace) detectedPBs.add('Best Pace');

        // Update best times only if distance qualifies (>=)
        int? newBest5k = best5k;
        if (distanceKm >= 5.0) {
          newBest5k = best5k == null
              ? durationSeconds
              : (durationSeconds < best5k ? durationSeconds : best5k);
          if (best5k != null && durationSeconds < best5k) detectedPBs.add('5K Time');
        }

        int? newBest10k = best10k;
        if (distanceKm >= 10.0) {
          newBest10k = best10k == null
              ? durationSeconds
              : (durationSeconds < best10k ? durationSeconds : best10k);
          if (best10k != null && durationSeconds < best10k) detectedPBs.add('10K Time');
        }

        int? newBestHalf = bestHalf;
        if (distanceKm >= 21.0975) {
          newBestHalf = bestHalf == null
              ? durationSeconds
              : (durationSeconds < bestHalf ? durationSeconds : bestHalf);
          if (bestHalf != null && durationSeconds < bestHalf) detectedPBs.add('Half Marathon');
        }

        int? newBestFull = bestFull;
        if (distanceKm >= 42.195) {
          newBestFull = bestFull == null
              ? durationSeconds
              : (durationSeconds < bestFull ? durationSeconds : bestFull);
          if (bestFull != null && durationSeconds < bestFull) detectedPBs.add('Marathon');
        }

        // Build the update map with explicit values (not FieldValue.increment for reliability)
        final updateData = <String, dynamic>{
          // Totals - compute new values explicitly
          'workoutsCount': currentWorkouts + 1,
          'totalKm': currentKm + distanceKm,
          'totalRunSeconds': currentSeconds + durationSeconds,
          'totalCalories': currentCalories + calories,

          // Badges
          'badge5k': currentBadge5k + inc5k,
          'badge10k': currentBadge10k + inc10k,
          'badgeHalf': currentBadgeHalf + incHalf,
          'badgeFull': currentBadgeFull + incFull,

          // PBs
          'bestPaceSecPerKm': newBestPace,
        };

        // Add optional PB fields
        if (newBest5k != null) updateData['best5kSeconds'] = newBest5k;
        if (newBest10k != null) updateData['best10kSeconds'] = newBest10k;
        if (newBestHalf != null) updateData['bestHalfSeconds'] = newBestHalf;
        if (newBestFull != null) updateData['bestFullSeconds'] = newBestFull;

        tx.set(userRef, updateData, SetOptions(merge: true));

        debugPrint('📊 UserStatsService: Transaction prepared - workouts: ${currentWorkouts + 1}, totalKm: ${currentKm + distanceKm}');
      });

      debugPrint('✅ UserStatsService.addRun: Transaction completed successfully');
    } catch (e) {
      debugPrint('❌ UserStatsService.addRun: Transaction failed: $e');
      // Fallback: try direct update without transaction
      try {
        await userRef.set({
          'workoutsCount': FieldValue.increment(1),
          'totalKm': FieldValue.increment(distanceKm),
          'totalRunSeconds': FieldValue.increment(durationSeconds),
          'totalCalories': FieldValue.increment(calories),
          'badge5k': FieldValue.increment(inc5k),
          'badge10k': FieldValue.increment(inc10k),
          'badgeHalf': FieldValue.increment(incHalf),
          'badgeFull': FieldValue.increment(incFull),
          'bestPaceSecPerKm': paceSecPerKm,
        }, SetOptions(merge: true));
        debugPrint('✅ UserStatsService.addRun: Fallback update succeeded');
      } catch (e2) {
        debugPrint('❌ UserStatsService.addRun: Fallback also failed: $e2');
      }
    }

    return (pbs: detectedPBs, badges: newBadges);
  }

  Future<void> incrementPosts(String uid) async {
    await _db.collection('users').doc(uid).set(
      {'postsCount': FieldValue.increment(1)},
      SetOptions(merge: true),
    );
  }

  /// Recalculate totalKm and workoutsCount from actual training_history records
  /// and sync them back to the user document. Call this to fix stale counters.
  Future<({double totalKm, int totalRuns})> recalculateAndSyncStats(String uid) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('training_history')
          .get();

      double totalKm = 0;
      int totalRuns = snapshot.docs.length;

      for (final doc in snapshot.docs) {
        final d = doc.data();
        totalKm += (d['distanceKm'] as num?)?.toDouble() ?? 0.0;
      }

      // Sync back to user document so profile shows correct values
      await _db.collection('users').doc(uid).set({
        'totalKm': totalKm,
        'workoutsCount': totalRuns,
      }, SetOptions(merge: true));

      debugPrint('✅ UserStatsService: Recalculated — ${totalKm.toStringAsFixed(2)} km, $totalRuns runs');
      return (totalKm: totalKm, totalRuns: totalRuns);
    } catch (e) {
      debugPrint('⚠️ UserStatsService.recalculateAndSyncStats: $e');
      return (totalKm: 0.0, totalRuns: 0);
    }
  }
}