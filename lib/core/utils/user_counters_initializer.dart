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

      // Always sync badges from run history to ensure accuracy
      await syncBadgesFromRunHistory(currentUser.uid);
    } catch (e) {
      debugPrint('❌ Error during initialization: $e');
    }
  }

  /// Sync badges by recalculating from run history
  /// This ensures badges are accurate even if they weren't tracked properly before
  static Future<void> syncBadgesFromRunHistory(String userId) async {
    final firestore = FirebaseFirestore.instance;

    try {
      debugPrint('🔄 Syncing badges from run history for user: $userId');

      int badge5kCount = 0;
      int badge10kCount = 0;
      int badgeHalfCount = 0;
      int badgeFullCount = 0;

      // Track processed run timestamps to avoid duplicates
      final processedRuns = <String>{};

      // 1) Get all runs from training_history (primary source)
      final historySnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('training_history')
          .get();

      for (final doc in historySnapshot.docs) {
        final data = doc.data();
        final distanceKm = (data['distanceKm'] as num?)?.toDouble() ?? 0.0;
        final completed = data['completed'] as bool? ?? true;

        // Create a unique key based on distance and timestamp to detect duplicates
        final completedAt = (data['completedAt'] as Timestamp?)?.seconds.toString() ?? doc.id;
        final runKey = '${distanceKm.toStringAsFixed(2)}_$completedAt';

        if (!completed || processedRuns.contains(runKey)) continue;
        processedRuns.add(runKey);

        // Count badge-qualifying runs
        if (distanceKm >= 5.0) badge5kCount++;
        if (distanceKm >= 10.0) badge10kCount++;
        if (distanceKm >= 21.0975) badgeHalfCount++;
        if (distanceKm >= 42.195) badgeFullCount++;
      }

      // 2) Also check posts for run data (in case runs were posted but not in history)
      final postsSnapshot = await firestore
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in postsSnapshot.docs) {
        final data = doc.data();
        final distanceKm = (data['distanceKm'] as num?)?.toDouble() ?? 0.0;

        // Skip if no run data
        if (distanceKm <= 0) continue;

        // Create a unique key to detect if this run was already counted from history
        final createdAt = (data['createdAt'] as Timestamp?)?.seconds.toString() ?? doc.id;
        final runKey = '${distanceKm.toStringAsFixed(2)}_$createdAt';

        // Skip if already processed from training_history
        if (processedRuns.contains(runKey)) continue;
        processedRuns.add(runKey);

        // Count badge-qualifying runs from posts
        if (distanceKm >= 5.0) badge5kCount++;
        if (distanceKm >= 10.0) badge10kCount++;
        if (distanceKm >= 21.0975) badgeHalfCount++;
        if (distanceKm >= 42.195) badgeFullCount++;
      }

      debugPrint('📊 Found ${processedRuns.length} unique runs');
      debugPrint('🏅 Badge counts: 5k=$badge5kCount, 10k=$badge10kCount, half=$badgeHalfCount, full=$badgeFullCount');

      // Get current user data to compare
      final userDoc = await firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        debugPrint('⚠️ User document does not exist');
        return;
      }

      final currentData = userDoc.data() ?? {};
      final currentBadge5k = (currentData['badge5k'] as int?) ?? 0;
      final currentBadge10k = (currentData['badge10k'] as int?) ?? 0;
      final currentBadgeHalf = (currentData['badgeHalf'] as int?) ?? 0;
      final currentBadgeFull = (currentData['badgeFull'] as int?) ?? 0;

      // Sync workoutsCount to the actual number of completed runs in training_history
      final actualRunCount = historySnapshot.docs
          .where((d) => (d.data()['completed'] as bool?) ?? true)
          .length;
      final currentWorkoutsCount = (currentData['workoutsCount'] as int?) ?? 0;

      // Update badges if recalculated values differ
      final updates = <String, dynamic>{};

      if (badge5kCount != currentBadge5k) {
        updates['badge5k'] = badge5kCount;
        debugPrint('🏅 Updating badge5k: $currentBadge5k → $badge5kCount');
      }
      if (badge10kCount != currentBadge10k) {
        updates['badge10k'] = badge10kCount;
        debugPrint('🏅 Updating badge10k: $currentBadge10k → $badge10kCount');
      }
      if (badgeHalfCount != currentBadgeHalf) {
        updates['badgeHalf'] = badgeHalfCount;
        debugPrint('🏅 Updating badgeHalf: $currentBadgeHalf → $badgeHalfCount');
      }
      if (badgeFullCount != currentBadgeFull) {
        updates['badgeFull'] = badgeFullCount;
        debugPrint('🏅 Updating badgeFull: $currentBadgeFull → $badgeFullCount');
      }

      if (actualRunCount != currentWorkoutsCount) {
        updates['workoutsCount'] = actualRunCount;
        debugPrint('🔄 Syncing workoutsCount: $currentWorkoutsCount → $actualRunCount');
      }

      if (updates.isNotEmpty) {
        await firestore.collection('users').doc(userId).update(updates);
        debugPrint('✅ Badges + workoutsCount synced: $updates');
      } else {
        debugPrint('✅ Stats already in sync');
      }
    } catch (e) {
      debugPrint('❌ Error syncing badges: $e');
    }
  }

  /// Force recalculate all badges (call manually when needed)
  static Future<void> forceRecalculateBadges() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await syncBadgesFromRunHistory(currentUser.uid);
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