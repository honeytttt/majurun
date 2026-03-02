import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Social Feed Service - Activity sharing like Strava
/// Supports follows, kudos, comments, and activity feed
class SocialFeedService extends ChangeNotifier {
  static final SocialFeedService _instance = SocialFeedService._internal();
  factory SocialFeedService() => _instance;
  SocialFeedService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userId;

  List<FeedActivity> _feedActivities = [];
  List<String> _following = [];
  List<String> _followers = [];
  bool _isLoading = false;

  List<FeedActivity> get feedActivities => List.unmodifiable(_feedActivities);
  List<String> get following => List.unmodifiable(_following);
  List<String> get followers => List.unmodifiable(_followers);
  int get followingCount => _following.length;
  int get followersCount => _followers.length;
  bool get isLoading => _isLoading;

  void setUserId(String? userId) {
    _userId = userId;
    if (userId != null) {
      _loadSocialData();
    }
  }

  Future<void> _loadSocialData() async {
    if (_userId == null) return;

    try {
      // Load following list (paginated)
      final followingSnap = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('following')
          .limit(500) // Max following to load
          .get();

      _following = followingSnap.docs.map((d) => d.id).toList();

      // Load followers list (paginated)
      final followersSnap = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('followers')
          .limit(500) // Max followers to load
          .get();

      _followers = followersSnap.docs.map((d) => d.id).toList();

      await loadFeed();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading social data: $e');
    }
  }

