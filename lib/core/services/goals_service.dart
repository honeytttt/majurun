import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Weekly Goals Service
/// Manages user's weekly running targets and tracks progress
class GoalsService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  WeeklyGoal? _currentGoal;
  WeeklyGoal? get currentGoal => _currentGoal;

  double _weeklyProgress = 0.0;
  double get weeklyProgress => _weeklyProgress;

  int _runsThisWeek = 0;
  int get runsThisWeek => _runsThisWeek;

  double _distanceThisWeek = 0.0;
  double get distanceThisWeek => _distanceThisWeek;

  int _durationThisWeek = 0; // in minutes
  int get durationThisWeek => _durationThisWeek;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Initialize and load current goal
  Future<void> initialize() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _loadCurrentGoal(userId);
      await _calculateWeeklyProgress(userId);
    } catch (e) {
      debugPrint('Error initializing goals: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadCurrentGoal(String userId) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('goals')
        .doc('weekly')
        .get();

    if (doc.exists) {
      _currentGoal = WeeklyGoal.fromMap(doc.data()!);
    } else {
      // Create default goal
      _currentGoal = WeeklyGoal(
        distanceKm: 10.0,
        runsCount: 3,
        durationMinutes: 60,
        createdAt: DateTime.now(),
      );
      await saveGoal(_currentGoal!);
    }
  }

  Future<void> _calculateWeeklyProgress(String userId) async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekMidnight = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

    final runsQuery = await _firestore
        .collection('runs')
        .where('userId', isEqualTo: userId)
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeekMidnight))
        .get();

    _runsThisWeek = runsQuery.docs.length;
    _distanceThisWeek = 0.0;
    _durationThisWeek = 0;

    for (final doc in runsQuery.docs) {
      final data = doc.data();
      _distanceThisWeek += (data['distanceKm'] as num?)?.toDouble() ?? 0.0;
      _durationThisWeek += (data['durationMinutes'] as num?)?.toInt() ?? 0;
    }

    // Calculate overall progress (average of all metrics)
    if (_currentGoal != null) {
      final distanceProgress = (_distanceThisWeek / _currentGoal!.distanceKm).clamp(0.0, 1.0);
      final runsProgress = (_runsThisWeek / _currentGoal!.runsCount).clamp(0.0, 1.0);
      final durationProgress = (_durationThisWeek / _currentGoal!.durationMinutes).clamp(0.0, 1.0);
      _weeklyProgress = (distanceProgress + runsProgress + durationProgress) / 3;
    }
  }

  /// Save or update weekly goal
  Future<void> saveGoal(WeeklyGoal goal) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('goals')
        .doc('weekly')
        .set(goal.toMap());

    _currentGoal = goal;
    await _calculateWeeklyProgress(userId);
    notifyListeners();
  }

  /// Update goal with new values
  Future<void> updateGoal({
    double? distanceKm,
    int? runsCount,
    int? durationMinutes,
  }) async {
    if (_currentGoal == null) return;

    final updatedGoal = WeeklyGoal(
      distanceKm: distanceKm ?? _currentGoal!.distanceKm,
      runsCount: runsCount ?? _currentGoal!.runsCount,
      durationMinutes: durationMinutes ?? _currentGoal!.durationMinutes,
      createdAt: _currentGoal!.createdAt,
      updatedAt: DateTime.now(),
    );

    await saveGoal(updatedGoal);
  }

  /// Refresh progress data
  Future<void> refresh() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    await _calculateWeeklyProgress(userId);
    notifyListeners();
  }

  /// Get progress percentage for distance
  double get distanceProgressPercent {
    if (_currentGoal == null || _currentGoal!.distanceKm == 0) return 0;
    return (_distanceThisWeek / _currentGoal!.distanceKm * 100).clamp(0, 100);
  }

  /// Get progress percentage for runs
  double get runsProgressPercent {
    if (_currentGoal == null || _currentGoal!.runsCount == 0) return 0;
    return (_runsThisWeek / _currentGoal!.runsCount * 100).clamp(0, 100);
  }

  /// Get progress percentage for duration
  double get durationProgressPercent {
    if (_currentGoal == null || _currentGoal!.durationMinutes == 0) return 0;
    return (_durationThisWeek / _currentGoal!.durationMinutes * 100).clamp(0, 100);
  }

  /// Check if all goals are achieved
  bool get allGoalsAchieved {
    if (_currentGoal == null) return false;
    return _distanceThisWeek >= _currentGoal!.distanceKm &&
        _runsThisWeek >= _currentGoal!.runsCount &&
        _durationThisWeek >= _currentGoal!.durationMinutes;
  }
}

/// Weekly Goal Model
class WeeklyGoal {
  final double distanceKm;
  final int runsCount;
  final int durationMinutes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  WeeklyGoal({
    required this.distanceKm,
    required this.runsCount,
    required this.durationMinutes,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'distanceKm': distanceKm,
      'runsCount': runsCount,
      'durationMinutes': durationMinutes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory WeeklyGoal.fromMap(Map<String, dynamic> map) {
    return WeeklyGoal(
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 10.0,
      runsCount: (map['runsCount'] as num?)?.toInt() ?? 3,
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 60,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
