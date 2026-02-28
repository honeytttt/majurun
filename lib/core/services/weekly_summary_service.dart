import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Weekly Summary Service - Like Strava's Weekly Report
/// Generates weekly progress reports, comparisons, and insights
class WeeklySummaryService {
  static final WeeklySummaryService _instance = WeeklySummaryService._internal();
  factory WeeklySummaryService() => _instance;
  WeeklySummaryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  /// Generate weekly summary for the current week
  Future<WeeklySummary> getCurrentWeekSummary() async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return getWeekSummary(DateTime(weekStart.year, weekStart.month, weekStart.day));
  }

  /// Generate weekly summary for a specific week
  Future<WeeklySummary> getWeekSummary(DateTime weekStartDate) async {
    if (_userId == null) return WeeklySummary.empty(weekStartDate);

    final weekEnd = weekStartDate.add(const Duration(days: 7));

    try {
      // Get this week's runs
      final thisWeekSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('runHistory')
          .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStartDate))
          .where('completedAt', isLessThan: Timestamp.fromDate(weekEnd))
          .orderBy('completedAt')
          .get();

      // Get previous week's runs for comparison
      final prevWeekStart = weekStartDate.subtract(const Duration(days: 7));
      final prevWeekSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('runHistory')
          .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(prevWeekStart))
          .where('completedAt', isLessThan: Timestamp.fromDate(weekStartDate))
          .get();

      // Calculate this week's stats
      final thisWeekStats = _calculateWeekStats(thisWeekSnapshot.docs);
      final prevWeekStats = _calculateWeekStats(prevWeekSnapshot.docs);

      // Get all-time stats
      final allTimeStats = await _getAllTimeStats();

      // Calculate achievements for the week
      final achievements = await _calculateWeeklyAchievements(
        thisWeekStats,
        prevWeekStats,
        allTimeStats,
      );

      // Get personal bests this week
      final newPBs = await _getNewPBsThisWeek(weekStartDate, weekEnd);

      // Generate insights
      final insights = _generateInsights(thisWeekStats, prevWeekStats);

      // Calculate streak
      final streak = await _calculateStreak(weekStartDate);

      return WeeklySummary(
        weekStartDate: weekStartDate,
        totalRuns: thisWeekStats.runCount,
        totalDistanceKm: thisWeekStats.totalDistanceKm,
        totalDurationSeconds: thisWeekStats.totalDurationSeconds,
        totalCalories: thisWeekStats.totalCalories,
        averagePaceSecondsPerKm: thisWeekStats.avgPaceSecondsPerKm,
        longestRunKm: thisWeekStats.longestRunKm,
        fastestPaceSecondsPerKm: thisWeekStats.fastestPaceSecondsPerKm,
        elevationGainMeters: thisWeekStats.totalElevationGain,
        runsByDay: _getRunsByDay(thisWeekSnapshot.docs, weekStartDate),
        distanceChangePercent: _calculateChange(
          thisWeekStats.totalDistanceKm,
          prevWeekStats.totalDistanceKm,
        ),
        durationChangePercent: _calculateChange(
          thisWeekStats.totalDurationSeconds.toDouble(),
          prevWeekStats.totalDurationSeconds.toDouble(),
        ),
        runsChangePercent: _calculateChange(
          thisWeekStats.runCount.toDouble(),
          prevWeekStats.runCount.toDouble(),
        ),
        previousWeekDistanceKm: prevWeekStats.totalDistanceKm,
        previousWeekRuns: prevWeekStats.runCount,
        achievements: achievements,
        newPersonalBests: newPBs,
        insights: insights,
        currentStreak: streak,
        allTimeDistanceKm: allTimeStats.totalDistanceKm,
        allTimeRuns: allTimeStats.runCount,
      );
    } catch (e) {
      debugPrint('Error generating weekly summary: $e');
      return WeeklySummary.empty(weekStartDate);
    }
  }

  WeekStats _calculateWeekStats(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) {
      return WeekStats.empty();
    }

    double totalDistance = 0;
    int totalDuration = 0;
    int totalCalories = 0;
    double totalElevation = 0;
    double longestRun = 0;
    double fastestPace = double.infinity;

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final distance = (data['distanceKm'] as num?)?.toDouble() ?? 0;
      final duration = (data['durationSeconds'] as int?) ?? 0;
      final calories = (data['calories'] as int?) ?? 0;
      final elevation = (data['elevationGain'] as num?)?.toDouble() ?? 0;

      totalDistance += distance;
      totalDuration += duration;
      totalCalories += calories;
      totalElevation += elevation;

      if (distance > longestRun) longestRun = distance;

      if (distance > 0 && duration > 0) {
        final pace = duration / distance; // seconds per km
        if (pace < fastestPace) fastestPace = pace;
      }
    }

    final avgPace = totalDistance > 0 ? totalDuration / totalDistance : 0.0;

    return WeekStats(
      runCount: docs.length,
      totalDistanceKm: totalDistance,
      totalDurationSeconds: totalDuration,
      totalCalories: totalCalories,
      totalElevationGain: totalElevation,
      avgPaceSecondsPerKm: avgPace.toDouble(),
      longestRunKm: longestRun,
      fastestPaceSecondsPerKm: fastestPace == double.infinity ? 0 : fastestPace,
    );
  }

  Future<WeekStats> _getAllTimeStats() async {
    if (_userId == null) return WeekStats.empty();

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('runHistory')
          .get();

      return _calculateWeekStats(snapshot.docs);
    } catch (e) {
      return WeekStats.empty();
    }
  }

  Map<int, DayRuns> _getRunsByDay(List<QueryDocumentSnapshot> docs, DateTime weekStart) {
    final runsByDay = <int, DayRuns>{};

    // Initialize all days
    for (int i = 0; i < 7; i++) {
      runsByDay[i] = DayRuns(dayIndex: i, runs: 0, distanceKm: 0);
    }

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = data['completedAt'] as Timestamp?;
      if (timestamp == null) continue;

      final date = timestamp.toDate();
      final dayIndex = date.difference(weekStart).inDays;

      if (dayIndex >= 0 && dayIndex < 7) {
        final existing = runsByDay[dayIndex]!;
        runsByDay[dayIndex] = DayRuns(
          dayIndex: dayIndex,
          runs: existing.runs + 1,
          distanceKm: existing.distanceKm + ((data['distanceKm'] as num?)?.toDouble() ?? 0),
        );
      }
    }

    return runsByDay;
  }

  int _calculateChange(double current, double previous) {
    if (previous == 0) return current > 0 ? 100 : 0;
    return ((current - previous) / previous * 100).round();
  }

  Future<List<WeeklyAchievement>> _calculateWeeklyAchievements(
    WeekStats thisWeek,
    WeekStats prevWeek,
    WeekStats allTime,
  ) async {
    final achievements = <WeeklyAchievement>[];

    // Consistency achievement
    if (thisWeek.runCount >= 3) {
      achievements.add(WeeklyAchievement(
        type: AchievementType.consistency,
        title: 'Consistent Runner',
        description: 'Completed ${thisWeek.runCount} runs this week',
        icon: '🎯',
      ));
    }

    // Distance milestone
    if (thisWeek.totalDistanceKm >= 20) {
      achievements.add(WeeklyAchievement(
        type: AchievementType.distance,
        title: '20K Week',
        description: 'Ran over 20km this week!',
        icon: '🏅',
      ));
    }
    if (thisWeek.totalDistanceKm >= 50) {
      achievements.add(WeeklyAchievement(
        type: AchievementType.distance,
        title: '50K Week',
        description: 'Incredible! 50km in one week!',
        icon: '🏆',
      ));
    }

    // Improvement achievement
    if (thisWeek.totalDistanceKm > prevWeek.totalDistanceKm * 1.2) {
      achievements.add(WeeklyAchievement(
        type: AchievementType.improvement,
        title: 'Level Up',
        description: 'Increased distance by 20%+ vs last week',
        icon: '📈',
      ));
    }

    // Speed achievement
    if (thisWeek.fastestPaceSecondsPerKm > 0 &&
        prevWeek.fastestPaceSecondsPerKm > 0 &&
        thisWeek.fastestPaceSecondsPerKm < prevWeek.fastestPaceSecondsPerKm) {
      achievements.add(WeeklyAchievement(
        type: AchievementType.speed,
        title: 'Speed Demon',
        description: 'Set a new fastest pace this week!',
        icon: '⚡',
      ));
    }

    // Long run achievement
    if (thisWeek.longestRunKm >= 10) {
      achievements.add(WeeklyAchievement(
        type: AchievementType.endurance,
        title: 'Long Hauler',
        description: 'Completed a 10K+ run',
        icon: '🦵',
      ));
    }
    if (thisWeek.longestRunKm >= 21) {
      achievements.add(WeeklyAchievement(
        type: AchievementType.endurance,
        title: 'Half Marathon',
        description: 'Ran a half marathon distance!',
        icon: '🏃',
      ));
    }

    return achievements;
  }

  Future<List<String>> _getNewPBsThisWeek(DateTime weekStart, DateTime weekEnd) async {
    if (_userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('personalRecords')
          .where('achievedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .where('achievedAt', isLessThan: Timestamp.fromDate(weekEnd))
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return data['distanceName'] as String? ?? doc.id;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  List<WeeklyInsight> _generateInsights(WeekStats thisWeek, WeekStats prevWeek) {
    final insights = <WeeklyInsight>[];

    // Distance insight
    if (thisWeek.totalDistanceKm > 0) {
      final change = _calculateChange(thisWeek.totalDistanceKm, prevWeek.totalDistanceKm);
      if (change > 20) {
        insights.add(WeeklyInsight(
          type: InsightType.positive,
          title: 'Great progress!',
          message: 'Your distance is up ${change}% from last week. Keep it up!',
        ));
      } else if (change < -20) {
        insights.add(WeeklyInsight(
          type: InsightType.neutral,
          title: 'Rest week?',
          message: 'Your distance dropped ${-change}% - recovery is important too!',
        ));
      }
    }

    // Consistency insight
    if (thisWeek.runCount >= prevWeek.runCount && thisWeek.runCount >= 3) {
      insights.add(WeeklyInsight(
        type: InsightType.positive,
        title: 'Staying consistent',
        message: 'You\'re maintaining a solid running routine.',
      ));
    }

    // Pace insight
    if (thisWeek.avgPaceSecondsPerKm > 0 && prevWeek.avgPaceSecondsPerKm > 0) {
      if (thisWeek.avgPaceSecondsPerKm < prevWeek.avgPaceSecondsPerKm * 0.95) {
        insights.add(WeeklyInsight(
          type: InsightType.positive,
          title: 'Getting faster!',
          message: 'Your average pace improved this week.',
        ));
      }
    }

    // Add motivation if no runs
    if (thisWeek.runCount == 0) {
      insights.add(WeeklyInsight(
        type: InsightType.motivation,
        title: 'Ready for a run?',
        message: 'Every journey starts with a single step. Let\'s go!',
      ));
    }

    return insights;
  }

  Future<int> _calculateStreak(DateTime weekStart) async {
    if (_userId == null) return 0;

    try {
      int streak = 0;
      DateTime checkDate = weekStart;

      while (true) {
        final dayStart = DateTime(checkDate.year, checkDate.month, checkDate.day);
        final dayEnd = dayStart.add(const Duration(days: 1));

        final snapshot = await _firestore
            .collection('users')
            .doc(_userId)
            .collection('runHistory')
            .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
            .where('completedAt', isLessThan: Timestamp.fromDate(dayEnd))
            .limit(1)
            .get();

        if (snapshot.docs.isEmpty) break;

        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));

        // Safety limit
        if (streak > 365) break;
      }

      return streak;
    } catch (e) {
      return 0;
    }
  }

  /// Get historical weekly summaries (for graphs)
  Future<List<WeeklySummary>> getWeeklyHistory({int weeks = 12}) async {
    final summaries = <WeeklySummary>[];
    final now = DateTime.now();

    for (int i = 0; i < weeks; i++) {
      final weekStart = now.subtract(Duration(days: now.weekday - 1 + (i * 7)));
      final summary = await getWeekSummary(
        DateTime(weekStart.year, weekStart.month, weekStart.day),
      );
      summaries.add(summary);
    }

    return summaries.reversed.toList();
  }
}

