import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Handles user and content reports. Reports are written to the top-level
/// `reports` collection for admin review.
class ReportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> reportPost({
    required String reporterId,
    required String postId,
    required String postOwnerId,
    required String reason,
  }) async {
    try {
      await _db.collection('reports').add({
        'type': 'post',
        'reporterId': reporterId,
        'targetId': postId,
        'targetOwnerId': postOwnerId,
        'reason': reason,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Post reported: $postId ($reason)');
    } catch (e) {
      debugPrint('❌ reportPost error: $e');
      rethrow;
    }
  }

  Future<void> reportUser({
    required String reporterId,
    required String reportedUserId,
    required String reason,
  }) async {
    try {
      await _db.collection('reports').add({
        'type': 'user',
        'reporterId': reporterId,
        'targetId': reportedUserId,
        'reason': reason,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ User reported: $reportedUserId ($reason)');
    } catch (e) {
      debugPrint('❌ reportUser error: $e');
      rethrow;
    }
  }

  Future<void> reportMessage({
    required String reporterId,
    required String messageId,
    required String conversationId,
    required String senderId,
    required String reason,
  }) async {
    try {
      await _db.collection('reports').add({
        'type': 'message',
        'reporterId': reporterId,
        'targetId': messageId,
        'conversationId': conversationId,
        'targetOwnerId': senderId,
        'reason': reason,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Message reported: $messageId ($reason)');
    } catch (e) {
      debugPrint('❌ reportMessage error: $e');
      rethrow;
    }
  }
}
