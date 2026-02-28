import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:majurun/modules/dm/domain/entities/conversation.dart';
import 'package:majurun/modules/dm/domain/entities/message.dart';
import 'package:majurun/modules/dm/domain/entities/user_privacy.dart';
import 'package:majurun/core/services/notification_service.dart';

class DmService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ==================== CONVERSATIONS ====================

  /// Get stream of conversations for current user
  Stream<List<Conversation>> getConversationsStream() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return Stream.error('Not logged in');

    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .limit(50) // Pagination: limit conversations loaded
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Conversation.fromFirestore(doc);
          }).toList();
        });
  }

  /// Get total unread count for current user
  Stream<int> getTotalUnreadCountStream() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return Stream.error('Not logged in');

    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .limit(100) // Limit for performance
        .snapshots()
        .map((snapshot) {
          int totalUnread = 0;
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final unreadCount = data['unreadCount'] as Map<String, dynamic>?;
            totalUnread += (unreadCount?[currentUserId] as int? ?? 0);
          }
          return totalUnread;
        });
  }

  /// Get or create a conversation between two users
  Future<String?> getOrCreateConversation({
    required String currentUserId,
    required String otherUserId,
    required String currentUserName,
    required String otherUserName,
    String? currentUserPhoto,
    String? otherUserPhoto,
  }) async {
    try {
      // Check if conversation already exists
      final querySnapshot = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: currentUserId)
          .get();

      for (var doc in querySnapshot.docs) {
        final participants = List<String>.from(doc['participants'] ?? []);
        if (participants.contains(otherUserId)) {
          return doc.id;
        }
      }

      // Create new conversation
      final conversationRef = _firestore.collection('conversations').doc();
      
      final participantNames = {
        currentUserId: currentUserName,
        otherUserId: otherUserName,
      };
      
      final participantPhotos = {
        if (currentUserPhoto != null) currentUserId: currentUserPhoto,
        if (otherUserPhoto != null) otherUserId: otherUserPhoto,
      };

      await conversationRef.set({
        'participants': [currentUserId, otherUserId],
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': {
          currentUserId: 0,
          otherUserId: 0,
        },
        'participantNames': participantNames,
        'participantPhotos': participantPhotos,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return conversationRef.id;
    } catch (e) {
      log('❌ Error creating conversation: $e');
      return null;
    }
  }

  /// Mark conversation as read for current user
  Future<void> markConversationAsRead(String conversationId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      await _firestore.collection('conversations').doc(conversationId).update({
        'unreadCount.$currentUserId': 0,
      });
    } catch (e) {
      log('❌ Error marking conversation as read: $e');
    }
  }

  /// Delete conversation
  Future<void> deleteConversation(String conversationId) async {
    try {
      await _firestore.collection('conversations').doc(conversationId).delete();
      
      // Also delete all messages in the conversation
      final messages = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .get();
          
      for (var doc in messages.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      log('❌ Error deleting conversation: $e');
      rethrow;
    }
  }

  // ==================== MESSAGES ====================

  /// Get stream of messages for a conversation
  Stream<List<Message>> getMessagesStream(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true) // Get latest first
        .limit(100) // Limit messages loaded initially
        .snapshots()
        .map((snapshot) {
          // Reverse to show oldest first in UI
          return snapshot.docs.reversed.map((doc) {
            return Message.fromFirestore(doc);
          }).toList();
        });
  }

  /// Send a new message
  Future<void> sendMessage({
    required String conversationId,
    required String content,
    MessageType type = MessageType.text,
    Map<String, dynamic>? metadata,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception('Not logged in');

    try {
      // Get conversation to find other participant
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();
      
      if (!conversationDoc.exists) throw Exception('Conversation not found');
      
      final participants = List<String>.from(conversationDoc.data()?['participants'] ?? []);
      final otherUserId = participants.firstWhere((id) => id != currentUserId);
      
      // Check if you're blocked
      final canSend = await canSendMessage(currentUserId, otherUserId);
      if (!canSend) {
        throw Exception('Cannot send message to this user');
      }

      // Create message
      final messageRef = _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc();

      final message = Message(
        id: messageRef.id,
        senderId: currentUserId,
        content: content,
        type: type,
        createdAt: DateTime.now(),
        metadata: metadata,
      );

      await messageRef.set(message.toMap());

      // Update conversation
      await _firestore.collection('conversations').doc(conversationId).update({
        'lastMessage': content,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount.$otherUserId': FieldValue.increment(1),
      });

      // ✅ Create DM notification
      try {
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          await NotificationService().createDmNotification(
            targetUserId: otherUserId,
            senderUserId: currentUserId,
            senderUsername: currentUser.displayName ?? 'Runner',
            senderPhotoUrl: currentUser.photoURL,
            conversationId: conversationId,
          );
          log('💬 DM notification sent to $otherUserId');
        }
      } catch (e) {
        log('❌ Error creating DM notification: $e');
        // Don't throw - notification failure shouldn't block message sending
      }

      log('✅ Message sent successfully');
    } catch (e) {
      log('❌ Error sending message: $e');
      rethrow;
    }
  }

  /// Mark message as read
  Future<void> markMessageAsRead(String conversationId, String messageId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .update({
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      log('❌ Error marking message as read: $e');
    }
  }

  // ==================== BLOCKING ====================

  /// Block a user
  Future<void> blockUser(String currentUserId, String userToBlockId) async {
    try {
      // Get user info for the blocked user
      final userDoc = await _firestore
          .collection('users')
          .doc(userToBlockId)
          .get();
      
      final userName = userDoc.data()?['displayName'] ?? 'Unknown User';
      final userPhoto = userDoc.data()?['photoUrl'] as String?;

      final blockRef = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blockedUsers')
          .doc(userToBlockId);
      
      await blockRef.set({
        'userId': currentUserId,
        'blockedUserId': userToBlockId,
        'blockedUserName': userName,
        'blockedUserPhoto': userPhoto,
        'blockedAt': FieldValue.serverTimestamp(),
      });
      
      // Archive conversations with this user
      await _archiveConversationsWithUser(currentUserId, userToBlockId);
      
      log('✅ User $userToBlockId blocked successfully');
    } catch (e) {
      log('❌ Error blocking user: $e');
      rethrow;
    }
  }

  /// Unblock a user
  Future<void> unblockUser(String currentUserId, String blockedUserId) async {
    try {
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blockedUsers')
          .doc(blockedUserId)
          .delete();
      
      log('✅ User $blockedUserId unblocked successfully');
    } catch (e) {
      log('❌ Error unblocking user: $e');
      rethrow;
    }
  }

  /// Check if user is blocked (either direction)
  Future<bool> checkIfBlocked(String currentUserId, String otherUserId) async {
    try {
      // Check if current user blocked other user
      final blockDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('blockedUsers')
          .doc(otherUserId)
          .get();
      
      if (blockDoc.exists) return true;
      
      // Check if other user blocked current user
      final otherBlockDoc = await _firestore
          .collection('users')
          .doc(otherUserId)
          .collection('blockedUsers')
          .doc(currentUserId)
          .get();
      
      return otherBlockDoc.exists;
    } catch (e) {
      log('❌ Error checking block status: $e');
      return false; // Assume not blocked on error
    }
  }

  /// Stream blocked users
  Stream<List<Map<String, dynamic>>> getBlockedUsersStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('blockedUsers')
        .orderBy('blockedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'userId': doc.id,
              ...data,
            };
          }).toList();
        });
  }

  /// Archive conversations with blocked user
  Future<void> _archiveConversationsWithUser(String userId, String blockedUserId) async {
    try {
      final conversations = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: userId)
          .get();
      
      for (var doc in conversations.docs) {
        final participants = List<String>.from(doc['participants'] ?? []);
        if (participants.contains(blockedUserId)) {
          // Mark as archived for this user
          await doc.reference.update({
            'archivedFor.$userId': true,
            'archivedAt.$userId': FieldValue.serverTimestamp(),
          });
          log('📦 Archived conversation ${doc.id} for user $userId');
        }
      }
    } catch (e) {
      log('❌ Error archiving conversations: $e');
    }
  }

  // ==================== PRIVACY ====================

  /// Update privacy settings
  Future<void> updatePrivacySettings(String userId, UserPrivacy privacy) async {
    try {
      await _firestore
          .collection('userPrivacy')
          .doc(userId)
          .set(privacy.toMap());
      
      log('✅ Privacy settings updated for $userId');
    } catch (e) {
      log('❌ Error updating privacy settings: $e');
      rethrow;
    }
  }

  /// Get privacy settings for a user
  Future<UserPrivacy?> getPrivacySettings(String userId) async {
    try {
      final doc = await _firestore
          .collection('userPrivacy')
          .doc(userId)
          .get();
      
      if (doc.exists) {
        return UserPrivacy.fromFirestore(doc.data()!, userId);
      }
      return null;
    } catch (e) {
      log('❌ Error getting privacy settings: $e');
      return null;
    }
  }

  /// Check if user can send message to another user
  Future<bool> canSendMessage(String senderId, String receiverId) async {
    try {
      // Check blocks first
      final isBlocked = await checkIfBlocked(senderId, receiverId);
      if (isBlocked) {
        log('⛔ Cannot send: User is blocked');
        return false;
      }
      
      // Check privacy settings
      final privacy = await getPrivacySettings(receiverId);
      if (privacy == null) {
        log('✅ No privacy settings, default to everyone');
        return true; // Default to everyone
      }
      
      switch (privacy.messagePrivacy) {
        case MessagePrivacy.everyone:
          log('✅ Privacy: everyone can message');
          return true;
          
        case MessagePrivacy.followersOnly:
          log('🔍 Checking if sender follows receiver...');
          // Check if sender follows receiver
          final followDoc = await _firestore
              .collection('users')
              .doc(receiverId)
              .collection('followers')
              .doc(senderId)
              .get();
          
          final canSend = followDoc.exists;
          log(canSend ? '✅ Sender follows receiver' : '⛔ Sender does not follow receiver');
          return canSend;
          
        case MessagePrivacy.noOne:
          log('⛔ Privacy: no one can message');
          return false;
      }
    } catch (e) {
      log('❌ Error checking message permission: $e');
      return false; // Deny on error for safety
    }
  }
}