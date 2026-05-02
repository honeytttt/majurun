import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:majurun/core/services/notification_service.dart';

/// Service for managing running streaks and daily activity tracking
class StreakService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  /// Check and update user streak after completing a run
  Future<Map<String, dynamic>> updateStreak(String userId) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final doc = await userRef.get();
      final data = doc.data() ?? <String, dynamic>{};

      final lastRunDate = (data['lastRunDate'] as Timestamp?)?.toDate();
      final currentStreak = (data['currentStreak'] as int?) ?? 0;
      final longestStreak = (data['longestStreak'] as int?) ?? 0;

      int newStreak = currentStreak;
      bool streakExtended = false;
      bool streakBroken = false;

      if (lastRunDate == null) {
        // First ever run
        newStreak = 1;
        streakExtended = true;
      } else {
        final lastRunDay = DateTime(lastRunDate.year, lastRunDate.month, lastRunDate.day);
        final yesterday = today.subtract(const Duration(days: 1));

        if (lastRunDay.isAtSameMomentAs(today)) {
          // Already ran today, streak unchanged
          newStreak = currentStreak;
        } else if (lastRunDay.isAtSameMomentAs(yesterday)) {
          // Ran yesterday, extend streak
          newStreak = currentStreak + 1;
          streakExtended = true;
        } else {
          // Missed a day, streak broken
          newStreak = 1;
          streakBroken = currentStreak > 0;
        }
      }

      final newLongestStreak = newStreak > longestStreak ? newStreak : longestStreak;

      // Update Firestore
      await userRef.set({
        'lastRunDate': Timestamp.fromDate(now),
        'currentStreak': newStreak,
        'longestStreak': newLongestStreak,
      }, SetOptions(merge: true));

      // Check for streak badges
      if (streakExtended) {
        await _checkStreakBadges(userId, newStreak);
      }

      debugPrint('Streak updated: $currentStreak -> $newStreak (longest: $newLongestStreak)');

      return {
        'currentStreak': newStreak,
        'longestStreak': newLongestStreak,
        'streakExtended': streakExtended,
        'streakBroken': streakBroken,
        'previousStreak': currentStreak,
      };
    } catch (e) {
      debugPrint('Error updating streak: $e');
      return {
        'currentStreak': 0,
        'longestStreak': 0,
        'streakExtended': false,
        'streakBroken': false,
        'error': e.toString(),
      };
    }
  }

  /// Check if user earned streak badges
  Future<void> _checkStreakBadges(String userId, int streak) async {
    final streakMilestones = {
      3: 'badge3DayStreak',
      7: 'badge7DayStreak',
      14: 'badge14DayStreak',
      30: 'badge30DayStreak',
      60: 'badge60DayStreak',
      90: 'badge90DayStreak',
      365: 'badge365DayStreak',
    };

    for (final entry in streakMilestones.entries) {
      if (streak == entry.key) {
        final userRef = _firestore.collection('users').doc(userId);
        final doc = await userRef.get();
        final data = doc.data() ?? {};

        final badgeField = entry.value;
        final currentCount = (data[badgeField] as int?) ?? 0;

        if (currentCount == 0) {
          // First time earning this badge
          await userRef.set({badgeField: 1}, SetOptions(merge: true));

          await _notificationService.createBadgeNotification(
            userId: userId,
            badgeName: '${entry.key}-Day Streak',
            badgeDescription: 'You ran ${entry.key} days in a row!',
          );

          debugPrint('Streak badge earned: ${entry.key}-day streak');
        }
      }
    }
  }

  /// Get current streak status for a user
  Future<Map<String, dynamic>> getStreakStatus(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data() ?? {};

      final lastRunDate = (data['lastRunDate'] as Timestamp?)?.toDate();
      final currentStreak = (data['currentStreak'] as int?) ?? 0;
      final longestStreak = (data['longestStreak'] as int?) ?? 0;

      // Check if streak is still active
      bool isActive = false;
      if (lastRunDate != null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final lastRunDay = DateTime(lastRunDate.year, lastRunDate.month, lastRunDate.day);
        final yesterday = today.subtract(const Duration(days: 1));

        isActive = lastRunDay.isAtSameMomentAs(today) || lastRunDay.isAtSameMomentAs(yesterday);
      }

      return {
        'currentStreak': isActive ? currentStreak : 0,
        'longestStreak': longestStreak,
        'lastRunDate': lastRunDate,
        'isActive': isActive,
      };
    } catch (e) {
      debugPrint('Error getting streak status: $e');
      return {
        'currentStreak': 0,
        'longestStreak': 0,
        'lastRunDate': null,
        'isActive': false,
      };
    }
  }

  /// Get weekly activity (which days the user ran this week)
  Future<List<bool>> getWeeklyActivity(String userId) async {
    try {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final weekStart = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

      final runsSnapshot = await _firestore
          .collection('runs')
          .where('userId', isEqualTo: userId)
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .get();

      final runDays = <int>{};
      for (final doc in runsSnapshot.docs) {
        final startTime = (doc.data()['startTime'] as Timestamp).toDate();
        runDays.add(startTime.weekday); // 1 = Monday, 7 = Sunday
      }

      // Return list of 7 bools, Monday to Sunday
      return List.generate(7, (index) => runDays.contains(index + 1));
    } catch (e) {
      debugPrint('Error getting weekly activity: $e');
      return List.filled(7, false);
    }
  }

  /// Calculate XP for a user
  Future<Map<String, dynamic>> calculateUserXP(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data() ?? {};

      int totalXP = 0;

      // Distance XP (10 XP per km)
      final totalDistance = ((data['totalDistance'] as num?)?.toDouble() ?? 0.0);
      totalXP += (totalDistance * 10).toInt();

      // Badge XP
      totalXP += ((data['badge5k'] as int?) ?? 0) * 100;
      totalXP += ((data['badge10k'] as int?) ?? 0) * 250;
      totalXP += ((data['badgeHalf'] as int?) ?? 0) * 500;
      totalXP += ((data['badgeFull'] as int?) ?? 0) * 1000;
      totalXP += ((data['badge50kWeek'] as int?) ?? 0) * 200;
      totalXP += ((data['badge100kWeek'] as int?) ?? 0) * 400;
      totalXP += ((data['badge100kMonth'] as int?) ?? 0) * 300;
      totalXP += ((data['badge200kMonth'] as int?) ?? 0) * 600;

      // Streak badge XP
      totalXP += ((data['badge3DayStreak'] as int?) ?? 0) * 50;
      totalXP += ((data['badge7DayStreak'] as int?) ?? 0) * 100;
      totalXP += ((data['badge14DayStreak'] as int?) ?? 0) * 200;
      totalXP += ((data['badge30DayStreak'] as int?) ?? 0) * 400;
      totalXP += ((data['badge60DayStreak'] as int?) ?? 0) * 800;
      totalXP += ((data['badge90DayStreak'] as int?) ?? 0) * 1200;
      totalXP += ((data['badge365DayStreak'] as int?) ?? 0) * 5000;

      // Calculate level
      int level = 1;
      int xpNeeded = 100;
      int remainingXP = totalXP;

      while (remainingXP >= xpNeeded) {
        remainingXP -= xpNeeded;
        level++;
        xpNeeded = (xpNeeded * 1.2).toInt();
      }

      final xpForNextLevel = xpNeeded;
      final xpProgress = remainingXP;

      return {
        'totalXP': totalXP,
        'level': level,
        'xpProgress': xpProgress,
        'xpForNextLevel': xpForNextLevel,
        'progressPercent': (xpProgress / xpForNextLevel * 100).toInt(),
      };
    } catch (e) {
      debugPrint('Error calculating XP: $e');
      return {
        'totalXP': 0,
        'level': 1,
        'xpProgress': 0,
        'xpForNextLevel': 100,
        'progressPercent': 0,
      };
    }
  }

  /// Get level title based on level number
  String getLevelTitle(int level) {
    if (level < 5) return 'Beginner Runner';
    if (level < 10) return 'Active Runner';
    if (level < 20) return 'Dedicated Runner';
    if (level < 35) return 'Expert Runner';
    if (level < 50) return 'Elite Athlete';
    if (level < 75) return 'Champion';
    return 'Legend';
  }
}