// Data classes

class WeekStats {
  final int runCount;
  final double totalDistanceKm;
  final int totalDurationSeconds;
  final int totalCalories;
  final double totalElevationGain;
  final double avgPaceSecondsPerKm;
  final double longestRunKm;
  final double fastestPaceSecondsPerKm;

  WeekStats({
    required this.runCount,
    required this.totalDistanceKm,
    required this.totalDurationSeconds,
    required this.totalCalories,
    required this.totalElevationGain,
    required this.avgPaceSecondsPerKm,
    required this.longestRunKm,
    required this.fastestPaceSecondsPerKm,
  });

  factory WeekStats.empty() => WeekStats(
    runCount: 0,
    totalDistanceKm: 0,
    totalDurationSeconds: 0,
    totalCalories: 0,
    totalElevationGain: 0,
    avgPaceSecondsPerKm: 0,
    longestRunKm: 0,
    fastestPaceSecondsPerKm: 0,
  );
}

class WeeklySummary {
  final DateTime weekStartDate;
  final int totalRuns;
  final double totalDistanceKm;
  final int totalDurationSeconds;
  final int totalCalories;
  final double averagePaceSecondsPerKm;
  final double longestRunKm;
  final double fastestPaceSecondsPerKm;
  final double elevationGainMeters;
  final Map<int, DayRuns> runsByDay;
  final int distanceChangePercent;
  final int durationChangePercent;
  final int runsChangePercent;
  final double previousWeekDistanceKm;
  final int previousWeekRuns;
  final List<WeeklyAchievement> achievements;
  final List<String> newPersonalBests;
  final List<WeeklyInsight> insights;
  final int currentStreak;
  final double allTimeDistanceKm;
  final int allTimeRuns;

