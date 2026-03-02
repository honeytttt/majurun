import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'push_notification_service.dart';

/// Achievement Service - Milestones, badges, and notifications
/// Tracks running achievements and sends celebratory notifications
class AchievementService extends ChangeNotifier {
  static final AchievementService _instance = AchievementService._internal();
  factory AchievementService() => _instance;
  AchievementService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PushNotificationService _pushService = PushNotificationService();

  List<Achievement> _unlockedAchievements = [];
  List<Achievement> _allAchievements = [];

  List<Achievement> get unlockedAchievements => List.unmodifiable(_unlockedAchievements);
  List<Achievement> get allAchievements => List.unmodifiable(_allAchievements);
  List<Achievement> get lockedAchievements =>
      _allAchievements.where((a) => !_unlockedAchievements.any((u) => u.id == a.id)).toList();

  /// Initialize achievement definitions
  void initialize() {
    _allAchievements = _getAchievementDefinitions();
  }

  /// Check and award achievements after a run
  Future<List<Achievement>> checkAchievements({
    required double totalDistanceKm,
    required int totalRuns,
    required int currentStreak,
    required double runDistanceKm,
    required int runDurationSeconds,
    required double avgPaceSecondsPerKm,
    int? elevationGain,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    final newAchievements = <Achievement>[];

    // Load already unlocked achievements
    await _loadUnlockedAchievements(userId);

    // Check each achievement
    for (final achievement in _allAchievements) {
      // Skip if already unlocked
      if (_unlockedAchievements.any((a) => a.id == achievement.id)) continue;

      bool unlocked = false;

      switch (achievement.type) {
        case AchievementType.totalDistance:
          unlocked = totalDistanceKm >= achievement.threshold;
          break;

        case AchievementType.singleRun:
          unlocked = runDistanceKm >= achievement.threshold;
          break;

        case AchievementType.totalRuns:
          unlocked = totalRuns >= achievement.threshold;
          break;

        case AchievementType.streak:
          unlocked = currentStreak >= achievement.threshold;
          break;

        case AchievementType.pace:
          // Pace is in seconds/km, lower is better
          unlocked = avgPaceSecondsPerKm > 0 &&
              avgPaceSecondsPerKm <= achievement.threshold &&
              runDistanceKm >= 1.0; // Minimum 1km to count
          break;

        case AchievementType.elevation:
          if (elevationGain != null) {
            unlocked = elevationGain >= achievement.threshold;
          }
          break;

        case AchievementType.duration:
          unlocked = runDurationSeconds >= achievement.threshold;
          break;

        case AchievementType.special:
          // Handle special achievements
          unlocked = await _checkSpecialAchievement(achievement, userId);
          break;
      }

      if (unlocked) {
        await _unlockAchievement(userId, achievement);
        newAchievements.add(achievement);
      }
    }

    // Send notifications for new achievements
    for (final achievement in newAchievements) {
      await _sendAchievementNotification(achievement);
    }

    return newAchievements;
  }

  /// Load unlocked achievements from Firestore
  Future<void> _loadUnlockedAchievements(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('achievements')
          .get();

      _unlockedAchievements = snapshot.docs.map((doc) {
        final data = doc.data();
        final definition = _allAchievements.firstWhere(
          (a) => a.id == doc.id,
          orElse: () => Achievement(
            id: doc.id,
            name: data['name'] ?? 'Achievement',
            description: data['description'] ?? '',
            icon: data['icon'] ?? '🏆',
            type: AchievementType.special,
            threshold: 0,
            tier: AchievementTier.bronze,
          ),
        );
        return definition.copyWith(
          unlockedAt: (data['unlockedAt'] as Timestamp?)?.toDate(),
        );
      }).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading achievements: $e');
    }
  }