  /// Load feed from followed users and self
  Future<void> loadFeed({int limit = 20}) async {
    if (_userId == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Get activities from followed users and self (limit to 50 users for performance)
      final usersToLoad = [..._following.take(50), _userId!];

      // Batch fetch all user profiles first to avoid N+1 queries
      final Map<String, Map<String, dynamic>> userProfiles = {};

      // Firestore whereIn supports max 30 items, so batch if needed
      for (var i = 0; i < usersToLoad.length; i += 30) {
        final batch = usersToLoad.skip(i).take(30).toList();
        if (batch.isEmpty) continue;

        final usersSnap = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (final doc in usersSnap.docs) {
          userProfiles[doc.id] = doc.data();
        }
      }

      List<FeedActivity> allActivities = [];

      // Load activities for each user (limited per user)
      for (final userId in usersToLoad) {
        final activitiesSnap = await _firestore
            .collection('users')
            .doc(userId)
            .collection('runHistory')
            .where('isPublic', isEqualTo: true)
            .orderBy('timestamp', descending: true)
            .limit(5) // Reduced per user for better performance
            .get();

        final userData = userProfiles[userId] ?? {};

        for (final doc in activitiesSnap.docs) {
          final data = doc.data();
          allActivities.add(FeedActivity(
            id: doc.id,
            userId: userId,
            userName: userData['displayName'] as String? ?? 'Runner',
            userPhotoUrl: userData['photoUrl'] as String?,
            activityType: ActivityType.run,
            title: data['title'] as String? ?? 'Run',
            description: data['description'] as String?,
            distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0,
            durationSeconds: (data['durationSeconds'] as num?)?.toInt() ?? 0,
            elevationGain: (data['elevationGain'] as num?)?.toDouble() ?? 0,
            avgPaceSecondsPerKm: (data['avgPaceSecondsPerKm'] as num?)?.toDouble() ?? 0,
            mapPreviewUrl: data['mapPreviewUrl'] as String?,
            timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
            kudosCount: (data['kudosCount'] as num?)?.toInt() ?? 0,
            commentsCount: (data['commentsCount'] as num?)?.toInt() ?? 0,
            hasKudos: (data['kudosBy'] as List?)?.contains(_userId) ?? false,
          ));
        }
      }

      // Sort by timestamp
      allActivities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _feedActivities = allActivities.take(limit).toList();
    } catch (e) {
      debugPrint('Error loading feed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Follow a user
  Future<void> followUser(String targetUserId) async {
    if (_userId == null || targetUserId == _userId) return;

    try {
      // Add to my following
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('following')
          .doc(targetUserId)
          .set({'followedAt': FieldValue.serverTimestamp()});

      // Add me to their followers
      await _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('followers')
          .doc(_userId)
          .set({'followedAt': FieldValue.serverTimestamp()});

      // Create notification for them
      await _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('notifications')
          .add({
        'type': 'follow',
        'fromUserId': _userId,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      _following.add(targetUserId);
      await loadFeed();
      notifyListeners();
    } catch (e) {
      debugPrint('Error following user: $e');
    }
  }

  /// Unfollow a user
  Future<void> unfollowUser(String targetUserId) async {
    if (_userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('following')
          .doc(targetUserId)
          .delete();

      await _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('followers')
          .doc(_userId)
          .delete();

      _following.remove(targetUserId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error unfollowing user: $e');
    }
  }

  /// Give kudos to an activity
  Future<void> giveKudos(String activityUserId, String activityId) async {
    if (_userId == null) return;

    try {
      final activityRef = _firestore
          .collection('users')
          .doc(activityUserId)
          .collection('runHistory')
          .doc(activityId);

      await activityRef.update({
        'kudosCount': FieldValue.increment(1),
        'kudosBy': FieldValue.arrayUnion([_userId]),
      });

      // Create notification
      if (activityUserId != _userId) {
        await _firestore
            .collection('users')
            .doc(activityUserId)
            .collection('notifications')
            .add({
          'type': 'kudos',
          'fromUserId': _userId,
          'activityId': activityId,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });
      }

      // Update local state
      final index = _feedActivities.indexWhere((a) => a.id == activityId);
      if (index != -1) {
        final activity = _feedActivities[index];
        _feedActivities[index] = FeedActivity(
          id: activity.id,
          userId: activity.userId,
          userName: activity.userName,
          userPhotoUrl: activity.userPhotoUrl,
          activityType: activity.activityType,
          title: activity.title,
          description: activity.description,
          distanceKm: activity.distanceKm,
          durationSeconds: activity.durationSeconds,
          elevationGain: activity.elevationGain,
          avgPaceSecondsPerKm: activity.avgPaceSecondsPerKm,
          mapPreviewUrl: activity.mapPreviewUrl,
          timestamp: activity.timestamp,
          kudosCount: activity.kudosCount + 1,
          commentsCount: activity.commentsCount,
          hasKudos: true,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error giving kudos: $e');
    }
  }

  /// Remove kudos from an activity
  Future<void> removeKudos(String activityUserId, String activityId) async {
    if (_userId == null) return;

    try {
      final activityRef = _firestore
          .collection('users')
          .doc(activityUserId)
          .collection('runHistory')
          .doc(activityId);

      await activityRef.update({
        'kudosCount': FieldValue.increment(-1),
        'kudosBy': FieldValue.arrayRemove([_userId]),
      });

      // Update local state
      final index = _feedActivities.indexWhere((a) => a.id == activityId);
      if (index != -1) {
        final activity = _feedActivities[index];
        _feedActivities[index] = FeedActivity(
          id: activity.id,
          userId: activity.userId,
          userName: activity.userName,
          userPhotoUrl: activity.userPhotoUrl,
          activityType: activity.activityType,
          title: activity.title,
          description: activity.description,
          distanceKm: activity.distanceKm,
          durationSeconds: activity.durationSeconds,
          elevationGain: activity.elevationGain,
          avgPaceSecondsPerKm: activity.avgPaceSecondsPerKm,
          mapPreviewUrl: activity.mapPreviewUrl,
          timestamp: activity.timestamp,
          kudosCount: activity.kudosCount - 1,
          commentsCount: activity.commentsCount,
          hasKudos: false,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error removing kudos: $e');
    }
  }

  /// Add a comment to an activity
  Future<void> addComment(String activityUserId, String activityId, String text) async {
    if (_userId == null || text.trim().isEmpty) return;

    try {
      // Add comment
      await _firestore
          .collection('users')
          .doc(activityUserId)
          .collection('runHistory')
          .doc(activityId)
          .collection('comments')
          .add({
        'userId': _userId,
        'text': text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update comment count
      await _firestore
          .collection('users')
          .doc(activityUserId)
          .collection('runHistory')
          .doc(activityId)
          .update({
        'commentsCount': FieldValue.increment(1),
      });

      // Create notification
      if (activityUserId != _userId) {
        await _firestore
            .collection('users')
            .doc(activityUserId)
            .collection('notifications')
            .add({
          'type': 'comment',
          'fromUserId': _userId,
          'activityId': activityId,
          'commentPreview': text.trim().length > 50 ? '${text.trim().substring(0, 50)}...' : text.trim(),
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });
      }

      // Update local state
      final index = _feedActivities.indexWhere((a) => a.id == activityId);
      if (index != -1) {
        final activity = _feedActivities[index];
        _feedActivities[index] = FeedActivity(
          id: activity.id,
          userId: activity.userId,
          userName: activity.userName,
          userPhotoUrl: activity.userPhotoUrl,
          activityType: activity.activityType,
          title: activity.title,
          description: activity.description,
          distanceKm: activity.distanceKm,
          durationSeconds: activity.durationSeconds,
          elevationGain: activity.elevationGain,
          avgPaceSecondsPerKm: activity.avgPaceSecondsPerKm,
          mapPreviewUrl: activity.mapPreviewUrl,
          timestamp: activity.timestamp,
          kudosCount: activity.kudosCount,
          commentsCount: activity.commentsCount + 1,
          hasKudos: activity.hasKudos,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error adding comment: $e');
    }
  }

  /// Get comments for an activity
  Future<List<ActivityComment>> getComments(String activityUserId, String activityId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(activityUserId)
          .collection('runHistory')
          .doc(activityId)
          .collection('comments')
          .orderBy('timestamp', descending: false)
          .limit(100) // Max comments to load
          .get();

      // Batch fetch all commenter profiles to avoid N+1 queries
      final userIds = snapshot.docs
          .map((doc) => doc.data()['userId'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toSet()
          .toList();

      final Map<String, Map<String, dynamic>> userProfiles = {};

      // Firestore whereIn supports max 30 items
      for (var i = 0; i < userIds.length; i += 30) {
        final batch = userIds.skip(i).take(30).toList();
        if (batch.isEmpty) continue;

        final usersSnap = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (final doc in usersSnap.docs) {
          userProfiles[doc.id] = doc.data();
        }
      }

      List<ActivityComment> comments = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final commentUserId = data['userId'] as String?;
        final userData = commentUserId != null ? userProfiles[commentUserId] ?? {} : {};

        comments.add(ActivityComment(
          id: doc.id,
          userId: commentUserId ?? '',
          userName: userData['displayName'] as String? ?? 'Runner',
          userPhotoUrl: userData['photoUrl'] as String?,
          text: data['text'] as String? ?? '',
          timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        ));
      }

      return comments;
    } catch (e) {
      debugPrint('Error getting comments: $e');
      return [];
    }
  }

  /// Search users
  Future<List<UserProfile>> searchUsers(String query) async {
    if (query.length < 2) return [];

    try {
      // Search by display name (case-insensitive would require Cloud Functions or Algolia)
      final snapshot = await _firestore
          .collection('users')
          .where('displayNameLower', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('displayNameLower', isLessThanOrEqualTo: '${query.toLowerCase()}\uf8ff')
          .limit(20)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return UserProfile(
          id: doc.id,
          displayName: data['displayName'] as String? ?? 'Runner',
          photoUrl: data['photoUrl'] as String?,
          totalRuns: (data['totalRuns'] as num?)?.toInt() ?? 0,
          totalDistanceKm: (data['totalDistanceKm'] as num?)?.toDouble() ?? 0,
          isFollowing: _following.contains(doc.id),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [];
    }
  }

  /// Share activity to feed (make it public)
  Future<void> shareActivity(String activityId, {String? title, String? description}) async {
    if (_userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('runHistory')
          .doc(activityId)
          .update({
        'isPublic': true,
        if (title != null) 'title': title,
        if (description != null) 'description': description,
      });
    } catch (e) {
      debugPrint('Error sharing activity: $e');
    }
  }

  bool isFollowing(String userId) => _following.contains(userId);
}

// Data classes

enum ActivityType {
  run,
  walk,
  hike,
  workout,
}

class FeedActivity {
  final String id;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final ActivityType activityType;
  final String title;
  final String? description;
  final double distanceKm;
  final int durationSeconds;
  final double elevationGain;
  final double avgPaceSecondsPerKm;
  final String? mapPreviewUrl;
  final DateTime timestamp;
  final int kudosCount;
  final int commentsCount;
  final bool hasKudos;

  const FeedActivity({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.activityType,
    required this.title,
    this.description,
    required this.distanceKm,
    required this.durationSeconds,
    required this.elevationGain,
    required this.avgPaceSecondsPerKm,
    this.mapPreviewUrl,
    required this.timestamp,
    required this.kudosCount,
    required this.commentsCount,
    required this.hasKudos,
  });

  String get formattedPace {
    if (avgPaceSecondsPerKm <= 0) return '--:--';
    final minutes = (avgPaceSecondsPerKm / 60).floor();
    final seconds = (avgPaceSecondsPerKm % 60).floor();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedDuration {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inDays > 7) {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    }
    return 'Just now';
  }
}

class ActivityComment {
  final String id;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final String text;
  final DateTime timestamp;

  const ActivityComment({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.text,
    required this.timestamp,
  });
}

class UserProfile {
  final String id;
  final String displayName;
  final String? photoUrl;
  final int totalRuns;
  final double totalDistanceKm;
  final bool isFollowing;

  const UserProfile({
    required this.id,
    required this.displayName,
    this.photoUrl,
    required this.totalRuns,
    required this.totalDistanceKm,
    required this.isFollowing,
  });
}
