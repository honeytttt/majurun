import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service for managing daily, weekly, and monthly challenges
class DailyChallengeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Daily challenge definitions
  static final List<Map<String, dynamic>> dailyChallengeTemplates = [
    {
      'id': 'daily_run_3km',
      'name': 'Complete a 3km run',
      'description': 'Run at least 3 kilometers today',
      'type': 'distance',
      'target': 3.0,
      'unit': 'km',
      'xpReward': 50,
      'icon': 'directions_run',
    },
    {
      'id': 'daily_run_5km',
      'name': 'Complete a 5km run',
      'description': 'Run at least 5 kilometers today',
      'type': 'distance',
      'target': 5.0,
      'unit': 'km',
      'xpReward': 75,
      'icon': 'directions_run',
    },
    {
      'id': 'daily_workout',
      'name': 'Do a 10 min workout',
      'description': 'Complete any workout for at least 10 minutes',
      'type': 'workout_duration',
      'target': 10,
      'unit': 'min',
      'xpReward': 30,
      'icon': 'fitness_center',
    },
    {
      'id': 'daily_stretch',
      'name': 'Stretch for 5 minutes',
      'description': 'Do a stretching or yoga session',
      'type': 'stretch',
      'target': 5,
      'unit': 'min',
      'xpReward': 20,
      'icon': 'self_improvement',
    },
    {
      'id': 'daily_water',
      'name': 'Log your water intake',
      'description': 'Track your hydration for the day',
      'type': 'water',
      'target': 1,
      'unit': 'log',
      'xpReward': 20,
      'icon': 'water_drop',
    },
    {
      'id': 'daily_morning_run',
      'name': 'Morning Run',
      'description': 'Complete a run before 9 AM',
      'type': 'morning_run',
      'target': 1,
      'unit': 'run',
      'xpReward': 40,
      'icon': 'wb_sunny',
    },
    {
      'id': 'daily_evening_run',
      'name': 'Evening Run',
      'description': 'Complete a run after 5 PM',
      'type': 'evening_run',
      'target': 1,
      'unit': 'run',
      'xpReward': 40,
      'icon': 'nights_stay',
    },
    {
      'id': 'daily_any_run',
      'name': 'Just Run',
      'description': 'Complete any run today',
      'type': 'any_run',
      'target': 1,
      'unit': 'run',
      'xpReward': 30,
      'icon': 'directions_run',
    },
  ];

  /// Weekly challenge definitions
  static final List<Map<String, dynamic>> weeklyChallengeTemplates = [
    {
      'id': 'weekly_20km',
      'name': 'Run 20km this week',
      'description': 'Accumulate 20 kilometers of running this week',
      'type': 'distance',
      'target': 20.0,
      'unit': 'km',
      'xpReward': 150,
      'badgeReward': 'weekly_20k',
      'icon': 'directions_run',
    },
    {
      'id': 'weekly_50km',
      'name': 'Run 50km this week',
      'description': 'Accumulate 50 kilometers of running this week',
      'type': 'distance',
      'target': 50.0,
      'unit': 'km',
      'xpReward': 300,
      'badgeReward': 'weekly_50k',
      'icon': 'directions_run',
    },
    {
      'id': 'weekly_5_workouts',
      'name': 'Complete 5 workouts',
      'description': 'Do any 5 workouts this week',
      'type': 'workout_count',
      'target': 5,
      'unit': 'workouts',
      'xpReward': 100,
      'icon': 'fitness_center',
    },
    {
      'id': 'weekly_5_day_streak',
      'name': 'Maintain 5-day streak',
      'description': 'Run for 5 consecutive days',
      'type': 'streak',
      'target': 5,
      'unit': 'days',
      'xpReward': 75,
      'icon': 'local_fire_department',
    },
  ];

  /// Monthly challenge definitions
  static final List<Map<String, dynamic>> monthlyChallengeTemplates = [
    {
      'id': 'monthly_100km',
      'name': '100K Month Challenge',
      'description': 'Run 100 kilometers this month',
      'type': 'distance',
      'target': 100.0,
      'unit': 'km',
      'xpReward': 500,
      'badgeReward': 'monthly_100k',
      'icon': 'emoji_events',
    },
    {
      'id': 'monthly_200km',
      'name': '200K Month Challenge',
      'description': 'Run 200 kilometers this month',
      'type': 'distance',
      'target': 200.0,
      'unit': 'km',
      'xpReward': 1000,
      'badgeReward': 'monthly_200k',
      'icon': 'emoji_events',
    },
    {
      'id': 'monthly_all_workouts',
      'name': 'Try all workout types',
      'description': 'Complete at least one workout from each category',
      'type': 'workout_variety',
      'target': 7,
      'unit': 'categories',
      'xpReward': 200,
      'icon': 'category',
    },
  ];

  /// Get today's challenges for a user (selects 3 random daily challenges)
  Future<List<Map<String, dynamic>>> getDailyChallenges(String userId) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Check if user already has daily challenges for today
      final userChallengeDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('dailyChallenges')
          .doc(todayStr)
          .get();

      if (userChallengeDoc.exists) {
        final data = userChallengeDoc.data()!;
        return List<Map<String, dynamic>>.from(data['challenges'] ?? []);
      }

      // Generate new daily challenges (pick 3 random ones)
      final shuffled = List<Map<String, dynamic>>.from(dailyChallengeTemplates)..shuffle();
      final selectedChallenges = shuffled.take(3).map((c) => {
        ...c,
        'progress': 0.0,
        'completed': false,
        'date': todayStr,
      }).toList();

      // Save to Firestore
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('dailyChallenges')
          .doc(todayStr)
          .set({
        'challenges': selectedChallenges,
        'createdAt': Timestamp.now(),
        'allCompleted': false,
        'bonusClaimed': false,
      });

      return selectedChallenges;
    } catch (e) {
      debugPrint('Error getting daily challenges: $e');
      return [];
    }
  }

  /// Update progress on a daily challenge
  Future<void> updateChallengeProgress({
    required String userId,
    required String challengeId,
    required double progress,
  }) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('dailyChallenges')
          .doc(todayStr);

      final doc = await docRef.get();
      if (!doc.exists) return;

      final data = doc.data()!;
      final challenges = List<Map<String, dynamic>>.from(data['challenges'] ?? []);

      for (int i = 0; i < challenges.length; i++) {
        if (challenges[i]['id'] == challengeId) {
          final target = (challenges[i]['target'] as num).toDouble();
          challenges[i]['progress'] = progress;
          challenges[i]['completed'] = progress >= target;
          break;
        }
      }

      // Check if all challenges are completed
      final allCompleted = challenges.every((c) => c['completed'] == true);

      await docRef.update({
        'challenges': challenges,
        'allCompleted': allCompleted,
      });

      debugPrint('Challenge progress updated: $challengeId -> $progress');
    } catch (e) {
      debugPrint('Error updating challenge progress: $e');
    }
  }

  /// Claim bonus XP for completing all daily challenges
  Future<int> claimDailyBonus(String userId) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('dailyChallenges')
          .doc(todayStr);

      final doc = await docRef.get();
      if (!doc.exists) return 0;

      final data = doc.data()!;
      if (data['allCompleted'] != true || data['bonusClaimed'] == true) {
        return 0;
      }

      const bonusXP = 50;

      // Mark bonus as claimed
      await docRef.update({'bonusClaimed': true});

      // Add XP to user (this would integrate with your existing XP system)
      debugPrint('Daily bonus claimed: $bonusXP XP');

      return bonusXP;
    } catch (e) {
      debugPrint('Error claiming daily bonus: $e');
      return 0;
    }
  }

  /// Get weekly challenges for current week
  Future<List<Map<String, dynamic>>> getWeeklyChallenges(String userId) async {
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStr = '${weekStart.year}-W${(weekStart.day ~/ 7 + 1).toString().padLeft(2, '0')}';

      final userChallengeDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('weeklyChallenges')
          .doc(weekStr)
          .get();

      if (userChallengeDoc.exists) {
        final data = userChallengeDoc.data()!;
        return List<Map<String, dynamic>>.from(data['challenges'] ?? []);
      }

      // Generate weekly challenges
      final challenges = weeklyChallengeTemplates.map((c) => {
        ...c,
        'progress': 0.0,
        'completed': false,
        'week': weekStr,
      }).toList();

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('weeklyChallenges')
          .doc(weekStr)
          .set({
        'challenges': challenges,
        'createdAt': Timestamp.now(),
      });

      return challenges;
    } catch (e) {
      debugPrint('Error getting weekly challenges: $e');
      return [];
    }
  }

  /// Get monthly challenges for current month
  Future<List<Map<String, dynamic>>> getMonthlyChallenges(String userId) async {
    try {
      final now = DateTime.now();
      final monthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      final userChallengeDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('monthlyChallenges')
          .doc(monthStr)
          .get();

      if (userChallengeDoc.exists) {
        final data = userChallengeDoc.data()!;
        return List<Map<String, dynamic>>.from(data['challenges'] ?? []);
      }

      // Generate monthly challenges
      final challenges = monthlyChallengeTemplates.map((c) => {
        ...c,
        'progress': 0.0,
        'completed': false,
        'month': monthStr,
      }).toList();

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('monthlyChallenges')
          .doc(monthStr)
          .set({
        'challenges': challenges,
        'createdAt': Timestamp.now(),
      });

      return challenges;
    } catch (e) {
      debugPrint('Error getting monthly challenges: $e');
      return [];
    }
  }

  /// Auto-update challenge progress after a run.
  /// Returns the names of challenges that were newly completed this run.
  Future<List<String>> updateChallengesAfterRun({
    required String userId,
    required double distanceKm,
    required DateTime startTime,
  }) async {
    final newlyCompleted = <String>[];
    try {
      final dailyChallenges = await getDailyChallenges(userId);
      for (final challenge in dailyChallenges) {
        // Skip already-completed challenges — don't count them again.
        if (challenge['completed'] == true) continue;

        final wasIncomplete = challenge['completed'] != true;

        if (challenge['type'] == 'distance') {
          final currentProgress = (challenge['progress'] as num?)?.toDouble() ?? 0.0;
          await updateChallengeProgress(
            userId: userId,
            challengeId: challenge['id'],
            progress: currentProgress + distanceKm,
          );
          final target = (challenge['target'] as num).toDouble();
          if (wasIncomplete && (currentProgress + distanceKm) >= target) {
            newlyCompleted.add(challenge['name'] as String);
          }
        }

        if (challenge['type'] == 'morning_run' && startTime.hour < 9) {
          await updateChallengeProgress(
            userId: userId,
            challengeId: challenge['id'],
            progress: 1.0,
          );
          if (wasIncomplete) newlyCompleted.add(challenge['name'] as String);
        }
        if (challenge['type'] == 'evening_run' && startTime.hour >= 17) {
          await updateChallengeProgress(
            userId: userId,
            challengeId: challenge['id'],
            progress: 1.0,
          );
          if (wasIncomplete) newlyCompleted.add(challenge['name'] as String);
        }
        if (challenge['type'] == 'any_run') {
          await updateChallengeProgress(
            userId: userId,
            challengeId: challenge['id'],
            progress: 1.0,
          );
          if (wasIncomplete) newlyCompleted.add(challenge['name'] as String);
        }
      }

      debugPrint('Challenges updated after run: ${distanceKm}km — completed: $newlyCompleted');
    } catch (e) {
      debugPrint('Error updating challenges after run: $e');
    }
    return newlyCompleted;
  }
}