  /// Unlock an achievement
  Future<void> _unlockAchievement(String userId, Achievement achievement) async {
    try {
      final unlockedAt = DateTime.now();

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('achievements')
          .doc(achievement.id)
          .set({
        'name': achievement.name,
        'description': achievement.description,
        'icon': achievement.icon,
        'tier': achievement.tier.name,
        'type': achievement.type.name,
        'unlockedAt': Timestamp.fromDate(unlockedAt),
      });

      // Update user's achievement count
      await _firestore.collection('users').doc(userId).update({
        'achievementCount': FieldValue.increment(1),
      });

      _unlockedAchievements.add(achievement.copyWith(unlockedAt: unlockedAt));
      notifyListeners();

      debugPrint('Achievement unlocked: ${achievement.name}');
    } catch (e) {
      debugPrint('Error unlocking achievement: $e');
    }
  }

  /// Send achievement notification
  Future<void> _sendAchievementNotification(Achievement achievement) async {
    await _pushService.showAchievementNotification(
      title: "Achievement Unlocked! ${achievement.icon}",
      body: achievement.name,
      achievementId: achievement.id,
    );
  }

  /// Check special achievements
  Future<bool> _checkSpecialAchievement(Achievement achievement, String userId) async {
    switch (achievement.id) {
      case 'early_bird':
        // Run before 6 AM
        final hour = DateTime.now().hour;
        return hour < 6;

      case 'night_owl':
        // Run after 10 PM
        final hour = DateTime.now().hour;
        return hour >= 22;

      case 'weekend_warrior':
        // Run on both Saturday and Sunday in the same week
        return await _checkWeekendWarrior(userId);

      case 'social_butterfly':
        // Have 10+ followers
        return await _checkFollowerCount(userId, 10);

      case 'century_club':
        // Complete 100 runs
        return await _checkRunCount(userId, 100);

      default:
        return false;
    }
  }

  Future<bool> _checkWeekendWarrior(String userId) async {
    try {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final saturday = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day + 5);
      final sunday = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day + 6);

