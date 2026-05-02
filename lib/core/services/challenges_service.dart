import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Challenges Service - Monthly/weekly challenges like Strava
/// Compete with friends and global community
class ChallengesService extends ChangeNotifier {
  static final ChallengesService _instance = ChallengesService._internal();
  factory ChallengesService() => _instance;
  ChallengesService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userId;

  List<Challenge> _activeChallenges = [];
  List<Challenge> _joinedChallenges = [];
  List<Challenge> _completedChallenges = [];
  final Map<String, ChallengeProgress> _progress = {};

  List<Challenge> get activeChallenges => List.unmodifiable(_activeChallenges);
  List<Challenge> get joinedChallenges => List.unmodifiable(_joinedChallenges);
  List<Challenge> get completedChallenges => List.unmodifiable(_completedChallenges);
  Map<String, ChallengeProgress> get progress => Map.unmodifiable(_progress);

  void setUserId(String? userId) {
    _userId = userId;
    if (userId != null) {
      _loadChallenges();
    }
  }

  Future<void> _loadChallenges() async {
    if (_userId == null) return;

    try {
      // Load active global challenges
      final now = Timestamp.now();
      final activeSnapshot = await _firestore
          .collection('challenges')
          .where('endDate', isGreaterThan: now)
          .where('startDate', isLessThanOrEqualTo: now)
          .get();

      _activeChallenges = activeSnapshot.docs.map((doc) {
        return Challenge.fromMap(doc.data(), doc.id);
      }).toList();

      // Load user's joined challenges
      final joinedSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('joinedChallenges')
          .get();

      final joinedIds = joinedSnapshot.docs.map((d) => d.id).toSet();

      _joinedChallenges = _activeChallenges.where((c) => joinedIds.contains(c.id)).toList();

      // Load completed challenges
      final completedSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('completedChallenges')
          .orderBy('completedAt', descending: true)
          .limit(20)
          .get();

      _completedChallenges = [];
      for (final doc in completedSnapshot.docs) {
        final challengeDoc = await _firestore.collection('challenges').doc(doc.id).get();
        if (challengeDoc.exists) {
          _completedChallenges.add(Challenge.fromMap(challengeDoc.data()!, challengeDoc.id));
        }
      }

      // Load progress for joined challenges
      for (final challenge in _joinedChallenges) {
        await _loadProgress(challenge);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading challenges: $e');
    }
  }

  Future<void> _loadProgress(Challenge challenge) async {
    if (_userId == null) return;

    try {
      // Get runs within challenge period (limit to prevent excessive reads)
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('runHistory')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(challenge.startDate))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(challenge.endDate))
          .limit(500) // Max runs per challenge period
          .get();

      double currentValue = 0;
      int runCount = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        runCount++;

        switch (challenge.type) {
          case ChallengeType.totalDistance:
            currentValue += (data['distanceKm'] as num?)?.toDouble() ?? 0;
            break;
          case ChallengeType.longestRun:
            final distance = (data['distanceKm'] as num?)?.toDouble() ?? 0;
            if (distance > currentValue) currentValue = distance;
            break;
          case ChallengeType.runCount:
            currentValue += 1;
            break;
          case ChallengeType.totalElevation:
            currentValue += (data['elevationGain'] as num?)?.toDouble() ?? 0;
            break;
          case ChallengeType.totalTime:
            currentValue += (data['durationSeconds'] as num?)?.toDouble() ?? 0;
            break;
          case ChallengeType.streak:
            // Handled separately
            break;
        }
      }

      // Handle streak calculation
      if (challenge.type == ChallengeType.streak) {
        currentValue = await _calculateStreak(challenge.startDate, challenge.endDate);
      }

      final isCompleted = currentValue >= challenge.targetValue;

      _progress[challenge.id] = ChallengeProgress(
        challengeId: challenge.id,
        currentValue: currentValue,
        targetValue: challenge.targetValue,
        percentComplete: (currentValue / challenge.targetValue * 100).clamp(0, 100),
        runCount: runCount,
        isCompleted: isCompleted,
      );

