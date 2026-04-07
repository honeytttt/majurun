import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:majurun/modules/run/domain/repositories/run_history_repository.dart';
import 'package:majurun/modules/run/data/repositories/firestore_run_history_impl.dart';
import 'package:majurun/modules/run/domain/entities/run_post.dart';
import 'package:majurun/core/services/user_stats_service.dart';
import 'package:majurun/core/services/push_notification_service.dart';

class StatsController extends ChangeNotifier {
  final RunHistoryRepository _repository;
  final FirebaseFirestore _firestore;

  StatsController({
    RunHistoryRepository? repository,
    FirebaseFirestore? firestore,
  })  : _repository = repository ?? FirestoreRunHistoryImpl(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  // Personal stats (from run history)
  double historyDistance = 0.0;
  int runStreak = 0;
  int totalRuns = 0;
  String totalHistoryTimeStr = "00:00:00";

  Future<void> refreshHistoryStats() async {
    final stats = await _repository.getStats();
    totalRuns = stats.totalRuns;
    historyDistance = stats.totalDistanceKm;
    runStreak = stats.runStreak;
    totalHistoryTimeStr = stats.formattedTotalDuration;
    notifyListeners();
  }

  /// Saves run to personal history (private workout record)
  /// Does NOT create a social post automatically
  Future<void> saveRunHistory({
    required String planTitle,
    required double distanceKm,
    required int durationSeconds,
    required String pace,
    List<LatLng>? routePoints,
    int? avgBpm,
    int? calories,
    String? type,
    int? week,
    int? day,
    bool? completed,
    String? mapImageUrl,
    Map<String, dynamic>? extra,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    debugPrint('📊 StatsController.saveRunHistory called');
    debugPrint('   User ID: $uid');
    debugPrint('   Distance: ${distanceKm.toStringAsFixed(2)} km');
    debugPrint('   Duration: $durationSeconds seconds');
    debugPrint('   Calories: ${calories ?? 0}');

    if (uid == null) {
      debugPrint('❌ No user logged in - cannot save stats');
      return;
    }

    // 1) Save to run history (private workout record)
    await _repository.saveRun(
      planTitle: planTitle,
      distanceKm: distanceKm,
      durationSeconds: durationSeconds,
      pace: pace,
      routePoints: routePoints,
      avgBpm: avgBpm,
      calories: calories,
      type: type,
      week: week,
      day: day,
      completed: completed,
      mapImageUrl: mapImageUrl,
      extra: extra,
    );

    debugPrint('✅ Run saved to history repository (PRIVATE)');

    // 2) Update user stats and badges
    try {
      debugPrint('📈 Updating stats and badges via UserStatsService...');
      final result = await UserStatsService().addRun(
        uid: uid,
        distanceKm: distanceKm,
        durationSeconds: durationSeconds,
        calories: calories ?? 0,
        completed: completed ?? true,
      );
      debugPrint('✅ User stats and badges updated successfully');

      // PB local notifications
      for (final pb in result.pbs) {
        final timeStr = distanceKm > 0
            ? '${(durationSeconds / distanceKm / 60).floor()}:${((durationSeconds / distanceKm) % 60).toInt().toString().padLeft(2, '0')}/km'
            : '${durationSeconds ~/ 60}:${(durationSeconds % 60).toString().padLeft(2, '0')}';
        await PushNotificationService().showPersonalRecordNotification(
          recordType: pb,
          value: timeStr,
        );
      }

      // Notify followers when user earns a brand-new badge (first time)
      if (result.badges.isNotEmpty) {
        _notifyFollowersOfBadge(uid, result.badges.first);
      }
    } catch (e) {
      debugPrint('❌ ERROR updating user stats: $e');
    }

    // Update local state
    historyDistance += distanceKm;
    runStreak += 1;

    await refreshHistoryStats();
    notifyListeners();
  }

  /// Creates a social post from a completed run
  /// Call this separately when user wants to share
  Future<void> createPostFromRun({
    required String planTitle,
    required double distanceKm,
    required int durationSeconds,
    required String pace,
    String? caption,
    String? mapImageUrl,
    List<LatLng>? routePoints,
    int? avgBpm,
    int? calories,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('❌ No user logged in - cannot create post');
      return;
    }

    debugPrint('📝 Creating social post from run...');

    // Get user data for the post
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};

    final postData = {
      'userId': user.uid,
      'userName': userData['name'] ?? 'Runner',
      'userAvatar': userData['avatarUrl'] ?? '',
      'type': 'run',
      'createdAt': FieldValue.serverTimestamp(),
      
      // Run data
      'runData': {
        'planTitle': planTitle,
        'distanceKm': distanceKm,
        'durationSeconds': durationSeconds,
        'pace': pace,
        'avgBpm': avgBpm,
        'calories': calories,
        'mapImageUrl': mapImageUrl,
      },
      
      // Optional caption
      'caption': caption ?? 'Completed $planTitle - ${distanceKm.toStringAsFixed(2)} km!',
      
      // Social metrics
      'likes': [],
      'likeCount': 0,
      'commentCount': 0,
    };

    await _firestore.collection('posts').add(postData);
    debugPrint('✅ Social post created successfully');
    notifyListeners();
  }

  /// Get last activity from RUN HISTORY (private workout record)
  Future<Map<String, dynamic>?> getLastActivity() async {
    final lastRun = await _repository.getLastRun();
    if (lastRun == null) return null;

    return {
      'id': lastRun.id,
      'date': lastRun.completedAt,
      'distance': lastRun.distanceKm,
      'durationSeconds': lastRun.durationSeconds,
      'pace': lastRun.pace,
      'calories': lastRun.calories,
      'planTitle': lastRun.planTitle,
      'avgBpm': lastRun.avgBpm,
      'routePoints': lastRun.routePoints,
      'type': lastRun.type,
      'week': lastRun.week,
      'day': lastRun.day,
      'completed': lastRun.completed,
      'mapImageUrl': lastRun.mapImageUrl,
      'extra': lastRun.extra,
      'isExternal': lastRun.isExternal,
      'source': lastRun.source,
    };
  }

  /// Get all runs from RUN HISTORY (private workout records)
  /// This is YOUR personal workout log, not social posts
  Future<List<Map<String, dynamic>>> getRunHistory() async {
    final runs = await _repository.getAllRuns();
    return runs
        .map((run) => {
              'id': run.id,
              'date': run.completedAt,
              'distance': run.distanceKm,
              'durationSeconds': run.durationSeconds,
              'pace': run.pace,
              'calories': run.calories,
              'planTitle': run.planTitle,
              'avgBpm': run.avgBpm,
              'routePoints': run.routePoints,
              'type': run.type,
              'week': run.week,
              'day': run.day,
              'completed': run.completed,
              'mapImageUrl': run.mapImageUrl,
              'extra': run.extra,
              'isExternal': run.isExternal,
              'source': run.source,
            })
        .toList();
  }

  /// Get SOCIAL POSTS stream (public feed from all users)
  /// This is the global social feed, not just your runs
  Stream<List<RunPost>> getPostStream() {
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(50) // Add limit for performance
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => RunPost.fromFirestore(doc)).toList());
  }

  /// Get ONLY YOUR posts (for profile view)
  Stream<List<RunPost>> getMyPostsStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _firestore
        .collection('posts')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => RunPost.fromFirestore(doc)).toList());
  }

  /// Get posts from users you follow (for feed)
  Stream<List<RunPost>> getFeedPostsStream(List<String> followingIds) {
    if (followingIds.isEmpty) {
      // If not following anyone, show recent posts from everyone
      return getPostStream();
    }

    return _firestore
        .collection('posts')
        .where('userId', whereIn: followingIds)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => RunPost.fromFirestore(doc)).toList());
  }

  /// Delete a post (only your own)
  Future<void> deletePost(String postId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final postDoc = await _firestore.collection('posts').doc(postId).get();
    if (postDoc.exists && postDoc.data()?['userId'] == uid) {
      await _firestore.collection('posts').doc(postId).delete();
      debugPrint('✅ Post deleted: $postId');
      notifyListeners();
    } else {
      debugPrint('❌ Cannot delete post - not yours or does not exist');
    }
  }

  /// Like/Unlike a post
  Future<void> toggleLike(String postId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final postRef = _firestore.collection('posts').doc(postId);
    final postDoc = await postRef.get();
    
    if (!postDoc.exists) return;

    final likes = List<String>.from(postDoc.data()?['likes'] ?? []);
    
    if (likes.contains(uid)) {
      // Unlike
      await postRef.update({
        'likes': FieldValue.arrayRemove([uid]),
        'likeCount': FieldValue.increment(-1),
      });
      debugPrint('👎 Unliked post: $postId');
    } else {
      // Like
      await postRef.update({
        'likes': FieldValue.arrayUnion([uid]),
        'likeCount': FieldValue.increment(1),
      });
      debugPrint('👍 Liked post: $postId');
    }
  }

  /// Write in-app notification docs for each follower when a new badge is earned.
  /// Uses the existing notifications/{followerId}/items structure (same as follow notifs).
  void _notifyFollowersOfBadge(String uid, String badgeName) {
    _firestore
        .collection('users')
        .doc(uid)
        .collection('followers')
        .get()
        .then((snap) async {
      if (snap.docs.isEmpty) return;

      final userDoc = await _firestore.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? {};
      final runnerName = (userData['displayName'] as String?)?.trim() ?? 'A runner';
      final runnerPhoto = (userData['photoUrl'] as String?) ?? '';

      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        final followerId = doc.data()['userId'] as String?;
        if (followerId == null) continue;
        final notifRef = _firestore
            .collection('notifications')
            .doc(followerId)
            .collection('items')
            .doc();
        batch.set(notifRef, {
          'type': 'badge_earned',
          'fromUserId': uid,
          'fromUsername': runnerName,
          'fromUserPhotoUrl': runnerPhoto,
          'message': '$runnerName just earned the $badgeName badge! 🏅',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      debugPrint('🏅 Notified ${snap.docs.length} followers of $badgeName badge');
    }).catchError((e) {
      debugPrint('⚠️ Badge follower notification error: $e');
    });
  }
}