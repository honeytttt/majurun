import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Segments Service - Compete on specific routes like Strava Segments
/// Create segments, track personal bests, and compete with other runners
class SegmentsService {
  static final SegmentsService _instance = SegmentsService._internal();
  factory SegmentsService() => _instance;
  SegmentsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  // Matching tolerance in meters
  static const double _matchTolerance = 25.0;
  static const double _startEndTolerance = 50.0;

  /// Create a new segment from a route
  Future<String?> createSegment({
    required String name,
    required String description,
    required List<LatLng> route,
    required double distanceMeters,
    bool isPrivate = false,
  }) async {
    if (_userId == null) return null;
    if (route.length < 2) return null;

    try {
      final startPoint = route.first;
      final endPoint = route.last;

      // Calculate elevation change if available
      const elevationGain = 0.0; // Would need altitude data

      final segmentRef = _firestore.collection('segments').doc();

      await segmentRef.set({
        'id': segmentRef.id,
        'name': name,
        'description': description,
        'createdBy': _userId,
        'createdAt': FieldValue.serverTimestamp(),
        'startPoint': GeoPoint(startPoint.latitude, startPoint.longitude),
        'endPoint': GeoPoint(endPoint.latitude, endPoint.longitude),
        'route': route.map((p) => GeoPoint(p.latitude, p.longitude)).toList(),
        'distanceMeters': distanceMeters,
        'elevationGain': elevationGain,
        'isPrivate': isPrivate,
        'totalAttempts': 0,
        'uniqueRunners': 0,
        'averageTime': 0,
        'bestTime': null,
        'bestTimeUserId': null,
      });

      debugPrint('🏁 Segment created: $name (${segmentRef.id})');
      return segmentRef.id;
    } catch (e) {
      debugPrint('❌ Error creating segment: $e');
      return null;
    }
  }

  /// Find segments that match a run route
  Future<List<SegmentMatch>> findMatchingSegments(List<LatLng> runRoute) async {
    if (runRoute.length < 2) return [];

    final matches = <SegmentMatch>[];

    try {
      // Get all public segments (in production, use geohash for efficiency)
      final snapshot = await _firestore
          .collection('segments')
          .where('isPrivate', isEqualTo: false)
          .limit(100)
          .get();

      for (final doc in snapshot.docs) {
        final segment = Segment.fromFirestore(doc);
        final match = _checkSegmentMatch(segment, runRoute);
        if (match != null) {
          matches.add(match);
        }
      }

      debugPrint('🔍 Found ${matches.length} matching segments');
      return matches;
    } catch (e) {
      debugPrint('❌ Error finding segments: $e');
      return [];
    }
  }

  /// Check if a run route matches a segment
  SegmentMatch? _checkSegmentMatch(Segment segment, List<LatLng> runRoute) {
    // Find where the segment starts in the run
    int startIndex = -1;
    for (int i = 0; i < runRoute.length; i++) {
      final distance = _calculateDistance(runRoute[i], segment.startPoint);
      if (distance <= _startEndTolerance) {
        startIndex = i;
        break;
      }
    }

    if (startIndex == -1) return null;

    // Find where the segment ends in the run
    int endIndex = -1;
    for (int i = startIndex + 1; i < runRoute.length; i++) {
      final distance = _calculateDistance(runRoute[i], segment.endPoint);
      if (distance <= _startEndTolerance) {
        endIndex = i;
        break;
      }
    }

    if (endIndex == -1) return null;

    // Verify the route roughly matches the segment path
    final runSegment = runRoute.sublist(startIndex, endIndex + 1);
    if (!_routesMatch(segment.route, runSegment)) return null;

    return SegmentMatch(
      segment: segment,
      startIndex: startIndex,
      endIndex: endIndex,
    );
  }

  /// Check if two routes roughly match
  bool _routesMatch(List<LatLng> segmentRoute, List<LatLng> runRoute) {
    if (runRoute.isEmpty || segmentRoute.isEmpty) return false;

    // Sample points and check they're within tolerance
    final sampleCount = math.min(10, segmentRoute.length);
    int matchedPoints = 0;

    for (int i = 0; i < sampleCount; i++) {
      final segmentIdx = (i * segmentRoute.length / sampleCount).floor();
      final segmentPoint = segmentRoute[segmentIdx];

      // Find closest point in run route
      double minDistance = double.infinity;
      for (final runPoint in runRoute) {
        final distance = _calculateDistance(segmentPoint, runPoint);
        if (distance < minDistance) minDistance = distance;
      }

      if (minDistance <= _matchTolerance) matchedPoints++;
    }

    // Require at least 70% of points to match
    return matchedPoints / sampleCount >= 0.7;
  }