      // Mark as completed if achieved
      if (isCompleted && !_completedChallenges.any((c) => c.id == challenge.id)) {
        await _markCompleted(challenge.id);
      }
    } catch (e) {
      debugPrint('Error loading challenge progress: $e');
    }
  }

  Future<double> _calculateStreak(DateTime start, DateTime end) async {
    if (_userId == null) return 0;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('runHistory')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .orderBy('timestamp')
          .limit(500) // Limit for streak calculation
          .get();

      if (snapshot.docs.isEmpty) return 0;

      Set<String> runDates = {};
      for (final doc in snapshot.docs) {
        final ts = (doc.data()['timestamp'] as Timestamp?)?.toDate();
        if (ts != null) {
          runDates.add('${ts.year}-${ts.month}-${ts.day}');
        }
      }

      // Calculate longest consecutive streak
      int maxStreak = 0;
      int currentStreak = 0;
      DateTime checkDate = start;

      while (!checkDate.isAfter(end)) {
        final dateStr = '${checkDate.year}-${checkDate.month}-${checkDate.day}';
        if (runDates.contains(dateStr)) {
          currentStreak++;
          if (currentStreak > maxStreak) maxStreak = currentStreak;
        } else {
          currentStreak = 0;
        }
        checkDate = checkDate.add(const Duration(days: 1));
      }

      return maxStreak.toDouble();
    } catch (e) {
      debugPrint('Error calculating streak: $e');
      return 0;
    }
  }

  /// Join a challenge
  Future<void> joinChallenge(String challengeId) async {
    if (_userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('joinedChallenges')
          .doc(challengeId)
          .set({
        'joinedAt': FieldValue.serverTimestamp(),
      });

      // Increment participant count
      await _firestore.collection('challenges').doc(challengeId).update({
        'participantCount': FieldValue.increment(1),
      });

      final challenge = _activeChallenges.firstWhere((c) => c.id == challengeId);
      _joinedChallenges.add(challenge);
      await _loadProgress(challenge);

      notifyListeners();
    } catch (e) {
      debugPrint('Error joining challenge: $e');
    }
  }

  /// Leave a challenge
  Future<void> leaveChallenge(String challengeId) async {
    if (_userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('joinedChallenges')
          .doc(challengeId)
          .delete();

      // Decrement participant count
      await _firestore.collection('challenges').doc(challengeId).update({
        'participantCount': FieldValue.increment(-1),
      });

      _joinedChallenges.removeWhere((c) => c.id == challengeId);
      _progress.remove(challengeId);

      notifyListeners();
    } catch (e) {
      debugPrint('Error leaving challenge: $e');
    }
  }

  Future<void> _markCompleted(String challengeId) async {
    if (_userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('completedChallenges')
          .doc(challengeId)
          .set({
        'completedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error marking challenge completed: $e');
    }
  }

  /// Get leaderboard for a challenge
  Future<List<LeaderboardEntry>> getLeaderboard(String challengeId, {int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection('challenges')
          .doc(challengeId)
          .collection('leaderboard')
          .orderBy('value', descending: true)
          .limit(limit)
          .get();

      List<LeaderboardEntry> entries = [];
      int rank = 1;

      for (final doc in snapshot.docs) {
        final data = doc.data();

        // Get user info
        final userDoc = await _firestore.collection('users').doc(doc.id).get();
        final userData = userDoc.data() ?? {};

        entries.add(LeaderboardEntry(
          rank: rank,
          userId: doc.id,
          userName: userData['displayName'] as String? ?? 'Runner',
          userPhotoUrl: userData['photoUrl'] as String?,
          value: (data['value'] as num?)?.toDouble() ?? 0,
          isCurrentUser: doc.id == _userId,
        ));
        rank++;
      }

      return entries;
    } catch (e) {
      debugPrint('Error getting leaderboard: $e');
      return [];
    }
  }

  /// Update leaderboard after a run
  Future<void> updateLeaderboards() async {
    if (_userId == null) return;

    for (final challenge in _joinedChallenges) {
      final prog = _progress[challenge.id];
      if (prog != null) {
        try {
          await _firestore
              .collection('challenges')
              .doc(challenge.id)
              .collection('leaderboard')
              .doc(_userId)
              .set({
            'value': prog.currentValue,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('Error updating leaderboard: $e');
        }
      }
    }
  }

  /// Called after a run completes
  Future<void> onRunCompleted() async {
    for (final challenge in _joinedChallenges) {
      await _loadProgress(challenge);
    }
    await updateLeaderboards();
    notifyListeners();
  }

  /// Check if user has joined a challenge
  bool isJoined(String challengeId) {
    return _joinedChallenges.any((c) => c.id == challengeId);
  }

  /// Get featured challenges (upcoming or popular)
  Future<List<Challenge>> getFeaturedChallenges() async {
    try {
      final now = Timestamp.now();

      // Get upcoming challenges
      final upcomingSnapshot = await _firestore
          .collection('challenges')
          .where('startDate', isGreaterThan: now)
          .orderBy('startDate')
          .limit(5)
          .get();

      // Get popular active challenges
      final popularSnapshot = await _firestore
          .collection('challenges')
          .where('endDate', isGreaterThan: now)
          .where('startDate', isLessThanOrEqualTo: now)
          .orderBy('participantCount', descending: true)
          .limit(5)
          .get();

      final allChallenges = [
        ...upcomingSnapshot.docs.map((d) => Challenge.fromMap(d.data(), d.id)),
        ...popularSnapshot.docs.map((d) => Challenge.fromMap(d.data(), d.id)),
      ];

      // Remove duplicates
      final seen = <String>{};
      return allChallenges.where((c) => seen.add(c.id)).toList();
    } catch (e) {
      debugPrint('Error getting featured challenges: $e');
      return [];
    }
  }

  /// Create monthly distance challenges (admin function)
  static Map<String, dynamic> createMonthlyDistanceChallenge({
    required int year,
    required int month,
    required double targetKm,
    String? name,
    String? description,
  }) {
    final startDate = DateTime(year, month);
    final endDate = DateTime(year, month + 1, 0, 23, 59, 59);

    return {
      'name': name ?? '${_monthName(month)} $year Distance Challenge',
      'description': description ?? 'Run $targetKm km in ${_monthName(month)}',
      'type': ChallengeType.totalDistance.index,
      'targetValue': targetKm,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'participantCount': 0,
      'badgeIcon': 'distance',
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static String _monthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}

// Data classes

enum ChallengeType {
  totalDistance,
  longestRun,
  runCount,
  totalElevation,
  totalTime,
  streak,
}

extension ChallengeTypeExtension on ChallengeType {
  String get name {
    switch (this) {
      case ChallengeType.totalDistance:
        return 'Total Distance';
      case ChallengeType.longestRun:
        return 'Longest Run';
      case ChallengeType.runCount:
        return 'Run Count';
      case ChallengeType.totalElevation:
        return 'Total Elevation';
      case ChallengeType.totalTime:
        return 'Total Time';
      case ChallengeType.streak:
        return 'Streak';
    }
  }

  String get unit {
    switch (this) {
      case ChallengeType.totalDistance:
      case ChallengeType.longestRun:
        return 'km';
      case ChallengeType.runCount:
        return 'runs';
      case ChallengeType.totalElevation:
        return 'm';
      case ChallengeType.totalTime:
        return 'hours';
      case ChallengeType.streak:
        return 'days';
    }
  }

  String formatValue(double value) {
    switch (this) {
      case ChallengeType.totalDistance:
      case ChallengeType.longestRun:
        return '${value.toStringAsFixed(1)} km';
      case ChallengeType.runCount:
        return '${value.toInt()} runs';
      case ChallengeType.totalElevation:
        return '${value.toInt()} m';
      case ChallengeType.totalTime:
        final hours = (value / 3600).floor();
        final minutes = ((value % 3600) / 60).floor();
        return '${hours}h ${minutes}m';
      case ChallengeType.streak:
        return '${value.toInt()} days';
    }
  }
}

class Challenge {
  final String id;
  final String name;
  final String description;
  final ChallengeType type;
  final double targetValue;
  final DateTime startDate;
  final DateTime endDate;
  final int participantCount;
  final String badgeIcon;

  const Challenge({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.targetValue,
    required this.startDate,
    required this.endDate,
    required this.participantCount,
    required this.badgeIcon,
  });

  factory Challenge.fromMap(Map<String, dynamic> map, String id) {
    return Challenge(
      id: id,
      name: map['name'] as String? ?? 'Challenge',
      description: map['description'] as String? ?? '',
      type: ChallengeType.values[map['type'] as int? ?? 0],
      targetValue: (map['targetValue'] as num?)?.toDouble() ?? 0,
      startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (map['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      participantCount: (map['participantCount'] as num?)?.toInt() ?? 0,
      badgeIcon: map['badgeIcon'] as String? ?? 'default',
    );
  }

  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  bool get isUpcoming => DateTime.now().isBefore(startDate);
  bool get isEnded => DateTime.now().isAfter(endDate);

  int get daysRemaining {
    final now = DateTime.now();
    return endDate.difference(now).inDays;
  }

  String get formattedTarget => type.formatValue(targetValue);
}

class ChallengeProgress {
  final String challengeId;
  final double currentValue;
  final double targetValue;
  final double percentComplete;
  final int runCount;
  final bool isCompleted;

  const ChallengeProgress({
    required this.challengeId,
    required this.currentValue,
    required this.targetValue,
    required this.percentComplete,
    required this.runCount,
    required this.isCompleted,
  });
}

class LeaderboardEntry {
  final int rank;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final double value;
  final bool isCurrentUser;

  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.value,
    required this.isCurrentUser,
  });
}