      final runs = await _firestore
          .collection('users')
          .doc(userId)
          .collection('runHistory')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(saturday))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(sunday.add(const Duration(days: 1))))
          .get();

      bool hasSaturday = false;
      bool hasSunday = false;

      for (final doc in runs.docs) {
        final timestamp = (doc.data()['timestamp'] as Timestamp).toDate();
        if (timestamp.weekday == 6) hasSaturday = true;
        if (timestamp.weekday == 7) hasSunday = true;
      }

      return hasSaturday && hasSunday;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkFollowerCount(String userId, int threshold) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final followersCount = doc.data()?['followersCount'] as int? ?? 0;
      return followersCount >= threshold;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkRunCount(String userId, int threshold) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final runCount = doc.data()?['workoutsCount'] as int? ?? 0;
      return runCount >= threshold;
    } catch (e) {
      return false;
    }
  }

  /// Get achievement definitions
  List<Achievement> _getAchievementDefinitions() {
    return [
      // ==================== DISTANCE MILESTONES ====================
      // Single Run
      const Achievement(
        id: 'first_5k',
        name: 'First 5K',
        description: 'Complete your first 5 kilometer run',
        icon: '🎯',
        type: AchievementType.singleRun,
        threshold: 5.0,
        tier: AchievementTier.bronze,
      ),
      const Achievement(
        id: 'first_10k',
        name: 'First 10K',
        description: 'Complete your first 10 kilometer run',
        icon: '🏃',
        type: AchievementType.singleRun,
        threshold: 10.0,
        tier: AchievementTier.silver,
      ),
      const Achievement(
        id: 'half_marathon',
        name: 'Half Marathon',
        description: 'Run 21.1 kilometers in a single run',
        icon: '🏅',
        type: AchievementType.singleRun,
        threshold: 21.1,
        tier: AchievementTier.gold,
      ),
      const Achievement(
        id: 'marathon',
        name: 'Marathon',
        description: 'Run 42.2 kilometers in a single run',
        icon: '🏆',
        type: AchievementType.singleRun,
        threshold: 42.2,
        tier: AchievementTier.platinum,
      ),
      const Achievement(
        id: 'ultra',
        name: 'Ultramarathon',
        description: 'Run 50+ kilometers in a single run',
        icon: '💎',
        type: AchievementType.singleRun,
        threshold: 50.0,
        tier: AchievementTier.diamond,
      ),

      // Total Distance
      const Achievement(
        id: 'total_50k',
        name: '50K Club',
        description: 'Run 50 kilometers total',
        icon: '🌟',
        type: AchievementType.totalDistance,
        threshold: 50.0,
        tier: AchievementTier.bronze,
      ),
      const Achievement(
        id: 'total_100k',
        name: '100K Club',
        description: 'Run 100 kilometers total',
        icon: '💯',
        type: AchievementType.totalDistance,
        threshold: 100.0,
        tier: AchievementTier.silver,
      ),
      const Achievement(
        id: 'total_500k',
        name: '500K Club',
        description: 'Run 500 kilometers total',
        icon: '🔥',
        type: AchievementType.totalDistance,
        threshold: 500.0,
        tier: AchievementTier.gold,
      ),
      const Achievement(
        id: 'total_1000k',
        name: '1000K Club',
        description: 'Run 1000 kilometers total',
        icon: '👑',
        type: AchievementType.totalDistance,
        threshold: 1000.0,
        tier: AchievementTier.platinum,
      ),

      // ==================== RUN COUNT ====================
      const Achievement(
        id: 'first_run',
        name: 'First Steps',
        description: 'Complete your first run',
        icon: '👟',
        type: AchievementType.totalRuns,
        threshold: 1,
        tier: AchievementTier.bronze,
      ),
      const Achievement(
        id: 'ten_runs',
        name: 'Getting Started',
        description: 'Complete 10 runs',
        icon: '🎯',
        type: AchievementType.totalRuns,
        threshold: 10,
        tier: AchievementTier.bronze,
      ),
      const Achievement(
        id: 'fifty_runs',
        name: 'Dedicated Runner',
        description: 'Complete 50 runs',
        icon: '💪',
        type: AchievementType.totalRuns,
        threshold: 50,
        tier: AchievementTier.silver,
      ),
      const Achievement(
        id: 'hundred_runs',
        name: 'Century Club',
        description: 'Complete 100 runs',
        icon: '🎖️',
        type: AchievementType.totalRuns,
        threshold: 100,
        tier: AchievementTier.gold,
      ),

      // ==================== STREAK ====================
      const Achievement(
        id: 'streak_3',
        name: 'Hat Trick',
        description: 'Run 3 days in a row',
        icon: '🎩',
        type: AchievementType.streak,
        threshold: 3,
        tier: AchievementTier.bronze,
      ),
      const Achievement(
        id: 'streak_7',
        name: 'Week Warrior',
        description: 'Run 7 days in a row',
        icon: '📅',
        type: AchievementType.streak,
        threshold: 7,
        tier: AchievementTier.silver,
      ),
      const Achievement(
        id: 'streak_30',
        name: 'Monthly Master',
        description: 'Run 30 days in a row',
        icon: '🗓️',
        type: AchievementType.streak,
        threshold: 30,
        tier: AchievementTier.gold,
      ),
      const Achievement(
        id: 'streak_100',
        name: 'Unstoppable',
        description: 'Run 100 days in a row',
        icon: '⚡',
        type: AchievementType.streak,
        threshold: 100,
        tier: AchievementTier.platinum,
      ),

      // ==================== PACE ====================
      const Achievement(
        id: 'pace_6',
        name: 'Sub-6 Pace',
        description: 'Run faster than 6:00/km',
        icon: '⏱️',
        type: AchievementType.pace,
        threshold: 360, // 6:00 in seconds
        tier: AchievementTier.bronze,
      ),
      const Achievement(
        id: 'pace_5',
        name: 'Sub-5 Pace',
        description: 'Run faster than 5:00/km',
        icon: '🚀',
        type: AchievementType.pace,
        threshold: 300, // 5:00 in seconds
        tier: AchievementTier.silver,
      ),
      const Achievement(
        id: 'pace_4',
        name: 'Sub-4 Pace',
        description: 'Run faster than 4:00/km',
        icon: '💨',
        type: AchievementType.pace,
        threshold: 240, // 4:00 in seconds
        tier: AchievementTier.gold,
      ),

      // ==================== ELEVATION ====================
      const Achievement(
        id: 'elevation_500',
        name: 'Hill Climber',
        description: 'Gain 500m elevation in a single run',
        icon: '⛰️',
        type: AchievementType.elevation,
        threshold: 500,
        tier: AchievementTier.silver,
      ),
      const Achievement(
        id: 'elevation_1000',
        name: 'Mountain Goat',
        description: 'Gain 1000m elevation in a single run',
        icon: '🏔️',
        type: AchievementType.elevation,
        threshold: 1000,
        tier: AchievementTier.gold,
      ),

      // ==================== DURATION ====================
      const Achievement(
        id: 'hour_run',
        name: 'Hour Power',
        description: 'Run for 60+ minutes',
        icon: '⏰',
        type: AchievementType.duration,
        threshold: 3600, // 1 hour in seconds
        tier: AchievementTier.silver,
      ),
      const Achievement(
        id: 'two_hour_run',
        name: 'Endurance Beast',
        description: 'Run for 2+ hours',
        icon: '🦁',
        type: AchievementType.duration,
        threshold: 7200, // 2 hours in seconds
        tier: AchievementTier.gold,
      ),

      // ==================== SPECIAL ====================
      const Achievement(
        id: 'early_bird',
        name: 'Early Bird',
        description: 'Complete a run before 6 AM',
        icon: '🌅',
        type: AchievementType.special,
        threshold: 0,
        tier: AchievementTier.bronze,
      ),
      const Achievement(
        id: 'night_owl',
        name: 'Night Owl',
        description: 'Complete a run after 10 PM',
        icon: '🌙',
        type: AchievementType.special,
        threshold: 0,
        tier: AchievementTier.bronze,
      ),
      const Achievement(
        id: 'weekend_warrior',
        name: 'Weekend Warrior',
        description: 'Run on both Saturday and Sunday',
        icon: '🎉',
        type: AchievementType.special,
        threshold: 0,
        tier: AchievementTier.silver,
      ),
      const Achievement(
        id: 'social_butterfly',
        name: 'Social Butterfly',
        description: 'Gain 10 followers',
        icon: '🦋',
        type: AchievementType.special,
        threshold: 10,
        tier: AchievementTier.silver,
      ),
    ];
  }

  /// Get user's achievement progress
  Future<Map<String, dynamic>> getAchievementProgress(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data() ?? {};

      return {
        'totalDistanceKm': (data['totalKm'] as num?)?.toDouble() ?? 0.0,
        'totalRuns': data['workoutsCount'] as int? ?? 0,
        'currentStreak': data['currentStreak'] as int? ?? 0,
        'achievementCount': data['achievementCount'] as int? ?? 0,
      };
    } catch (e) {
      return {
        'totalDistanceKm': 0.0,
        'totalRuns': 0,
        'currentStreak': 0,
        'achievementCount': 0,
      };
    }
  }
}

