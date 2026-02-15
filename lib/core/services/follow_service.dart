import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:majurun/core/services/notification_service.dart';

class FollowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  /// Follow a user
  Future<void> followUser(String targetUserId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || currentUserId == targetUserId) return;

    try {
      await _firestore.runTransaction((tx) async {
        final followingRef = _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('following')
            .doc(targetUserId);

        final followerRef = _firestore
            .collection('users')
            .doc(targetUserId)
            .collection('followers')
            .doc(currentUserId);

        final currentUserRef =
            _firestore.collection('users').doc(currentUserId);
        final targetUserRef = _firestore.collection('users').doc(targetUserId);

        // Prevent double-follow (and double counter increments)
        final followingSnap = await tx.get(followingRef);
        if (followingSnap.exists) {
          debugPrint('ℹ️ Already following: $targetUserId');
          return;
        }

        // Create follow docs
        tx.set(followingRef, {
          'followedAt': FieldValue.serverTimestamp(),
          'userId': targetUserId,
        });

        tx.set(followerRef, {
          'followedAt': FieldValue.serverTimestamp(),
          'userId': currentUserId,
        });

        // Update counters safely (server-side numeric increments)
        tx.update(currentUserRef, {
          'followingCount': FieldValue.increment(1),
        });

        tx.update(targetUserRef, {
          'followersCount': FieldValue.increment(1),
        });
      });

      // Create follow notification (outside transaction for better error handling)
      try {
        final currentUserDoc = await _firestore.collection('users').doc(currentUserId).get();
        final currentUserData = currentUserDoc.data();

        await _notificationService.createFollowNotification(
          targetUserId: targetUserId,
          followerUserId: currentUserId,
          followerUsername: currentUserData?['displayName'] ?? 'Someone',
          followerPhotoUrl: currentUserData?['photoUrl'],
        );
      } catch (notifError) {
        debugPrint('⚠️ Failed to create follow notification: $notifError');
        // Don't rethrow - follow was successful, notification is optional
      }

      debugPrint('✅ Followed user: $targetUserId');
    } catch (e) {
      debugPrint('❌ Error following user: $e');
      rethrow;
    }
  }

  /// Unfollow a user
  Future<void> unfollowUser(String targetUserId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || currentUserId == targetUserId) return;

    try {
      await _firestore.runTransaction((tx) async {
        final followingRef = _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('following')
            .doc(targetUserId);

        final followerRef = _firestore
            .collection('users')
            .doc(targetUserId)
            .collection('followers')
            .doc(currentUserId);

        final currentUserRef =
            _firestore.collection('users').doc(currentUserId);
        final targetUserRef = _firestore.collection('users').doc(targetUserId);

        // If not following, do nothing
        final followingSnap = await tx.get(followingRef);
        if (!followingSnap.exists) {
          debugPrint('ℹ️ Not following (nothing to unfollow): $targetUserId');
          return;
        }

        // Delete follow docs
        tx.delete(followingRef);
        tx.delete(followerRef);

        // Decrement counters but never go below 0 if fields exist
        final currentUserSnap = await tx.get(currentUserRef);
        final targetUserSnap = await tx.get(targetUserRef);

        final currentFollowing =
            (currentUserSnap.data()?['followingCount'] as int?) ?? 0;
        final targetFollowers =
            (targetUserSnap.data()?['followersCount'] as int?) ?? 0;

        tx.update(currentUserRef, {
          'followingCount': currentFollowing > 0
              ? FieldValue.increment(-1)
              : FieldValue.increment(0),
        });

        tx.update(targetUserRef, {
          'followersCount': targetFollowers > 0
              ? FieldValue.increment(-1)
              : FieldValue.increment(0),
        });
      });

      debugPrint('✅ Unfollowed user: $targetUserId');
    } catch (e) {
      debugPrint('❌ Error unfollowing user: $e');
      rethrow;
    }
  }

  /// Check if current user is following target user
  Future<bool> isFollowing(String targetUserId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return false;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(targetUserId)
          .get();

      return doc.exists;
    } catch (e) {
      debugPrint('❌ Error checking follow status: $e');
      return false;
    }
  }

  /// Get follower count (from cached counter)
  Future<int> getFollowerCount(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return (doc.data()?['followersCount'] as int?) ?? 0;
    } catch (e) {
      debugPrint('❌ Error getting follower count: $e');
      return 0;
    }
  }

  /// Get following count (from cached counter)
  Future<int> getFollowingCount(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return (doc.data()?['followingCount'] as int?) ?? 0;
    } catch (e) {
      debugPrint('❌ Error getting following count: $e');
      return 0;
    }
  }

  /// Stream of followers
  Stream<List<Map<String, dynamic>>> getFollowersStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('followers')
        .orderBy('followedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final followers = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final followerId = doc.data()['userId'] as String;
        final userDoc =
            await _firestore.collection('users').doc(followerId).get();
        if (userDoc.exists) {
          followers.add({
            'id': followerId,
            'name': userDoc.data()?['displayName'] ?? 'Unknown',
            'photoUrl': userDoc.data()?['photoUrl'] ?? '',
            'followedAt': doc.data()['followedAt'],
          });
        }
      }
      return followers;
    });
  }

  /// Stream of following
  Stream<List<Map<String, dynamic>>> getFollowingStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('following')
        .orderBy('followedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final following = <Map<String, dynamic>>[];
      for (final doc in snapshot.docs) {
        final followingId = doc.data()['userId'] as String;
        final userDoc =
            await _firestore.collection('users').doc(followingId).get();
        if (userDoc.exists) {
          following.add({
            'id': followingId,
            'name': userDoc.data()?['displayName'] ?? 'Unknown',
            'photoUrl': userDoc.data()?['photoUrl'] ?? '',
            'followedAt': doc.data()['followedAt'],
          });
        }
      }
      return following;
    });
  }

  /// Initialize counters for existing users (run once for migration)
  Future<void> initializeCounters(String userId) async {
    try {
      final followersCount = await _firestore
          .collection('users')
          .doc(userId)
          .collection('followers')
          .count()
          .get();

      final followingCount = await _firestore
          .collection('users')
          .doc(userId)
          .collection('following')
          .count()
          .get();

      await _firestore.collection('users').doc(userId).set({
        'followersCount': followersCount.count ?? 0,
        'followingCount': followingCount.count ?? 0,
      }, SetOptions(merge: true));

      debugPrint('✅ Initialized counters for user: $userId');
    } catch (e) {
      debugPrint('❌ Error initializing counters: $e');
    }
  }
}