import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Streak Service
/// Tracks user's consecutive running days and provides motivation
class StreakService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _currentStreak = 0;
  int get currentStreak => _currentStreak;

  int _longestStreak = 0;
  int get longestStreak => _longestStreak;

  DateTime? _lastRunDate;
  DateTime? get lastRunDate => _lastRunDate;

  bool _ranToday = false;
  bool get ranToday => _ranToday;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  StreakData? _streakData;
  StreakData? get streakData => _streakData;

  /// Initialize and calculate current streak
  Future<void> initialize() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _loadStreakData(userId);
      await _calculateStreak(userId);
    } catch (e) {
      debugPrint('Error initializing streak: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadStreakData(String userId) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('stats')
        .doc('streak')
        .get();

    if (doc.exists) {
      _streakData = StreakData.fromMap(doc.data()!);
      _currentStreak = _streakData!.currentStreak;
      _longestStreak = _streakData!.longestStreak;
      _lastRunDate = _streakData!.lastRunDate;
    }
  }

  Future<void> _calculateStreak(String userId) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Check if user ran today
    final todayRuns = await _firestore
        .collection('runs')
        .where('userId', isEqualTo: userId)
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
        .limit(1)
        .get();

    _ranToday = todayRuns.docs.isNotEmpty;

    // If we have a last run date, check streak continuity
    if (_lastRunDate != null) {
      final lastRunDay = DateTime(_lastRunDate!.year, _lastRunDate!.month, _lastRunDate!.day);

      if (lastRunDay.isBefore(yesterday)) {
        // Streak broken - more than 1 day gap
        if (!_ranToday) {
          _currentStreak = 0;
        } else {
          _currentStreak = 1;
        }
      } else if (_ranToday && lastRunDay.isAtSameMomentAs(yesterday)) {
        // Continued streak
        _currentStreak++;
      }
    } else if (_ranToday) {
      _currentStreak = 1;
    }

    // Update longest streak
    if (_currentStreak > _longestStreak) {
      _longestStreak = _currentStreak;
    }

    // Save updated streak data
    await _saveStreakData(userId);
  }

  Future<void> _saveStreakData(String userId) async {
    final now = DateTime.now();

    _streakData = StreakData(
      currentStreak: _currentStreak,
      longestStreak: _longestStreak,
      lastRunDate: _ranToday ? now : _lastRunDate,
      updatedAt: now,
    );

    await _firestore
        .collection('users')
        .doc(userId)
        .collection('stats')
        .doc('streak')
        .set(_streakData!.toMap());
  }

  /// Record a run and update streak
  Future<void> recordRun() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (!_ranToday) {
      // Check if last run was yesterday (continuing streak) or earlier (starting new)
      if (_lastRunDate != null) {
        final lastRunDay = DateTime(_lastRunDate!.year, _lastRunDate!.month, _lastRunDate!.day);
        final yesterday = today.subtract(const Duration(days: 1));

        if (lastRunDay.isAtSameMomentAs(yesterday)) {
          _currentStreak++;
        } else if (lastRunDay.isBefore(yesterday)) {
          _currentStreak = 1;
        }
      } else {
        _currentStreak = 1;
      }

      _ranToday = true;
      _lastRunDate = now;

      if (_currentStreak > _longestStreak) {
        _longestStreak = _currentStreak;
      }

      await _saveStreakData(userId);
      notifyListeners();
    }
  }

  /// Get motivational message based on streak
  String get motivationalMessage {
    if (_currentStreak == 0) {
      return "Start your streak today!";
    } else if (_currentStreak == 1) {
      return "Great start! Keep going tomorrow!";
    } else if (_currentStreak < 7) {
      return "$_currentStreak days strong! Week goal in sight!";
    } else if (_currentStreak < 30) {
      return "Amazing $_currentStreak day streak! You're on fire!";
    } else if (_currentStreak < 100) {
      return "Incredible $_currentStreak days! You're unstoppable!";
    } else {
      return "Legendary $_currentStreak day streak! You're a champion!";
    }
  }

  /// Get streak status
  StreakStatus get status {
    if (_currentStreak == 0) return StreakStatus.none;
    if (!_ranToday) return StreakStatus.atRisk;
    return StreakStatus.active;
  }

  /// Refresh streak data
  Future<void> refresh() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    await _calculateStreak(userId);
    notifyListeners();
  }
}

/// Streak Data Model
class StreakData {
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastRunDate;
  final DateTime updatedAt;

  StreakData({
    required this.currentStreak,
    required this.longestStreak,
    this.lastRunDate,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'lastRunDate': lastRunDate != null ? Timestamp.fromDate(lastRunDate!) : null,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory StreakData.fromMap(Map<String, dynamic> map) {
    return StreakData(
      currentStreak: (map['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (map['longestStreak'] as num?)?.toInt() ?? 0,
      lastRunDate: (map['lastRunDate'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

enum StreakStatus {
  none,    // No streak
  atRisk,  // Has streak but hasn't run today
  active,  // Active streak with today's run
}