  /// Record a segment attempt (after a run)
  Future<SegmentResult?> recordSegmentAttempt({
    required String segmentId,
    required int timeSeconds,
    required String runId,
    required double avgPaceSecondsPerKm,
  }) async {
    if (_userId == null) return null;

    try {
      // Get segment
      final segmentDoc = await _firestore.collection('segments').doc(segmentId).get();
      if (!segmentDoc.exists) return null;

      final segment = Segment.fromFirestore(segmentDoc);

      // Get user's previous best
      final previousBest = await _getUserBestTime(segmentId);

      // Determine rank
      final rank = await _calculateRank(segmentId, timeSeconds);

      // Create attempt record
      final attemptRef = _firestore
          .collection('segments')
          .doc(segmentId)
          .collection('attempts')
          .doc();

      await attemptRef.set({
        'userId': _userId,
        'runId': runId,
        'timeSeconds': timeSeconds,
        'avgPaceSecondsPerKm': avgPaceSecondsPerKm,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update segment stats
      await _updateSegmentStats(segmentId, timeSeconds);

      // Update user's personal record if this is their best
      bool isPersonalBest = previousBest == null || timeSeconds < previousBest;
      if (isPersonalBest) {
        await _firestore
            .collection('users')
            .doc(_userId)
            .collection('segmentPRs')
            .doc(segmentId)
            .set({
          'segmentId': segmentId,
          'segmentName': segment.name,
          'timeSeconds': timeSeconds,
          'runId': runId,
          'achievedAt': FieldValue.serverTimestamp(),
        });
      }

      // Check if this is a new overall best (KOM/QOM)
      bool isKOM = segment.bestTime == null || timeSeconds < segment.bestTime!;
      if (isKOM) {
        await _firestore.collection('segments').doc(segmentId).update({
          'bestTime': timeSeconds,
          'bestTimeUserId': _userId,
          'bestTimeDate': FieldValue.serverTimestamp(),
        });
      }

      return SegmentResult(
        segmentId: segmentId,
        segmentName: segment.name,
        timeSeconds: timeSeconds,
        rank: rank,
        previousBest: previousBest,
        isPersonalBest: isPersonalBest,
        isKOM: isKOM,
        totalAttempts: segment.totalAttempts + 1,
      );
    } catch (e) {
      debugPrint('❌ Error recording segment attempt: $e');
      return null;
    }
  }

  Future<int?> _getUserBestTime(String segmentId) async {
    if (_userId == null) return null;

    final doc = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('segmentPRs')
        .doc(segmentId)
        .get();

    return doc.data()?['timeSeconds'] as int?;
  }

  Future<int> _calculateRank(String segmentId, int timeSeconds) async {
    final snapshot = await _firestore
        .collection('segments')
        .doc(segmentId)
        .collection('attempts')
        .where('timeSeconds', isLessThan: timeSeconds)
        .count()
        .get();

    return (snapshot.count ?? 0) + 1;
  }

  Future<void> _updateSegmentStats(String segmentId, int newTime) async {
    await _firestore.collection('segments').doc(segmentId).update({
      'totalAttempts': FieldValue.increment(1),
    });

    // Update unique runners count (simplified - would need to track properly)
  }

  /// Get leaderboard for a segment
  Future<List<SegmentLeaderboardEntry>> getSegmentLeaderboard(
    String segmentId, {
    int limit = 20,
  }) async {
    try {
      // Get all unique user PRs for this segment
      final snapshot = await _firestore
          .collectionGroup('segmentPRs')
          .where('segmentId', isEqualTo: segmentId)
          .orderBy('timeSeconds')
          .limit(limit)
          .get();

      final entries = <SegmentLeaderboardEntry>[];
      int rank = 1;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final userId = doc.reference.parent.parent?.id;
        if (userId == null) continue;

        // Get user info
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final userName = userDoc.data()?['displayName'] ?? 'Runner';
        final userPhoto = userDoc.data()?['photoUrl'];

        entries.add(SegmentLeaderboardEntry(
          rank: rank++,
          userId: userId,
          userName: userName,
          userPhotoUrl: userPhoto,
          timeSeconds: data['timeSeconds'] ?? 0,
          achievedAt: (data['achievedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          isCurrentUser: userId == _userId,
        ));
      }

      return entries;
    } catch (e) {
      debugPrint('❌ Error getting leaderboard: $e');
      return [];
    }
  }

  /// Get nearby segments
  Future<List<Segment>> getNearbySegments(LatLng location, {double radiusKm = 5}) async {
    // In production, use geohash for efficient querying
    // For now, return all public segments (simplified)
    try {
      final snapshot = await _firestore
          .collection('segments')
          .where('isPrivate', isEqualTo: false)
          .limit(50)
          .get();

      final segments = snapshot.docs
          .map((doc) => Segment.fromFirestore(doc))
          .where((segment) {
            final distance = _calculateDistance(location, segment.startPoint);
            return distance <= radiusKm * 1000;
          })
          .toList();

      return segments;
    } catch (e) {
      debugPrint('❌ Error getting nearby segments: $e');
      return [];
    }
  }

  /// Get user's segment PRs
  Future<List<UserSegmentPR>> getUserSegmentPRs() async {
    if (_userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('segmentPRs')
          .orderBy('achievedAt', descending: true)
          .limit(50)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return UserSegmentPR(
          segmentId: data['segmentId'] ?? '',
          segmentName: data['segmentName'] ?? '',
          timeSeconds: data['timeSeconds'] ?? 0,
          achievedAt: (data['achievedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting user segment PRs: $e');
      return [];
    }
  }

  double _calculateDistance(LatLng p1, LatLng p2) {
    const earthRadius = 6371000.0; // meters
    final lat1Rad = p1.latitude * math.pi / 180;
    final lat2Rad = p2.latitude * math.pi / 180;
    final deltaLat = (p2.latitude - p1.latitude) * math.pi / 180;
    final deltaLng = (p2.longitude - p1.longitude) * math.pi / 180;

    final a = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLng / 2) * math.sin(deltaLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }
}

// Data classes

class Segment {
  final String id;
  final String name;
  final String description;
  final String createdBy;
  final DateTime createdAt;
  final LatLng startPoint;
  final LatLng endPoint;
  final List<LatLng> route;
  final double distanceMeters;
  final double elevationGain;
  final bool isPrivate;
  final int totalAttempts;
  final int uniqueRunners;
  final int? bestTime;
  final String? bestTimeUserId;

  Segment({
    required this.id,
    required this.name,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    required this.startPoint,
    required this.endPoint,
    required this.route,
    required this.distanceMeters,
    required this.elevationGain,
    required this.isPrivate,
    required this.totalAttempts,
    required this.uniqueRunners,
    this.bestTime,
    this.bestTimeUserId,
  });

  factory Segment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final startGeo = data['startPoint'] as GeoPoint;
    final endGeo = data['endPoint'] as GeoPoint;
    final routeData = data['route'] as List<dynamic>? ?? [];

    return Segment(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startPoint: LatLng(startGeo.latitude, startGeo.longitude),
      endPoint: LatLng(endGeo.latitude, endGeo.longitude),
      route: routeData.map((g) {
        final geo = g as GeoPoint;
        return LatLng(geo.latitude, geo.longitude);
      }).toList(),
      distanceMeters: (data['distanceMeters'] as num?)?.toDouble() ?? 0,
      elevationGain: (data['elevationGain'] as num?)?.toDouble() ?? 0,
      isPrivate: data['isPrivate'] ?? false,
      totalAttempts: data['totalAttempts'] ?? 0,
      uniqueRunners: data['uniqueRunners'] ?? 0,
      bestTime: data['bestTime'] as int?,
      bestTimeUserId: data['bestTimeUserId'] as String?,
    );
  }

  String get formattedDistance {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(2)} km';
    }
    return '${distanceMeters.round()} m';
  }

  String? get formattedBestTime {
    if (bestTime == null) return null;
    final mins = bestTime! ~/ 60;
    final secs = bestTime! % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
}

class SegmentMatch {
  final Segment segment;
  final int startIndex;
  final int endIndex;

  SegmentMatch({
    required this.segment,
    required this.startIndex,
    required this.endIndex,
  });
}

class SegmentResult {
  final String segmentId;
  final String segmentName;
  final int timeSeconds;
  final int rank;
  final int? previousBest;
  final bool isPersonalBest;
  final bool isKOM;
  final int totalAttempts;

  SegmentResult({
    required this.segmentId,
    required this.segmentName,
    required this.timeSeconds,
    required this.rank,
    this.previousBest,
    required this.isPersonalBest,
    required this.isKOM,
    required this.totalAttempts,
  });

  String get formattedTime {
    final mins = timeSeconds ~/ 60;
    final secs = timeSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  String? get improvementString {
    if (previousBest == null || !isPersonalBest) return null;
    final improvement = previousBest! - timeSeconds;
    if (improvement <= 0) return null;
    final mins = improvement ~/ 60;
    final secs = improvement % 60;
    if (mins > 0) {
      return '-$mins:${secs.toString().padLeft(2, '0')}';
    }
    return '-${secs}s';
  }
}

class SegmentLeaderboardEntry {
  final int rank;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final int timeSeconds;
  final DateTime achievedAt;
  final bool isCurrentUser;

  SegmentLeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.timeSeconds,
    required this.achievedAt,
    required this.isCurrentUser,
  });

  String get formattedTime {
    final mins = timeSeconds ~/ 60;
    final secs = timeSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
}

class UserSegmentPR {
  final String segmentId;
  final String segmentName;
  final int timeSeconds;
  final DateTime achievedAt;

  UserSegmentPR({
    required this.segmentId,
    required this.segmentName,
    required this.timeSeconds,
    required this.achievedAt,
  });

  String get formattedTime {
    final mins = timeSeconds ~/ 60;
    final secs = timeSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
}
