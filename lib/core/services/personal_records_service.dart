import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Personal Records (PRs) - Track best performances like Strava
class PersonalRecordsService {
  static final PersonalRecordsService _instance = PersonalRecordsService._internal();
  factory PersonalRecordsService() => _instance;
  PersonalRecordsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Standard distances to track PRs for
  static const List<PRDistance> standardDistances = [
    PRDistance(id: '400m', name: '400m', meters: 400),
    PRDistance(id: '1k', name: '1 km', meters: 1000),
    PRDistance(id: '1mile', name: '1 Mile', meters: 1609),
    PRDistance(id: '5k', name: '5K', meters: 5000),
    PRDistance(id: '10k', name: '10K', meters: 10000),
    PRDistance(id: '15k', name: '15K', meters: 15000),
    PRDistance(id: 'half', name: 'Half Marathon', meters: 21097),
    PRDistance(id: 'marathon', name: 'Marathon', meters: 42195),
  ];

  // Time-based PRs
  static const List<PRDuration> standardDurations = [
    PRDuration(id: '5min', name: '5 min', seconds: 300),
    PRDuration(id: '10min', name: '10 min', seconds: 600),
    PRDuration(id: '30min', name: '30 min', seconds: 1800),
    PRDuration(id: '1hour', name: '1 Hour', seconds: 3600),
  ];

  String? get _userId => _auth.currentUser?.uid;

  /// Check if a run sets any new PRs and return them
  Future<List<NewPR>> checkForNewPRs({
    required double distanceMeters,
    required int durationSeconds,
    required List<RunSplit> splits,
    required String runId,
  }) async {
    if (_userId == null) return [];

    final newPRs = <NewPR>[];
    final existingPRs = await getPersonalRecords();

    // Check distance PRs (fastest time to cover distance)
    for (final distance in standardDistances) {
      if (distanceMeters >= distance.meters) {
        final timeForDistance = _calculateTimeForDistance(splits, distance.meters);
        if (timeForDistance != null) {
          final existingPR = existingPRs.firstWhere(
            (pr) => pr.distanceId == distance.id,
            orElse: () => PersonalRecord(
              distanceId: distance.id,
              distanceName: distance.name,
              timeSeconds: 999999,
              pacePerKm: '',
              achievedAt: DateTime.now(),
              runId: '',
            ),
          );

          if (timeForDistance < existingPR.timeSeconds) {
            final newPR = NewPR(
              distanceId: distance.id,
              distanceName: distance.name,
              newTimeSeconds: timeForDistance,
              previousTimeSeconds: existingPR.timeSeconds < 999999 ? existingPR.timeSeconds : null,
              improvement: existingPR.timeSeconds < 999999
                  ? existingPR.timeSeconds - timeForDistance
                  : null,
              runId: runId,
            );
            newPRs.add(newPR);
            await _savePR(distance, timeForDistance, runId);
          }
        }
      }
    }

    // Check duration PRs (longest distance in time)
    for (final duration in standardDurations) {
      if (durationSeconds >= duration.seconds) {
        final distanceInTime = _calculateDistanceInTime(splits, duration.seconds);
        if (distanceInTime != null) {
          // Store as a different collection
          await _saveDurationPR(duration, distanceInTime, runId);
        }
      }
    }

    // Check for longest run ever
    final longestRun = await _getLongestRun();
    if (distanceMeters > longestRun) {
      newPRs.add(NewPR(
        distanceId: 'longest',
        distanceName: 'Longest Run',
        newTimeSeconds: durationSeconds,
        newDistanceMeters: distanceMeters,
        isLongestRun: true,
        runId: runId,
      ));
      await _saveLongestRun(distanceMeters, durationSeconds, runId);
    }

    // Check for fastest average pace (minimum 1km)
    if (distanceMeters >= 1000) {
      final avgPaceSeconds = (durationSeconds / (distanceMeters / 1000)).round();
      final fastestPace = await _getFastestPace();
      if (avgPaceSeconds < fastestPace) {
        newPRs.add(NewPR(
          distanceId: 'fastest_pace',
          distanceName: 'Fastest Pace',
          newTimeSeconds: avgPaceSeconds,
          previousTimeSeconds: fastestPace < 999999 ? fastestPace : null,
          isFastestPace: true,
          runId: runId,
        ));
        await _saveFastestPace(avgPaceSeconds, distanceMeters, runId);
      }
    }

    return newPRs;
  }

