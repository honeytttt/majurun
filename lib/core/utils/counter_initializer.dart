import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ONE-TIME SETUP: Initialize follower/following counters for your user
/// 
/// HOW TO USE:
/// 1. Add this file to your project temporarily
/// 2. Call initializeMyCounters() once from your app (e.g., in a button or on app start)
/// 3. Remove this file after running once
/// 
/// This will add followersCount and followingCount fields to your user document

class CounterInitializer {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initialize counters for the current logged-in user
  static Future<void> initializeMyCounters() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    if (currentUserId == null) {
      debugPrint('❌ No user logged in');
      return;
    }

    try {
      debugPrint('🔄 Initializing counters for user: $currentUserId');
      
      // Count followers
      final followersSnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('followers')
          .get();
      
      final followersCount = followersSnapshot.docs.length;
      debugPrint('📊 Followers: $followersCount');

      // Count following
      final followingSnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .get();
      
      final followingCount = followingSnapshot.docs.length;
      debugPrint('📊 Following: $followingCount');

      // Update user document
      await _firestore.collection('users').doc(currentUserId).set({
        'followersCount': followersCount,
        'followingCount': followingCount,
      }, SetOptions(merge: true));

      debugPrint('✅ Counters initialized successfully!');
      debugPrint('   - followersCount: $followersCount');
      debugPrint('   - followingCount: $followingCount');
      
    } catch (e) {
      debugPrint('❌ Error initializing counters: $e');
    }
  }

  /// Initialize counters for ALL users — paginated to avoid loading all users at once
  /// ⚠️ ADMIN USE ONLY — Run once, then remove call
  static Future<void> initializeAllUsersCounters() async {
    try {
      debugPrint('🔄 Starting paginated bulk initialization...');
      int processed = 0;
      DocumentSnapshot? lastDoc;
      const pageSize = 100;

      while (true) {
        // Fetch next page of users
        Query query = _firestore.collection('users').limit(pageSize);
        if (lastDoc != null) query = query.startAfterDocument(lastDoc);

        final usersSnapshot = await query.get();
        if (usersSnapshot.docs.isEmpty) break;

        for (final userDoc in usersSnapshot.docs) {
          final userId = userDoc.id;

          final followersSnapshot = await _firestore
              .collection('users').doc(userId).collection('followers').get();
          final followingSnapshot = await _firestore
              .collection('users').doc(userId).collection('following').get();

          await _firestore.collection('users').doc(userId).set({
            'followersCount': followersSnapshot.docs.length,
            'followingCount': followingSnapshot.docs.length,
          }, SetOptions(merge: true));

          processed++;
        }

        debugPrint('✅ Processed $processed users so far...');
        lastDoc = usersSnapshot.docs.last;

        // All users in this page processed — stop if last page
        if (usersSnapshot.docs.length < pageSize) break;
      }

      debugPrint('✅ Bulk initialization complete! Total: $processed users');
    } catch (e) {
      debugPrint('❌ Error in bulk initialization: $e');
    }
  }
}

/// Example usage in a temporary button/screen:
/// 
/// ElevatedButton(
///   onPressed: () async {
///     await CounterInitializer.initializeMyCounters();
///     ScaffoldMessenger.of(context).showSnackBar(
///       const SnackBar(content: Text('Counters initialized! Check console.')),
///     );
///   },
///   child: const Text('Initialize My Counters'),
/// )