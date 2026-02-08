import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Comprehensive debugging and fixing utility
/// Add buttons to your settings screen to run these
class MajurunDebugger {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 1. CHECK CURRENT USER DOCUMENT
  static Future<void> checkMyUserDocument() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('❌ No user logged in');
      return;
    }

    try {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔍 CHECKING USER DOCUMENT');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('User ID: $uid');
      
      final userDoc = await _firestore.collection('users').doc(uid).get();
      
      if (!userDoc.exists) {
        debugPrint('❌ USER DOCUMENT DOES NOT EXIST!');
        debugPrint('   Run fixMyUserDocument() to create it');
        return;
      }
      
      final data = userDoc.data()!;
      debugPrint('✅ User document exists');
      debugPrint('');
      debugPrint('📄 ALL FIELDS:');
      data.forEach((key, value) {
        debugPrint('   $key: $value');
      });
      
      debugPrint('');
      debugPrint('🎯 CRITICAL FIELDS:');
      debugPrint('   followersCount: ${data['followersCount']} ${data['followersCount'] == null ? "❌ MISSING" : "✅"}');
      debugPrint('   followingCount: ${data['followingCount']} ${data['followingCount'] == null ? "❌ MISSING" : "✅"}');
      debugPrint('   displayName: ${data['displayName']} ${data['displayName'] == null ? "❌ MISSING" : "✅"}');
      
      // Check subcollections
      final followersSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('followers')
          .get();
      
      final followingSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('following')
          .get();
      
      debugPrint('');
      debugPrint('📊 SUBCOLLECTIONS:');
      debugPrint('   Followers: ${followersSnapshot.docs.length} documents');
      debugPrint('   Following: ${followingSnapshot.docs.length} documents');
      
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
    } catch (e) {
      debugPrint('❌ Error: $e');
    }
  }

  /// 2. FIX USER DOCUMENT
  static Future<void> fixMyUserDocument() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint('❌ No user logged in');
      return;
    }

    try {
      final uid = currentUser.uid;
      debugPrint('🔧 FIXING USER DOCUMENT for $uid');
      
      final userDoc = await _firestore.collection('users').doc(uid).get();
      
      if (!userDoc.exists) {
        // Create new document
        await _firestore.collection('users').doc(uid).set({
          'displayName': currentUser.displayName ?? currentUser.email?.split('@')[0] ?? 'Runner',
          'email': currentUser.email ?? '',
          'photoUrl': currentUser.photoURL ?? '',
          'bio': '',
          'followersCount': 0,
          'followingCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ Created new user document');
      } else {
        // Update existing document
        final followersSnapshot = await _firestore
            .collection('users')
            .doc(uid)
            .collection('followers')
            .get();
        
        final followingSnapshot = await _firestore
            .collection('users')
            .doc(uid)
            .collection('following')
            .get();
        
        await _firestore.collection('users').doc(uid).update({
          'followersCount': followersSnapshot.docs.length,
          'followingCount': followingSnapshot.docs.length,
          'displayName': currentUser.displayName ?? currentUser.email?.split('@')[0] ?? 'Runner',
        });
        debugPrint('✅ Updated user document with counters');
      }
      
      debugPrint('✅ DONE! Restart app to see changes.');
      
    } catch (e) {
      debugPrint('❌ Error: $e');
    }
  }

  /// 3. CHECK POST OWNERSHIP
  static Future<void> checkMyPosts() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('❌ No user logged in');
      return;
    }

    try {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📝 CHECKING MY POSTS');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('My UID: $uid');
      
      final postsSnapshot = await _firestore
          .collection('posts')
          .where('userId', isEqualTo: uid)
          .limit(5)
          .get();
      
      debugPrint('Found ${postsSnapshot.docs.length} of my posts');
      
      for (var doc in postsSnapshot.docs) {
        final data = doc.data();
        final postUserId = data['userId'];
        final isOwner = postUserId == uid;
        
        debugPrint('');
        debugPrint('Post ID: ${doc.id}');
        debugPrint('  userId in post: $postUserId');
        debugPrint('  My userId: $uid');
        debugPrint('  isOwner: $isOwner ${isOwner ? "✅" : "❌"}');
        debugPrint('  content: ${data['content']?.toString().substring(0, 30) ?? ""}...');
      }
      
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
    } catch (e) {
      debugPrint('❌ Error: $e');
    }
  }

  /// 4. CHECK FIRESTORE PERMISSIONS
  static Future<void> testFirestorePermissions() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('❌ No user logged in');
      return;
    }

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🔐 TESTING FIRESTORE PERMISSIONS');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // Test 1: Read user document
    try {
      await _firestore.collection('users').doc(uid).get();
      debugPrint('✅ Can read my user document');
    } catch (e) {
      debugPrint('❌ Cannot read my user document: $e');
    }

    // Test 2: Write to user document
    try {
      await _firestore.collection('users').doc(uid).update({
        'testField': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Can write to my user document');
    } catch (e) {
      debugPrint('❌ Cannot write to my user document: $e');
    }

    // Test 3: Create follower
    try {
      const testUserId = 'test_user_123';
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('following')
          .doc(testUserId)
          .set({
        'userId': testUserId,
        'followedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Can create following document');
      
      // Clean up
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('following')
          .doc(testUserId)
          .delete();
    } catch (e) {
      debugPrint('❌ Cannot create following document: $e');
      debugPrint('   This is the follow button error!');
    }

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  /// 5. FULL DIAGNOSTIC
  static Future<void> runFullDiagnostic() async {
    debugPrint('');
    debugPrint('═══════════════════════════════════════════');
    debugPrint('🔍 RUNNING FULL DIAGNOSTIC');
    debugPrint('═══════════════════════════════════════════');
    debugPrint('');
    
    await checkMyUserDocument();
    debugPrint('');
    await checkMyPosts();
    debugPrint('');
    await testFirestorePermissions();
    debugPrint('');
    
    debugPrint('═══════════════════════════════════════════');
    debugPrint('✅ DIAGNOSTIC COMPLETE - Check logs above');
    debugPrint('═══════════════════════════════════════════');
  }
}