  WeeklySummary({
    required this.weekStartDate,
    required this.totalRuns,
    required this.totalDistanceKm,
    required this.totalDurationSeconds,
    required this.totalCalories,
    required this.averagePaceSecondsPerKm,
    required this.longestRunKm,
    required this.fastestPaceSecondsPerKm,
    required this.elevationGainMeters,
    required this.runsByDay,
    required this.distanceChangePercent,
    required this.durationChangePercent,
    required this.runsChangePercent,
    required this.previousWeekDistanceKm,
    required this.previousWeekRuns,
    required this.achievements,
    required this.newPersonalBests,
    required this.insights,
    required this.currentStreak,
    required this.allTimeDistanceKm,
    required this.allTimeRuns,
  });

  factory WeeklySummary.empty(DateTime weekStart) => WeeklySummary(
    weekStartDate: weekStart,
    totalRuns: 0,
    totalDistanceKm: 0,
    totalDurationSeconds: 0,
    totalCalories: 0,
    averagePaceSecondsPerKm: 0,
    longestRunKm: 0,
    fastestPaceSecondsPerKm: 0,
    elevationGainMeters: 0,
    runsByDay: {},
    distanceChangePercent: 0,
    durationChangePercent: 0,
    runsChangePercent: 0,
    previousWeekDistanceKm: 0,
    previousWeekRuns: 0,
    achievements: [],
    newPersonalBests: [],
    insights: [],
    currentStreak: 0,
    allTimeDistanceKm: 0,
    allTimeRuns: 0,
  );

