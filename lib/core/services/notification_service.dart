import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:majurun/modules/notifications/domain/entities/app_notification.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get the current user's notification collection reference
  CollectionReference<Map<String, dynamic>> _notificationsRef(String userId) {
    return _firestore.collection('notifications').doc(userId).collection('items');
  }

  /// Stream notifications for current user
  Stream<List<AppNotification>> getNotificationsStream() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _notificationsRef(userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AppNotification.fromFirestore(doc))
          .toList();
    });
  }

  /// Get unread notification count
  Stream<int> getUnreadCountStream() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return Stream.value(0);

    return _notificationsRef(userId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Create a notification for a user
  Future<void> createNotification({
    required String targetUserId,
    required NotificationType type,
    required String fromUserId,
    required String fromUsername,
    String? fromUserPhotoUrl,
    required String message,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final notification = AppNotification(
        id: '', // Will be set by Firestore
        type: type,
        fromUserId: fromUserId,
        fromUsername: fromUsername,
        fromUserPhotoUrl: fromUserPhotoUrl,
        message: message,
        read: false,
        createdAt: DateTime.now(),
        metadata: metadata,
      );

      await _notificationsRef(targetUserId).add(notification.toMap());
      debugPrint('🔔 Notification created for $targetUserId: $message');
    } catch (e) {
      debugPrint('❌ Error creating notification: $e');
    }
  }

  /// Create follow notification
  Future<void> createFollowNotification({
    required String targetUserId,
    required String followerUserId,
    required String followerUsername,
    String? followerPhotoUrl,
  }) async {
    await createNotification(
      targetUserId: targetUserId,
      type: NotificationType.follow,
      fromUserId: followerUserId,
      fromUsername: followerUsername,
      fromUserPhotoUrl: followerPhotoUrl,
      message: '$followerUsername started following you',
    );
  }

  /// Create badge notification
  Future<void> createBadgeNotification({
    required String userId,
    required String badgeName,
    required String badgeDescription,
  }) async {
    await createNotification(
      targetUserId: userId,
      type: NotificationType.badge,
      fromUserId: 'system',
      fromUsername: 'Majurun',
      message: 'You earned the "$badgeName" badge! $badgeDescription',
      metadata: {'badgeName': badgeName},
    );
  }

  /// Create DM notification
  Future<void> createDmNotification({
    required String targetUserId,
    required String senderUserId,
    required String senderUsername,
    String? senderPhotoUrl,
    required String conversationId,
  }) async {
    await createNotification(
      targetUserId: targetUserId,
      type: NotificationType.dm,
      fromUserId: senderUserId,
      fromUsername: senderUsername,
      fromUserPhotoUrl: senderPhotoUrl,
      message: '$senderUsername sent you a message',
      metadata: {'conversationId': conversationId},
    );
  }

  /// Create post notification (for bell subscribers)
  Future<void> createPostNotification({
    required String targetUserId,
    required String posterUserId,
    required String posterUsername,
    String? posterPhotoUrl,
    required String postId,
  }) async {
    await createNotification(
      targetUserId: targetUserId,
      type: NotificationType.post,
      fromUserId: posterUserId,
      fromUsername: posterUsername,
      fromUserPhotoUrl: posterPhotoUrl,
      message: '$posterUsername shared a new post',
      metadata: {'postId': postId},
    );
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      await _notificationsRef(userId).doc(notificationId).update({'read': true});
      debugPrint('✅ Notification marked as read: $notificationId');
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final batch = _firestore.batch();
      final unreadDocs = await _notificationsRef(userId)
          .where('read', isEqualTo: false)
          .get();

      for (final doc in unreadDocs.docs) {
        batch.update(doc.reference, {'read': true});
      }

      await batch.commit();
      debugPrint('✅ All notifications marked as read');
    } catch (e) {
      debugPrint('❌ Error marking all notifications as read: $e');
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      await _notificationsRef(userId).doc(notificationId).delete();
      debugPrint('🗑️ Notification deleted: $notificationId');
    } catch (e) {
      debugPrint('❌ Error deleting notification: $e');
    }
  }

  // =============================================
  // BELL SUBSCRIPTION (User Post Notifications)
  // =============================================

  /// Subscribe to a user's posts (bell button)
  Future<void> subscribeToUser(String targetUserId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      await _firestore
          .collection('userNotificationSettings')
          .doc(currentUserId)
          .set({
        'subscribedUsers': FieldValue.arrayUnion([targetUserId]),
      }, SetOptions(merge: true));

      debugPrint('🔔 Subscribed to user: $targetUserId');
    } catch (e) {
      debugPrint('❌ Error subscribing to user: $e');
    }
  }

  /// Unsubscribe from a user's posts
  Future<void> unsubscribeFromUser(String targetUserId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      await _firestore
          .collection('userNotificationSettings')
          .doc(currentUserId)
          .update({
        'subscribedUsers': FieldValue.arrayRemove([targetUserId]),
      });

      debugPrint('🔕 Unsubscribed from user: $targetUserId');
    } catch (e) {
      debugPrint('❌ Error unsubscribing from user: $e');
    }
  }

  /// Check if current user is subscribed to a user
  Future<bool> isSubscribedToUser(String targetUserId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return false;

    try {
      final doc = await _firestore
          .collection('userNotificationSettings')
          .doc(currentUserId)
          .get();

      if (!doc.exists) return false;

      final subscribedUsers = List<String>.from(
        doc.data()?['subscribedUsers'] ?? [],
      );

      return subscribedUsers.contains(targetUserId);
    } catch (e) {
      debugPrint('❌ Error checking subscription: $e');
      return false;
    }
  }

  /// Stream subscription status
  Stream<bool> subscriptionStream(String targetUserId) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return Stream.value(false);

    return _firestore
        .collection('userNotificationSettings')
        .doc(currentUserId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return false;
      final subscribedUsers = List<String>.from(
        doc.data()?['subscribedUsers'] ?? [],
      );
      return subscribedUsers.contains(targetUserId);
    });
  }

  /// Get list of users who subscribed to a user (for sending post notifications)
  Future<List<String>> getSubscribers(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('userNotificationSettings')
          .where('subscribedUsers', arrayContains: userId)
          .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      debugPrint('❌ Error getting subscribers: $e');
      return [];
    }
  }

  /// Notify all subscribers when a user posts
  Future<void> notifySubscribersOfPost({
    required String posterUserId,
    required String posterUsername,
    String? posterPhotoUrl,
    required String postId,
  }) async {
    try {
      final subscribers = await getSubscribers(posterUserId);

      for (final subscriberId in subscribers) {
        await createPostNotification(
          targetUserId: subscriberId,
          posterUserId: posterUserId,
          posterUsername: posterUsername,
          posterPhotoUrl: posterPhotoUrl,
          postId: postId,
        );
      }

      debugPrint('🔔 Notified ${subscribers.length} subscribers of new post');
    } catch (e) {
      debugPrint('❌ Error notifying subscribers: $e');
    }
  }
}