  /// Calculate time to cover a specific distance from splits
  int? _calculateTimeForDistance(List<RunSplit> splits, double targetMeters) {
    if (splits.isEmpty) return null;

    double accumulatedDistance = 0;
    int accumulatedTime = 0;

    for (final split in splits) {
      if (accumulatedDistance + split.distanceMeters >= targetMeters) {
        // Interpolate the exact time
        final remainingDistance = targetMeters - accumulatedDistance;
        final fractionOfSplit = remainingDistance / split.distanceMeters;
        final additionalTime = (split.durationSeconds * fractionOfSplit).round();
        return accumulatedTime + additionalTime;
      }
      accumulatedDistance += split.distanceMeters;
      accumulatedTime += split.durationSeconds;
    }

    return null;
  }

  /// Calculate distance covered in a specific time from splits
  double? _calculateDistanceInTime(List<RunSplit> splits, int targetSeconds) {
    if (splits.isEmpty) return null;

    double accumulatedDistance = 0;
    int accumulatedTime = 0;

    for (final split in splits) {
      if (accumulatedTime + split.durationSeconds >= targetSeconds) {
        final remainingTime = targetSeconds - accumulatedTime;
        final fractionOfSplit = remainingTime / split.durationSeconds;
        final additionalDistance = split.distanceMeters * fractionOfSplit;
        return accumulatedDistance + additionalDistance;
      }
      accumulatedTime += split.durationSeconds;
      accumulatedDistance += split.distanceMeters;
    }

    return accumulatedDistance;
  }

  Future<void> _savePR(PRDistance distance, int timeSeconds, String runId) async {
    if (_userId == null) return;

    final pacePerKm = _formatPace(timeSeconds, distance.meters);

    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('personalRecords')
        .doc(distance.id)
        .set({
      'distanceId': distance.id,
      'distanceName': distance.name,
      'distanceMeters': distance.meters,
      'timeSeconds': timeSeconds,
      'pacePerKm': pacePerKm,
      'achievedAt': FieldValue.serverTimestamp(),
      'runId': runId,
    });

    debugPrint('🏆 New PR saved: ${distance.name} in ${_formatTime(timeSeconds)}');
  }

  Future<void> _saveDurationPR(PRDuration duration, double distanceMeters, String runId) async {
    if (_userId == null) return;

    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('durationRecords')
        .doc(duration.id)
        .set({
      'durationId': duration.id,
      'durationName': duration.name,
      'durationSeconds': duration.seconds,
      'distanceMeters': distanceMeters,
      'achievedAt': FieldValue.serverTimestamp(),
      'runId': runId,
    });
  }

  Future<double> _getLongestRun() async {
    if (_userId == null) return 0;

    final doc = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('personalRecords')
        .doc('longest_run')
        .get();

    return (doc.data()?['distanceMeters'] as num?)?.toDouble() ?? 0;
  }

  Future<void> _saveLongestRun(double distanceMeters, int durationSeconds, String runId) async {
    if (_userId == null) return;

    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('personalRecords')
        .doc('longest_run')
        .set({
      'distanceMeters': distanceMeters,
      'durationSeconds': durationSeconds,
      'achievedAt': FieldValue.serverTimestamp(),
      'runId': runId,
    });
  }

  Future<int> _getFastestPace() async {
    if (_userId == null) return 999999;

    final doc = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('personalRecords')
        .doc('fastest_pace')
        .get();

    return (doc.data()?['paceSeconds'] as int?) ?? 999999;
  }

  Future<void> _saveFastestPace(int paceSeconds, double distanceMeters, String runId) async {
    if (_userId == null) return;

    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('personalRecords')
        .doc('fastest_pace')
        .set({
      'paceSeconds': paceSeconds,
      'distanceMeters': distanceMeters,
      'achievedAt': FieldValue.serverTimestamp(),
      'runId': runId,
    });
  }