/// Achievement data class
class Achievement {
  final String id;
  final String name;
  final String description;
  final String icon;
  final AchievementType type;
  final double threshold;
  final AchievementTier tier;
  final DateTime? unlockedAt;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.type,
    required this.threshold,
    required this.tier,
    this.unlockedAt,
  });

  Achievement copyWith({DateTime? unlockedAt}) {
    return Achievement(
      id: id,
      name: name,
      description: description,
      icon: icon,
      type: type,
      threshold: threshold,
      tier: tier,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }

  bool get isUnlocked => unlockedAt != null;
}

/// Achievement types
enum AchievementType {
  totalDistance,
  singleRun,
  totalRuns,
  streak,
  pace,
  elevation,
  duration,
  special,
}

/// Achievement tiers
enum AchievementTier {
  bronze,
  silver,
  gold,
  platinum,
  diamond,
}

extension AchievementTierExtension on AchievementTier {
  String get displayName {
    switch (this) {
      case AchievementTier.bronze:
        return 'Bronze';
      case AchievementTier.silver:
        return 'Silver';
      case AchievementTier.gold:
        return 'Gold';
      case AchievementTier.platinum:
        return 'Platinum';
      case AchievementTier.diamond:
        return 'Diamond';
    }
  }

  int get points {
    switch (this) {
      case AchievementTier.bronze:
        return 10;
      case AchievementTier.silver:
        return 25;
      case AchievementTier.gold:
        return 50;
      case AchievementTier.platinum:
        return 100;
      case AchievementTier.diamond:
        return 200;
    }
  }
}