  String get formattedDuration {
    final hours = totalDurationSeconds ~/ 3600;
    final minutes = (totalDurationSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String get formattedPace {
    if (averagePaceSecondsPerKm <= 0) return '--:--';
    final mins = (averagePaceSecondsPerKm / 60).floor();
    final secs = (averagePaceSecondsPerKm % 60).round();
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  String get weekRangeString {
    final weekEnd = weekStartDate.add(const Duration(days: 6));
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    if (weekStartDate.month == weekEnd.month) {
      return '${months[weekStartDate.month - 1]} ${weekStartDate.day}-${weekEnd.day}';
    }
    return '${months[weekStartDate.month - 1]} ${weekStartDate.day} - ${months[weekEnd.month - 1]} ${weekEnd.day}';
  }
}

class DayRuns {
  final int dayIndex;
  final int runs;
  final double distanceKm;

  DayRuns({
    required this.dayIndex,
    required this.runs,
    required this.distanceKm,
  });

  String get dayName {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dayIndex];
  }
}

enum AchievementType {
  consistency,
  distance,
  improvement,
  speed,
  endurance,
}

class WeeklyAchievement {
  final AchievementType type;
  final String title;
  final String description;
  final String icon;

  WeeklyAchievement({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
  });
}

enum InsightType {
  positive,
  neutral,
  motivation,
}

class WeeklyInsight {
  final InsightType type;
  final String title;
  final String message;

  WeeklyInsight({
    required this.type,
    required this.title,
    required this.message,
  });
}