  /// Get all personal records for the current user
  Future<List<PersonalRecord>> getPersonalRecords() async {
    if (_userId == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('personalRecords')
        .get();

    return snapshot.docs
        .where((doc) => doc.id != 'longest_run' && doc.id != 'fastest_pace')
        .map((doc) {
          final data = doc.data();
          return PersonalRecord(
            distanceId: data['distanceId'] ?? doc.id,
            distanceName: data['distanceName'] ?? '',
            timeSeconds: data['timeSeconds'] ?? 0,
            pacePerKm: data['pacePerKm'] ?? '',
            achievedAt: (data['achievedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            runId: data['runId'] ?? '',
          );
        })
        .toList();
  }

  /// Get PR progress - how close to next PR
  Future<Map<String, PRProgress>> getPRProgress({
    required double currentDistanceMeters,
    required int currentTimeSeconds,
  }) async {
    final prs = await getPersonalRecords();
    final progress = <String, PRProgress>{};

    for (final distance in standardDistances) {
      final existingPR = prs.firstWhere(
        (pr) => pr.distanceId == distance.id,
        orElse: () => PersonalRecord(
          distanceId: distance.id,
          distanceName: distance.name,
          timeSeconds: 0,
          pacePerKm: '',
          achievedAt: DateTime.now(),
          runId: '',
        ),
      );

      if (currentDistanceMeters >= distance.meters) {
        // Calculate current time for this distance
        final currentPace = currentTimeSeconds / (currentDistanceMeters / 1000);
        final projectedTime = (currentPace * (distance.meters / 1000)).round();

        if (existingPR.timeSeconds > 0) {
          final diff = projectedTime - existingPR.timeSeconds;
          progress[distance.id] = PRProgress(
            distanceId: distance.id,
            distanceName: distance.name,
            currentProjection: projectedTime,
            prTime: existingPR.timeSeconds,
            difference: diff,
            isOnTrack: diff < 0,
          );
        }
      }
    }

    return progress;
  }

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _formatPace(int totalSeconds, double meters) {
    final paceSecondsPerKm = totalSeconds / (meters / 1000);
    final minutes = paceSecondsPerKm ~/ 60;
    final seconds = (paceSecondsPerKm % 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

// Data classes

class PRDistance {
  final String id;
  final String name;
  final double meters;

  const PRDistance({required this.id, required this.name, required this.meters});
}

class PRDuration {
  final String id;
  final String name;
  final int seconds;

  const PRDuration({required this.id, required this.name, required this.seconds});
}

class PersonalRecord {
  final String distanceId;
  final String distanceName;
  final int timeSeconds;
  final String pacePerKm;
  final DateTime achievedAt;
  final String runId;

  PersonalRecord({
    required this.distanceId,
    required this.distanceName,
    required this.timeSeconds,
    required this.pacePerKm,
    required this.achievedAt,
    required this.runId,
  });

  String get formattedTime {
    final hours = timeSeconds ~/ 3600;
    final minutes = (timeSeconds % 3600) ~/ 60;
    final secs = timeSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

class NewPR {
  final String distanceId;
  final String distanceName;
  final int newTimeSeconds;
  final int? previousTimeSeconds;
  final int? improvement;
  final double? newDistanceMeters;
  final bool isLongestRun;
  final bool isFastestPace;
  final String runId;

  NewPR({
    required this.distanceId,
    required this.distanceName,
    required this.newTimeSeconds,
    this.previousTimeSeconds,
    this.improvement,
    this.newDistanceMeters,
    this.isLongestRun = false,
    this.isFastestPace = false,
    required this.runId,
  });

  String get formattedTime {
    final hours = newTimeSeconds ~/ 3600;
    final minutes = (newTimeSeconds % 3600) ~/ 60;
    final secs = newTimeSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String? get formattedImprovement {
    if (improvement == null) return null;
    final mins = improvement! ~/ 60;
    final secs = improvement! % 60;
    if (mins > 0) {
      return '-$mins:${secs.toString().padLeft(2, '0')}';
    }
    return '-${secs}s';
  }
}

class PRProgress {
  final String distanceId;
  final String distanceName;
  final int currentProjection;
  final int prTime;
  final int difference;
  final bool isOnTrack;

  PRProgress({
    required this.distanceId,
    required this.distanceName,
    required this.currentProjection,
    required this.prTime,
    required this.difference,
    required this.isOnTrack,
  });
}

class RunSplit {
  final int splitNumber;
  final double distanceMeters;
  final int durationSeconds;
  final double cumulativeDistance;
  final int cumulativeTime;

  RunSplit({
    required this.splitNumber,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.cumulativeDistance,
    required this.cumulativeTime,
  });
}
