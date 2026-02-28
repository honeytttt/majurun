import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Goals Service - Set and track weekly/monthly running goals
/// Like Strava's goal tracking with progress visualization
class GoalsService extends ChangeNotifier {
  static final GoalsService _instance = GoalsService._internal();
  factory GoalsService() => _instance;
  GoalsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userId;

  List<RunningGoal> _activeGoals = [];
  Map<String, GoalProgress> _progress = {};

  List<RunningGoal> get activeGoals => List.unmodifiable(_activeGoals);
  Map<String, GoalProgress> get progress => Map.unmodifiable(_progress);

  void setUserId(String? userId) {
    _userId = userId;
    if (userId != null) {
      _loadGoals();
    }
  }

  Future<void> _loadGoals() async {
    if (_userId == null) return;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('goals')
          .where('isActive', isEqualTo: true)
          .get();

      _activeGoals = snapshot.docs.map((doc) {
        final data = doc.data();
        return RunningGoal.fromMap(data, doc.id);
      }).toList();

      await _calculateAllProgress();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading goals: $e');
    }
  }

  Future<void> createGoal(RunningGoal goal) async {
    if (_userId == null) return;

    try {
      final docRef = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('goals')
          .add(goal.toMap());

      final newGoal = RunningGoal(
        id: docRef.id,
        type: goal.type,
        targetValue: goal.targetValue,
        period: goal.period,
        startDate: goal.startDate,
        endDate: goal.endDate,
        isActive: true,
      );

      _activeGoals.add(newGoal);
      await _calculateProgress(newGoal);
      notifyListeners();
    } catch (e) {
      debugPrint('Error creating goal: $e');
    }
  }

  Future<void> _calculateAllProgress() async {
    for (final goal in _activeGoals) {
      await _calculateProgress(goal);
    }
  }

  Future<void> _calculateProgress(RunningGoal goal) async {
    if (_userId == null) return;

    try {
      final now = DateTime.now();
      final periodStart = _getPeriodStart(goal.period, goal.startDate);
      final periodEnd = _getPeriodEnd(goal.period, periodStart);

      // Query runs within the period
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('runHistory')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(periodStart))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(periodEnd))
          .get();

      double currentValue = 0;
      int runCount = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        runCount++;

        switch (goal.type) {
          case GoalType.distance:
            currentValue += (data['distanceKm'] as num?)?.toDouble() ?? 0;
            break;
          case GoalType.duration:
            currentValue += (data['durationSeconds'] as num?)?.toDouble() ?? 0;
            break;
          case GoalType.runCount:
            currentValue += 1;
            break;
          case GoalType.elevation:
            currentValue += (data['elevationGain'] as num?)?.toDouble() ?? 0;
            break;
          case GoalType.calories:
            currentValue += (data['calories'] as num?)?.toDouble() ?? 0;
            break;
        }
      }

      final daysElapsed = now.difference(periodStart).inDays + 1;
      final totalDays = periodEnd.difference(periodStart).inDays + 1;
      final expectedProgress = (daysElapsed / totalDays) * goal.targetValue;

      _progress[goal.id] = GoalProgress(
        goalId: goal.id,
        currentValue: currentValue,
        targetValue: goal.targetValue,
        percentComplete: (currentValue / goal.targetValue * 100).clamp(0, 100),
        isOnTrack: currentValue >= expectedProgress,
        daysRemaining: periodEnd.difference(now).inDays,
        runCount: runCount,
        periodStart: periodStart,
        periodEnd: periodEnd,
      );
    } catch (e) {
      debugPrint('Error calculating goal progress: $e');
    }
  }

  DateTime _getPeriodStart(GoalPeriod period, DateTime goalStart) {
    final now = DateTime.now();
    switch (period) {
      case GoalPeriod.weekly:
        final daysFromMonday = now.weekday - 1;
        return DateTime(now.year, now.month, now.day - daysFromMonday);
      case GoalPeriod.monthly:
        return DateTime(now.year, now.month, 1);
      case GoalPeriod.yearly:
        return DateTime(now.year, 1, 1);
      case GoalPeriod.custom:
        return goalStart;
    }
  }

  DateTime _getPeriodEnd(GoalPeriod period, DateTime periodStart) {
    switch (period) {
      case GoalPeriod.weekly:
        return periodStart.add(const Duration(days: 6));
      case GoalPeriod.monthly:
        final nextMonth = DateTime(periodStart.year, periodStart.month + 1, 1);
        return nextMonth.subtract(const Duration(days: 1));
      case GoalPeriod.yearly:
        return DateTime(periodStart.year, 12, 31);
      case GoalPeriod.custom:
        return periodStart.add(const Duration(days: 30)); // Default 30 days
    }
  }

  Future<void> deleteGoal(String goalId) async {
    if (_userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('goals')
          .doc(goalId)
          .update({'isActive': false});

      _activeGoals.removeWhere((g) => g.id == goalId);
      _progress.remove(goalId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting goal: $e');
    }
  }

  /// Get suggested goals based on history
  Future<List<GoalSuggestion>> getSuggestedGoals() async {
    if (_userId == null) return [];

    try {
      // Get last 4 weeks of data
      final fourWeeksAgo = DateTime.now().subtract(const Duration(days: 28));
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('runHistory')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(fourWeeksAgo))
          .get();

      double totalDistance = 0;
      int totalDuration = 0;
      int runCount = snapshot.docs.length;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        totalDistance += (data['distanceKm'] as num?)?.toDouble() ?? 0;
        totalDuration += (data['durationSeconds'] as num?)?.toInt() ?? 0;
      }

      final weeklyAvgDistance = totalDistance / 4;
      final weeklyAvgRuns = runCount / 4;
      final weeklyAvgDuration = totalDuration / 4;

      List<GoalSuggestion> suggestions = [];

      // Suggest 10% increase in distance
      if (weeklyAvgDistance > 0) {
        suggestions.add(GoalSuggestion(
          type: GoalType.distance,
          period: GoalPeriod.weekly,
          suggestedValue: (weeklyAvgDistance * 1.1).roundToDouble(),
          reason: 'Based on your average of ${weeklyAvgDistance.toStringAsFixed(1)}km/week',
        ));
      }

      // Suggest maintaining run frequency
      if (weeklyAvgRuns > 0) {
        suggestions.add(GoalSuggestion(
          type: GoalType.runCount,
          period: GoalPeriod.weekly,
          suggestedValue: weeklyAvgRuns.ceilToDouble(),
          reason: 'Maintain your ${weeklyAvgRuns.toStringAsFixed(1)} runs per week',
        ));
      }

      // Suggest duration goal based on history
      if (weeklyAvgDuration > 0) {
        final hoursPerWeek = weeklyAvgDuration / 3600;
        suggestions.add(GoalSuggestion(
          type: GoalType.duration,
          period: GoalPeriod.weekly,
          suggestedValue: (hoursPerWeek * 1.1 * 3600).roundToDouble(),
          reason: 'Based on your ${hoursPerWeek.toStringAsFixed(1)} hours/week average',
        ));
      }

      // Standard monthly distance goals
      suggestions.add(GoalSuggestion(
        type: GoalType.distance,
        period: GoalPeriod.monthly,
        suggestedValue: 50,
        reason: 'A great starting monthly goal',
      ));

      suggestions.add(GoalSuggestion(
        type: GoalType.distance,
        period: GoalPeriod.monthly,
        suggestedValue: 100,
        reason: 'Challenge yourself with 100km month',
      ));

      return suggestions;
    } catch (e) {
      debugPrint('Error getting suggestions: $e');
      return [];
    }
  }

  /// Update goal progress after a run
  Future<void> onRunCompleted() async {
    await _calculateAllProgress();
    notifyListeners();
  }
}

