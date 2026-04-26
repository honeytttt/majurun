import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service for managing leaderboards and rankings
class LeaderboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Leaderboard entry model
  static Map<String, dynamic> createLeaderboardEntry({
    required String oderId,
    required String displayName,
    String? photoUrl,
    required double distance,
    required String period,
  }) {
    return {
      'userId': oderId,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'distance': distance,
      'period': period,
      'updatedAt': Timestamp.now(),
    };
  }

  /// Get weekly leaderboard (top runners this week)
  Future<List<Map<String, dynamic>>> getWeeklyLeaderboard({int limit = 20}) async {
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);

      final snapshot = await _firestore
          .collection('users')
          .where('weeklyStartDate', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStartDate))
          .orderBy('weeklyStartDate')
          .orderBy('weeklyKm', descending: true)
          .limit(limit)
          .get();

      final leaderboard = <Map<String, dynamic>>[];
      int rank = 1;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final weeklyKm = (data['weeklyKm'] as num?)?.toDouble() ?? 0.0;

        if (weeklyKm > 0) {
          leaderboard.add({
            'rank': rank,
            'userId': doc.id,
            'displayName': data['displayName'] ?? 'Runner',
            'photoUrl': data['photoUrl'],
            'distance': weeklyKm,
            'avatar': _getAvatarLetter(data['displayName'] ?? 'R'),
          });
          rank++;
        }
      }

      return leaderboard.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting weekly leaderboard: $e');
      return [];
    }
  }

  /// Get monthly leaderboard (top runners this month)
  Future<List<Map<String, dynamic>>> getMonthlyLeaderboard({int limit = 20}) async {
    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);

      final snapshot = await _firestore
          .collection('users')
          .where('monthlyStartDate', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
          .orderBy('monthlyStartDate')
          .orderBy('monthlyKm', descending: true)
          .limit(limit)
          .get();

      final leaderboard = <Map<String, dynamic>>[];
      int rank = 1;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final monthlyKm = (data['monthlyKm'] as num?)?.toDouble() ?? 0.0;

        if (monthlyKm > 0) {
          leaderboard.add({
            'rank': rank,
            'userId': doc.id,
            'displayName': data['displayName'] ?? 'Runner',
            'photoUrl': data['photoUrl'],
            'distance': monthlyKm,
            'avatar': _getAvatarLetter(data['displayName'] ?? 'R'),
          });
          rank++;
        }
      }

      return leaderboard.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting monthly leaderboard: $e');
      return [];
    }
  }

  /// Get all-time leaderboard (total distance)
  Future<List<Map<String, dynamic>>> getAllTimeLeaderboard({int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .orderBy('totalDistance', descending: true)
          .limit(limit)
          .get();

      final leaderboard = <Map<String, dynamic>>[];
      int rank = 1;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final totalDistance = (data['totalDistance'] as num?)?.toDouble() ?? 0.0;

        if (totalDistance > 0) {
          leaderboard.add({
            'rank': rank,
            'userId': doc.id,
            'displayName': data['displayName'] ?? 'Runner',
            'photoUrl': data['photoUrl'],
            'distance': totalDistance,
            'avatar': _getAvatarLetter(data['displayName'] ?? 'R'),
          });
          rank++;
        }
      }

      return leaderboard.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting all-time leaderboard: $e');
      return [];
    }
  }

  /// Get user's rank in leaderboard
  Future<Map<String, dynamic>> getUserRank(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        return {'weeklyRank': 0, 'monthlyRank': 0, 'allTimeRank': 0};
      }

      final userData = userDoc.data()!;
      final weeklyKm = (userData['weeklyKm'] as num?)?.toDouble() ?? 0.0;
      final monthlyKm = (userData['monthlyKm'] as num?)?.toDouble() ?? 0.0;
      final totalDistance = (userData['totalDistance'] as num?)?.toDouble() ?? 0.0;

      // Count users with more distance
      final weeklyRankSnapshot = await _firestore
          .collection('users')
          .where('weeklyKm', isGreaterThan: weeklyKm)
          .count()
          .get();

      final monthlyRankSnapshot = await _firestore
          .collection('users')
          .where('monthlyKm', isGreaterThan: monthlyKm)
          .count()
          .get();

      final allTimeRankSnapshot = await _firestore
          .collection('users')
          .where('totalDistance', isGreaterThan: totalDistance)
          .count()
          .get();

      return {
        'weeklyRank': (weeklyRankSnapshot.count ?? 0) + 1,
        'monthlyRank': (monthlyRankSnapshot.count ?? 0) + 1,
        'allTimeRank': (allTimeRankSnapshot.count ?? 0) + 1,
        'weeklyKm': weeklyKm,
        'monthlyKm': monthlyKm,
        'totalKm': totalDistance,
      };
    } catch (e) {
      debugPrint('Error getting user rank: $e');
      return {'weeklyRank': 0, 'monthlyRank': 0, 'allTimeRank': 0};
    }
  }

  /// Get friends leaderboard (users you follow)
  Future<List<Map<String, dynamic>>> getFriendsLeaderboard(String userId, {int limit = 20}) async {
    try {
      // Get users that the current user follows
      final followingSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('following')
          .get();

      final followingIds = followingSnapshot.docs.map((d) => d.id).toList();
      followingIds.add(userId); // Include self

      if (followingIds.isEmpty) {
        return [];
      }

      // Firestore has a limit of 10 items for 'in' queries, so we may need to batch
      final batches = <List<String>>[];
      for (var i = 0; i < followingIds.length; i += 10) {
        batches.add(followingIds.skip(i).take(10).toList());
      }

      final leaderboard = <Map<String, dynamic>>[];

      for (final batch in batches) {
        final snapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final weeklyKm = (data['weeklyKm'] as num?)?.toDouble() ?? 0.0;

          leaderboard.add({
            'userId': doc.id,
            'displayName': data['displayName'] ?? 'Runner',
            'photoUrl': data['photoUrl'],
            'distance': weeklyKm,
            'avatar': _getAvatarLetter(data['displayName'] ?? 'R'),
            'isCurrentUser': doc.id == userId,
          });
        }
      }

      // Sort by distance and assign ranks
      leaderboard.sort((a, b) => (b['distance'] as double).compareTo(a['distance'] as double));
      for (var i = 0; i < leaderboard.length; i++) {
        leaderboard[i]['rank'] = i + 1;
      }

      return leaderboard.take(limit).toList();
    } catch (e) {
      debugPrint('Error getting friends leaderboard: $e');
      return [];
    }
  }

  String _getAvatarLetter(String name) {
    return name.isNotEmpty ? name[0].toUpperCase() : 'R';
  }
}
