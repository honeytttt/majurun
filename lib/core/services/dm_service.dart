import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:majurun/modules/dm/domain/entities/conversation.dart';
import 'package:majurun/modules/dm/domain/entities/message.dart';
import 'package:majurun/core/services/notification_service.dart';

class DmService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  /// Get or create a conversation with another user
  Future<String> getOrCreateConversation(String otherUserId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) throw Exception('Not authenticated');

    // Check if conversation already exists
    final existingQuery = await _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .get();

    for (final doc in existingQuery.docs) {
      final participants = List<String>.from(doc.data()['participants'] ?? []);
      if (participants.contains(otherUserId) && participants.length == 2) {
        debugPrint('💬 Found existing conversation: ${doc.id}');
        return doc.id;
      }
    }

    // Get user data for both participants
    final currentUserDoc = await _firestore.collection('users').doc(currentUserId).get();
    final otherUserDoc = await _firestore.collection('users').doc(otherUserId).get();

    final currentUserData = currentUserDoc.data() ?? {};
    final otherUserData = otherUserDoc.data() ?? {};

    // Create new conversation
    final conversationRef = await _firestore.collection('conversations').add({
      'participants': [currentUserId, otherUserId],
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCount': {
        currentUserId: 0,
        otherUserId: 0,
      },
      'participantNames': {
        currentUserId: currentUserData['displayName'] ?? 'Unknown',
        otherUserId: otherUserData['displayName'] ?? 'Unknown',
      },
      'participantPhotos': {
        currentUserId: currentUserData['photoUrl'] ?? '',
        otherUserId: otherUserData['photoUrl'] ?? '',
      },
      'createdAt': FieldValue.serverTimestamp(),
    });

    debugPrint('💬 Created new conversation: ${conversationRef.id}');
    return conversationRef.id;
  }

  /// Stream conversations for current user
  Stream<List<Conversation>> getConversationsStream() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Conversation.fromFirestore(doc))
          .toList();
    });
  }

  /// Stream messages for a conversation
  Stream<List<Message>> getMessagesStream(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Message.fromFirestore(doc))
          .toList();
    });
  }

  /// Send a message
  Future<void> sendMessage({
    required String conversationId,
    required String content,
    MessageType type = MessageType.text,
    Map<String, dynamic>? metadata,
  }) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) throw Exception('Not authenticated');

    final conversationRef = _firestore.collection('conversations').doc(conversationId);

    // Get conversation to find other participant
    final conversationDoc = await conversationRef.get();
    if (!conversationDoc.exists) throw Exception('Conversation not found');

    final conversation = Conversation.fromFirestore(conversationDoc);
    final otherUserId = conversation.getOtherParticipantId(currentUserId);

    // Add message
    final messageRef = conversationRef.collection('messages').doc();
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
    await conversationRef.update({
      'lastMessage': type == MessageType.text ? content : '[${type.name}]',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCount.$otherUserId': FieldValue.increment(1),
    });

    debugPrint('💬 Message sent in conversation: $conversationId');

    // Send notification to other user
    try {
      final currentUserDoc = await _firestore.collection('users').doc(currentUserId).get();
      final currentUserData = currentUserDoc.data() ?? {};

      await _notificationService.createDmNotification(
        targetUserId: otherUserId,
        senderUserId: currentUserId,
        senderUsername: currentUserData['displayName'] ?? 'Someone',
        senderPhotoUrl: currentUserData['photoUrl'],
        conversationId: conversationId,
      );
    } catch (e) {
      debugPrint('⚠️ Failed to send DM notification: $e');
    }
  }

  /// Mark messages as read
  Future<void> markConversationAsRead(String conversationId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .update({
        'unreadCount.$currentUserId': 0,
      });

      debugPrint('✅ Marked conversation as read: $conversationId');
    } catch (e) {
      debugPrint('❌ Error marking conversation as read: $e');
    }
  }

  /// Get total unread message count
  Stream<int> getTotalUnreadCountStream() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return Stream.value(0);

    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
      int total = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final unreadCount = (data['unreadCount'] as Map<String, dynamic>?)?[currentUserId];
        if (unreadCount != null) {
          total += (unreadCount as num).toInt();
        }
      }
      return total;
    });
  }

  /// Delete a conversation (for current user only - soft delete)
  Future<void> deleteConversation(String conversationId) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    // For now, just mark as deleted for the user (could add deletedFor field)
    // Full deletion would require checking if both users deleted
    try {
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .update({
        'deletedFor.$currentUserId': true,
      });
      debugPrint('🗑️ Conversation deleted for user: $conversationId');
    } catch (e) {
      debugPrint('❌ Error deleting conversation: $e');
    }
  }
}