// Data classes

enum GoalType {
  distance,
  duration,
  runCount,
  elevation,
  calories,
}

extension GoalTypeExtension on GoalType {
  String get name {
    switch (this) {
      case GoalType.distance:
        return 'Distance';
      case GoalType.duration:
        return 'Duration';
      case GoalType.runCount:
        return 'Run Count';
      case GoalType.elevation:
        return 'Elevation';
      case GoalType.calories:
        return 'Calories';
    }
  }

  String get unit {
    switch (this) {
      case GoalType.distance:
        return 'km';
      case GoalType.duration:
        return 'hours';
      case GoalType.runCount:
        return 'runs';
      case GoalType.elevation:
        return 'm';
      case GoalType.calories:
        return 'kcal';
    }
  }

  String formatValue(double value) {
    switch (this) {
      case GoalType.distance:
        return '${value.toStringAsFixed(1)} km';
      case GoalType.duration:
        final hours = (value / 3600).floor();
        final minutes = ((value % 3600) / 60).floor();
        return '${hours}h ${minutes}m';
      case GoalType.runCount:
        return '${value.toInt()} runs';
      case GoalType.elevation:
        return '${value.toInt()} m';
      case GoalType.calories:
        return '${value.toInt()} kcal';
    }
  }
}

enum GoalPeriod {
  weekly,
  monthly,
  yearly,
  custom,
}

extension GoalPeriodExtension on GoalPeriod {
  String get name {
    switch (this) {
      case GoalPeriod.weekly:
        return 'Weekly';
      case GoalPeriod.monthly:
        return 'Monthly';
      case GoalPeriod.yearly:
        return 'Yearly';
      case GoalPeriod.custom:
        return 'Custom';
    }
  }
}

class RunningGoal {
  final String id;
  final GoalType type;
  final double targetValue;
  final GoalPeriod period;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;

  const RunningGoal({
    required this.id,
    required this.type,
    required this.targetValue,
    required this.period,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
  });

  factory RunningGoal.fromMap(Map<String, dynamic> map, String id) {
    return RunningGoal(
      id: id,
      type: GoalType.values[map['type'] as int? ?? 0],
      targetValue: (map['targetValue'] as num?)?.toDouble() ?? 0,
      period: GoalPeriod.values[map['period'] as int? ?? 0],
      startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (map['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.index,
      'targetValue': targetValue,
      'period': period.index,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'isActive': isActive,
    };
  }
}

class GoalProgress {
  final String goalId;
  final double currentValue;
  final double targetValue;
  final double percentComplete;
  final bool isOnTrack;
  final int daysRemaining;
  final int runCount;
  final DateTime periodStart;
  final DateTime periodEnd;

  const GoalProgress({
    required this.goalId,
    required this.currentValue,
    required this.targetValue,
    required this.percentComplete,
    required this.isOnTrack,
    required this.daysRemaining,
    required this.runCount,
    required this.periodStart,
    required this.periodEnd,
  });
}

class GoalSuggestion {
  final GoalType type;
  final GoalPeriod period;
  final double suggestedValue;
  final String reason;

  const GoalSuggestion({
    required this.type,
    required this.period,
    required this.suggestedValue,
    required this.reason,
  });
}
