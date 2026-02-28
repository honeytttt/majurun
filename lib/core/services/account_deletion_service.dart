import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for handling account deletion (GDPR/CCPA compliance)
class AccountDeletionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Delete all user data and account
  /// Returns true if successful, false otherwise
  Future<bool> deleteAccount({
    required String userId,
    String? reauthPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.uid != userId) {
        debugPrint('AccountDeletion: User not authenticated');
        return false;
      }

      // Re-authenticate if password provided (required for some operations)
      if (reauthPassword != null && user.email != null) {
        try {
          final credential = EmailAuthProvider.credential(
            email: user.email!,
            password: reauthPassword,
          );
          await user.reauthenticateWithCredential(credential);
        } catch (e) {
          debugPrint('AccountDeletion: Re-authentication failed: $e');
          // Continue anyway - some providers don't need re-auth
        }
      }

      // Delete user data from Firestore (in order of dependencies)
      await _deleteUserData(userId);

      // Delete Firebase Auth account
      await user.delete();

      // Clear local storage
      await _clearLocalData();

      debugPrint('AccountDeletion: Account deleted successfully');
      return true;
    } catch (e) {
      debugPrint('AccountDeletion: Error deleting account: $e');
      return false;
    }
  }

  /// Delete all user data from Firestore
  Future<void> _deleteUserData(String userId) async {
    final batch = _firestore.batch();

    try {
      // 1. Delete user's runs
      final runsSnapshot = await _firestore
          .collection('runs')
          .where('userId', isEqualTo: userId)
          .get();
      for (final doc in runsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // 2. Delete user's posts
      final postsSnapshot = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .get();
      for (final doc in postsSnapshot.docs) {
        // Delete comments on each post
        final commentsSnapshot = await doc.reference.collection('comments').get();
        for (final comment in commentsSnapshot.docs) {
          batch.delete(comment.reference);
        }
        batch.delete(doc.reference);
      }

      // 3. Delete user's conversations and messages
      final conversationsSnapshot = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: userId)
          .get();
      for (final doc in conversationsSnapshot.docs) {
        final messagesSnapshot = await doc.reference.collection('messages').get();
        for (final message in messagesSnapshot.docs) {
          batch.delete(message.reference);
        }
        batch.delete(doc.reference);
      }

      // 4. Delete user's notifications
      final notificationsSnapshot = await _firestore
          .collection('notifications')
          .doc(userId)
          .collection('items')
          .get();
      for (final doc in notificationsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // 5. Delete followers/following relationships
      final followersSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('followers')
          .get();
      for (final doc in followersSnapshot.docs) {
        batch.delete(doc.reference);
      }

      final followingSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('following')
          .get();
      for (final doc in followingSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // 6. Delete daily/weekly/monthly challenges
      final dailyChallengesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('dailyChallenges')
          .get();
      for (final doc in dailyChallengesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // 7. Delete the user document itself
      batch.delete(_firestore.collection('users').doc(userId));

      // Commit all deletions
      await batch.commit();

      debugPrint('AccountDeletion: All Firestore data deleted');
    } catch (e) {
      debugPrint('AccountDeletion: Error deleting Firestore data: $e');
      rethrow;
    }
  }

  /// Clear local storage data
  Future<void> _clearLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      debugPrint('AccountDeletion: Local data cleared');
    } catch (e) {
      debugPrint('AccountDeletion: Error clearing local data: $e');
    }
  }

  /// Request data export (GDPR right to data portability)
  Future<Map<String, dynamic>> exportUserData(String userId) async {
    try {
      final userData = <String, dynamic>{};

      // Get user profile
      final userDoc = await _firestore.collection('users').doc(userId).get();
      userData['profile'] = userDoc.data();

      // Get runs
      final runsSnapshot = await _firestore
          .collection('runs')
          .where('userId', isEqualTo: userId)
          .get();
      userData['runs'] = runsSnapshot.docs.map((d) => d.data()).toList();

      // Get posts
      final postsSnapshot = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .get();
      userData['posts'] = postsSnapshot.docs.map((d) => d.data()).toList();

      // Add export metadata
      userData['exportDate'] = DateTime.now().toIso8601String();
      userData['userId'] = userId;

      return userData;
    } catch (e) {
      debugPrint('AccountDeletion: Error exporting data: $e');
      return {'error': e.toString()};
    }
  }

  /// Show confirmation dialog and handle deletion
  static Future<bool> showDeleteConfirmationDialog({
    required dynamic context, // BuildContext
    required String userId,
    required Function(String) onError,
    required Function() onSuccess,
  }) async {
    // This would be implemented in the UI layer
    // The service just handles the data deletion
    return false;
  }
}
