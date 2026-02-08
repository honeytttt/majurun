import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Automatic one-time initialization of follower counters
/// Call this from main.dart or your auth wrapper
class UserCountersInitializer {
  static Future<void> initializeOnFirstLaunch() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'counters_initialized_${currentUser.uid}';
      final hasInitialized = prefs.getBool(key) ?? false;

      if (!hasInitialized) {
        debugPrint('🔄 First launch detected, initializing counters...');
        await _ensureUserDocumentHasCounters(currentUser.uid);
        await prefs.setBool(key, true);
        debugPrint('✅ Counters initialized successfully!');
      }
    } catch (e) {
      debugPrint('❌ Error during initialization: $e');
    }
  }

  static Future<void> _ensureUserDocumentHasCounters(String userId) async {
    final firestore = FirebaseFirestore.instance;
    final userDoc = await firestore.collection('users').doc(userId).get();

    if (!userDoc.exists) {
      // Create user document if it doesn't exist
      final currentUser = FirebaseAuth.instance.currentUser;
      await firestore.collection('users').doc(userId).set({
        'displayName': currentUser?.displayName ?? 'Runner',
        'email': currentUser?.email ?? '',
        'photoUrl': currentUser?.photoURL ?? '',
        'bio': '',
        'followersCount': 0,
        'followingCount': 0,
        // Initialize stats fields
        'workoutsCount': 0,
        'totalKm': 0.0,
        'totalRunSeconds': 0,
        'totalCalories': 0,
        'postsCount': 0,
        // Initialize badge fields
        'badge5k': 0,
        'badge10k': 0,
        'badgeHalf': 0,
        'badgeFull': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ User document created with counters and stats');
      return;
    }

    // Check if counters and stats exist
    final data = userDoc.data() ?? {};
    final updates = <String, dynamic>{};

    // Check follow counters
    if (data['followersCount'] == null || data['followingCount'] == null) {
      final followersSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('followers')
          .get();

      final followingSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('following')
          .get();

      updates['followersCount'] = followersSnapshot.docs.length;
      updates['followingCount'] = followingSnapshot.docs.length;
    }

    // Check stats fields and initialize if missing
    if (data['workoutsCount'] == null) updates['workoutsCount'] = 0;
    if (data['totalKm'] == null) updates['totalKm'] = 0.0;
    if (data['totalRunSeconds'] == null) updates['totalRunSeconds'] = 0;
    if (data['totalCalories'] == null) updates['totalCalories'] = 0;
    if (data['postsCount'] == null) updates['postsCount'] = 0;

    // Check badge fields
    if (data['badge5k'] == null) updates['badge5k'] = 0;
    if (data['badge10k'] == null) updates['badge10k'] = 0;
    if (data['badgeHalf'] == null) updates['badgeHalf'] = 0;
    if (data['badgeFull'] == null) updates['badgeFull'] = 0;

    if (updates.isNotEmpty) {
      await firestore.collection('users').doc(userId).update(updates);
      debugPrint('✅ Counters and stats added/updated: ${updates.keys.join(', ')}');
    } else {
      debugPrint('✅ All counters and stats already exist');
    }
  }
}