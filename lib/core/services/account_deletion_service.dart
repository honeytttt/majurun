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
    } on FirebaseAuthException {
      // Let FirebaseAuthException (e.g. requires-recent-login) bubble up
      // so the UI layer can handle re-authentication.
      rethrow;
    } catch (e) {
      debugPrint('AccountDeletion: Error deleting account: $e');
      return false;
    }
  }

  // Firestore batch max is 500 ops — commit in safe chunks of 400
  Future<void> _commitRefs(List<DocumentReference> refs) async {
    const chunkSize = 400;
    for (int i = 0; i < refs.length; i += chunkSize) {
      final chunk = refs.sublist(i, (i + chunkSize).clamp(0, refs.length));
      final batch = _firestore.batch();
      for (final ref in chunk) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  /// Delete all user data from Firestore
  Future<void> _deleteUserData(String userId) async {
    try {
      final refs = <DocumentReference>[];

      // 1. User's runs
      final runsSnapshot = await _firestore
          .collection('runs')
          .where('userId', isEqualTo: userId)
          .get();
      refs.addAll(runsSnapshot.docs.map((d) => d.reference));

      // 2. User's posts + nested comments
      final postsSnapshot = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .get();
      for (final doc in postsSnapshot.docs) {
        final comments = await doc.reference.collection('comments').get();
        refs.addAll(comments.docs.map((d) => d.reference));
        refs.add(doc.reference);
      }

      // 3. Conversations + nested messages
      final convsSnapshot = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: userId)
          .get();
      for (final doc in convsSnapshot.docs) {
        final messages = await doc.reference.collection('messages').get();
        refs.addAll(messages.docs.map((d) => d.reference));
        refs.add(doc.reference);
      }

      // 4. Notifications
      final notifSnapshot = await _firestore
          .collection('notifications')
          .doc(userId)
          .collection('items')
          .get();
      refs.addAll(notifSnapshot.docs.map((d) => d.reference));

      // 5. Followers / following
      final followersSnap = await _firestore
          .collection('users').doc(userId).collection('followers').get();
      refs.addAll(followersSnap.docs.map((d) => d.reference));

      final followingSnap = await _firestore
          .collection('users').doc(userId).collection('following').get();
      refs.addAll(followingSnap.docs.map((d) => d.reference));

      // 6. Daily challenges
      final challengesSnap = await _firestore
          .collection('users').doc(userId).collection('dailyChallenges').get();
      refs.addAll(challengesSnap.docs.map((d) => d.reference));

      // 7. Saved posts
      final savedPostsSnap = await _firestore
          .collection('users').doc(userId).collection('savedPosts').get();
      refs.addAll(savedPostsSnap.docs.map((d) => d.reference));

      // 8. User document itself
      refs.add(_firestore.collection('users').doc(userId));

      // Commit in safe chunks (Firestore batch limit = 500)
      await _commitRefs(refs);

      debugPrint('AccountDeletion: All Firestore data deleted (${refs.length} docs)');
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
