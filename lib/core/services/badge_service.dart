import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:majurun/core/services/notification_service.dart';

/// Badge definitions with display information
class RunnerBadge {
  final String id;
  final String name;
  final String description;
  final String icon; // Emoji or icon name
  final int count; // How many times earned (for repeat badges)

  RunnerBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.count = 0,
  });

  bool get isEarned => count > 0;
}

class BadgeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  /// Get all badges for a user
  Future<List<RunnerBadge>> getUserBadges(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return [];

      final data = doc.data()!;
      return _buildBadgeList(data);
    } catch (e) {
      debugPrint('❌ Error getting user badges: $e');
      return [];
    }
  }

  /// Stream user badges (for real-time updates)
  Stream<List<RunnerBadge>> streamUserBadges(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return <RunnerBadge>[];
      return _buildBadgeList(doc.data()!);
    });
  }

  List<RunnerBadge> _buildBadgeList(Map<String, dynamic> data) {
    final badges = <RunnerBadge>[];

    // Distance badges (single run achievements)
    final badge5k = (data['badge5k'] as int?) ?? 0;
    final badge10k = (data['badge10k'] as int?) ?? 0;
    final badgeHalf = (data['badgeHalf'] as int?) ?? 0;
    final badgeFull = (data['badgeFull'] as int?) ?? 0;

    // Weekly badges
    final badge50kWeek = (data['badge50kWeek'] as int?) ?? 0;
    final badge100kWeek = (data['badge100kWeek'] as int?) ?? 0;

    // Monthly badges
    final badge100kMonth = (data['badge100kMonth'] as int?) ?? 0;
    final badge200kMonth = (data['badge200kMonth'] as int?) ?? 0;

    // Distance badges with tier-based icons:
    // 5K = Silver 🥈, 10K = Gold 🥇, Half Marathon = Platinum 💎, Marathon = Champion 🏆
    if (badge5k > 0) {
      badges.add(RunnerBadge(
        id: '5k_runner',
        name: '5K Runner',
        description: 'Completed a 5km run',
        icon: '🥈', // Silver
        count: badge5k,
      ));
    }

    if (badge10k > 0) {
      badges.add(RunnerBadge(
        id: '10k_runner',
        name: '10K Runner',
        description: 'Completed a 10km run',
        icon: '🥇', // Gold
        count: badge10k,
      ));
    }

    if (badgeHalf > 0) {
      badges.add(RunnerBadge(
        id: 'half_marathon',
        name: 'Half Marathon',
        description: 'Completed a half marathon (21.1km)',
        icon: '💎', // Platinum
        count: badgeHalf,
      ));
    }

    if (badgeFull > 0) {
      badges.add(RunnerBadge(
        id: 'marathon',
        name: 'Marathon',
        description: 'Completed a full marathon (42.2km)',
        icon: '🏆', // Champion
        count: badgeFull,
      ));
    }

    // Weekly badges with tier-based icons:
    // 50K Week = Silver 🥈, 100K Week = Gold 🥇
    if (badge50kWeek > 0) {
      badges.add(RunnerBadge(
        id: 'weekly_50k',
        name: 'Weekly 50K',
        description: 'Ran 50km in a single week',
        icon: '🥈', // Silver
        count: badge50kWeek,
      ));
    }

    if (badge100kWeek > 0) {
      badges.add(RunnerBadge(
        id: 'weekly_100k',
        name: 'Weekly 100K',
        description: 'Ran 100km in a single week',
        icon: '🥇', // Gold
        count: badge100kWeek,
      ));
    }

    // Monthly badges with tier-based icons:
    // 100K Month = Silver 🥈, 200K Month = Gold 🥇
    if (badge100kMonth > 0) {
      badges.add(RunnerBadge(
        id: 'monthly_100k',
        name: 'Monthly 100K',
        description: 'Ran 100km in a single month',
        icon: '🥈', // Silver
        count: badge100kMonth,
      ));
    }

    if (badge200kMonth > 0) {
      badges.add(RunnerBadge(
        id: 'monthly_200k',
        name: 'Monthly 200K',
        description: 'Ran 200km in a single month',
        icon: '🥇', // Gold
        count: badge200kMonth,
      ));
    }

    return badges;
  }

  /// Add run distance and check for weekly/monthly badges
  Future<void> addRunAndCheckBadges({
    required String userId,
    required double distanceKm,
  }) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      final now = DateTime.now();

      // Get current data
      final doc = await userRef.get();
      final data = doc.data() ?? <String, dynamic>{};

      // Get weekly data
      final weeklyKm = (data['weeklyKm'] as num?)?.toDouble() ?? 0.0;
      final weeklyStartDate = (data['weeklyStartDate'] as Timestamp?)?.toDate();
      final currentWeekStart = _getWeekStart(now);

      // Get monthly data
      final monthlyKm = (data['monthlyKm'] as num?)?.toDouble() ?? 0.0;
      final monthlyStartDate = (data['monthlyStartDate'] as Timestamp?)?.toDate();
      final currentMonthStart = DateTime(now.year, now.month, 1);

      // Calculate new values
      double newWeeklyKm;
      Timestamp newWeeklyStartDate;

      if (weeklyStartDate == null || weeklyStartDate.isBefore(currentWeekStart)) {
        // New week started - reset counter
        newWeeklyKm = distanceKm;
        newWeeklyStartDate = Timestamp.fromDate(currentWeekStart);
        debugPrint('📊 New week started, resetting weekly km');
      } else {
        // Same week - add to counter
        newWeeklyKm = weeklyKm + distanceKm;
        newWeeklyStartDate = Timestamp.fromDate(weeklyStartDate);
      }

      double newMonthlyKm;
      Timestamp newMonthlyStartDate;

      if (monthlyStartDate == null || monthlyStartDate.isBefore(currentMonthStart)) {
        // New month started - reset counter
        newMonthlyKm = distanceKm;
        newMonthlyStartDate = Timestamp.fromDate(currentMonthStart);
        debugPrint('📊 New month started, resetting monthly km');
      } else {
        // Same month - add to counter
        newMonthlyKm = monthlyKm + distanceKm;
        newMonthlyStartDate = Timestamp.fromDate(monthlyStartDate);
      }

      // Check for new badges
      final badge50kWeekPrevious = (data['badge50kWeek'] as int?) ?? 0;
      final badge100kWeekPrevious = (data['badge100kWeek'] as int?) ?? 0;
      final badge100kMonthPrevious = (data['badge100kMonth'] as int?) ?? 0;
      final badge200kMonthPrevious = (data['badge200kMonth'] as int?) ?? 0;

      // Check weekly badges (only if crossed threshold this run)
      int new50kWeek = 0;
      int new100kWeek = 0;
      if (weeklyKm < 50 && newWeeklyKm >= 50) {
        new50kWeek = 1;
        await _notificationService.createBadgeNotification(
          userId: userId,
          badgeName: 'Weekly 50K',
          badgeDescription: 'You ran 50km this week!',
        );
      }
      if (weeklyKm < 100 && newWeeklyKm >= 100) {
        new100kWeek = 1;
        await _notificationService.createBadgeNotification(
          userId: userId,
          badgeName: 'Weekly 100K',
          badgeDescription: 'You ran 100km this week!',
        );
      }

      // Check monthly badges (only if crossed threshold this run)
      int new100kMonth = 0;
      int new200kMonth = 0;
      if (monthlyKm < 100 && newMonthlyKm >= 100) {
        new100kMonth = 1;
        await _notificationService.createBadgeNotification(
          userId: userId,
          badgeName: 'Monthly 100K',
          badgeDescription: 'You ran 100km this month!',
        );
      }
      if (monthlyKm < 200 && newMonthlyKm >= 200) {
        new200kMonth = 1;
        await _notificationService.createBadgeNotification(
          userId: userId,
          badgeName: 'Monthly 200K',
          badgeDescription: 'You ran 200km this month!',
        );
      }

      // Update Firestore
      final updateData = <String, dynamic>{
        'weeklyKm': newWeeklyKm,
        'weeklyStartDate': newWeeklyStartDate,
        'monthlyKm': newMonthlyKm,
        'monthlyStartDate': newMonthlyStartDate,
      };

      if (new50kWeek > 0) {
        updateData['badge50kWeek'] = badge50kWeekPrevious + new50kWeek;
      }
      if (new100kWeek > 0) {
        updateData['badge100kWeek'] = badge100kWeekPrevious + new100kWeek;
      }
      if (new100kMonth > 0) {
        updateData['badge100kMonth'] = badge100kMonthPrevious + new100kMonth;
      }
      if (new200kMonth > 0) {
        updateData['badge200kMonth'] = badge200kMonthPrevious + new200kMonth;
      }

      await userRef.set(updateData, SetOptions(merge: true));

      debugPrint('📊 Badge check complete: weekly=${newWeeklyKm}km, monthly=${newMonthlyKm}km');
    } catch (e) {
      debugPrint('❌ Error checking badges: $e');
    }
  }

  /// Get the start of the current week (Monday at midnight)
  DateTime _getWeekStart(DateTime date) {
    final daysFromMonday = date.weekday - 1; // Monday = 1
    final monday = date.subtract(Duration(days: daysFromMonday));
    return DateTime(monday.year, monday.month, monday.day);
  }

  /// Check if a new single-run badge was earned
  Future<void> checkSingleRunBadges({
    required String userId,
    required double distanceKm,
  }) async {
    // These are already handled by UserStatsService, but we can add notifications
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return;

      final data = doc.data()!;

      // Check if this is the first time earning each badge
      if (distanceKm >= 5.0 && (data['badge5k'] as int? ?? 0) == 1) {
        // First 5K badge
        await _notificationService.createBadgeNotification(
          userId: userId,
          badgeName: '5K Runner',
          badgeDescription: 'Your first 5km run completed!',
        );
      }

      if (distanceKm >= 10.0 && (data['badge10k'] as int? ?? 0) == 1) {
        // First 10K badge
        await _notificationService.createBadgeNotification(
          userId: userId,
          badgeName: '10K Runner',
          badgeDescription: 'Your first 10km run completed!',
        );
      }

      if (distanceKm >= 21.0975 && (data['badgeHalf'] as int? ?? 0) == 1) {
        // First half marathon
        await _notificationService.createBadgeNotification(
          userId: userId,
          badgeName: 'Half Marathon',
          badgeDescription: 'Your first half marathon completed!',
        );
      }

      if (distanceKm >= 42.195 && (data['badgeFull'] as int? ?? 0) == 1) {
        // First full marathon
        await _notificationService.createBadgeNotification(
          userId: userId,
          badgeName: 'Marathon',
          badgeDescription: 'Your first full marathon completed!',
        );
      }
    } catch (e) {
      debugPrint('❌ Error checking single run badges: $e');
    }
  }
}
