import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Subscription tiers
enum SubscriptionTier {
  free,
  pro,
}

/// Subscription service to manage pro features
class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Legacy admin email — transitional fallback only.
  // Authoritative admin source: Firebase Custom Claim `admin: true`.
  // To grant admin: firebase.auth().setCustomUserClaims(uid, { admin: true })
  // TODO: remove email fallback once all admin accounts have the custom claim.
  static const String adminEmail = 'majurun.app@gmail.com';

  /// Synchronous admin check (email only — use [isAdminAsync] where possible).
  bool isAdmin() {
    return _auth.currentUser?.email == adminEmail;
  }

  /// Async admin check — prefers Custom Claim, falls back to email.
  /// Use this wherever an async call is acceptable (profile load, purchase flow).
  Future<bool> isAdminAsync() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      final token = await user.getIdTokenResult();
      if (token.claims?['admin'] == true) return true;
    } catch (e) {
      debugPrint('Admin claim check error: $e');
    }
    return user.email == adminEmail; // fallback
  }

  /// Check if a given user ID is admin (async, checks Custom Claim first).
  Future<bool> isUserAdmin(String userId) async {
    try {
      // Prefer Custom Claim on the current user if IDs match
      if (_auth.currentUser?.uid == userId) {
        return isAdminAsync();
      }
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        // Custom claim is not readable from Firestore, fall back to email field
        final email = doc.data()?['email'] as String?;
        return email == adminEmail;
      }
    } catch (e) {
      debugPrint('Error checking admin status: $e');
    }
    return false;
  }

  /// Get current user's subscription tier
  Future<SubscriptionTier> getCurrentUserTier() async {
    // Admin always has pro access
    if (isAdmin()) return SubscriptionTier.pro;

    final userId = _auth.currentUser?.uid;
    if (userId == null) return SubscriptionTier.free;

    return getUserTier(userId);
  }

  /// Get user's subscription tier by ID
  Future<SubscriptionTier> getUserTier(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;

        // Check if admin
        final email = data['email'] as String?;
        if (email == adminEmail) return SubscriptionTier.pro;

        // Check subscription status
        final isPro = data['isPro'] as bool? ?? false;
        final subscriptionExpiry = data['subscriptionExpiry'] as Timestamp?;

        if (isPro) {
          // Check if subscription is still valid
          if (subscriptionExpiry != null) {
            if (subscriptionExpiry.toDate().isAfter(DateTime.now())) {
              return SubscriptionTier.pro;
            }
          } else {
            // Lifetime pro
            return SubscriptionTier.pro;
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting user tier: $e');
    }
    return SubscriptionTier.free;
  }

  /// Check if current user is pro
  Future<bool> isProUser() async {
    final tier = await getCurrentUserTier();
    return tier == SubscriptionTier.pro;
  }

  /// Stream user's pro status
  Stream<bool> streamProStatus() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value(false);

    // Admin always pro
    if (isAdmin()) return Stream.value(true);

    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return false;
      final data = doc.data()!;

      final email = data['email'] as String?;
      if (email == adminEmail) return true;

      final isPro = data['isPro'] as bool? ?? false;
      if (!isPro) return false;

      final subscriptionExpiry = data['subscriptionExpiry'] as Timestamp?;
      if (subscriptionExpiry == null) return true; // Lifetime

      return subscriptionExpiry.toDate().isAfter(DateTime.now());
    });
  }

  /// DEBUG / ADMIN ONLY — writes isPro directly to Firestore.
  /// NEVER call this in production code or from any purchase flow.
  /// The only trusted writer of isPro in production is the verifySubscription
  /// Cloud Function.  Any client-side write can be replayed by any user.
  Future<void> upgradeToProMonth(String userId) async {
    assert(
      kDebugMode,
      'upgradeToProMonth must not be called in release builds — '
      'use the verifySubscription Cloud Function instead.',
    );
    final expiry = DateTime.now().add(const Duration(days: 30));
    await _firestore.collection('users').doc(userId).update({
      'isPro': true,
      'subscriptionExpiry': Timestamp.fromDate(expiry),
      'subscriptionType': 'monthly',
      'subscribedAt': FieldValue.serverTimestamp(),
    });
    debugPrint('User $userId upgraded to Pro (Monthly) [DEBUG ONLY]');
  }

  /// DEBUG / ADMIN ONLY — see [upgradeToProMonth] warning.
  Future<void> upgradeToProYear(String userId) async {
    assert(
      kDebugMode,
      'upgradeToProYear must not be called in release builds — '
      'use the verifySubscription Cloud Function instead.',
    );
    final expiry = DateTime.now().add(const Duration(days: 365));
    await _firestore.collection('users').doc(userId).update({
      'isPro': true,
      'subscriptionExpiry': Timestamp.fromDate(expiry),
      'subscriptionType': 'yearly',
      'subscribedAt': FieldValue.serverTimestamp(),
    });
    debugPrint('User $userId upgraded to Pro (Yearly) [DEBUG ONLY]');
  }

  /// Downgrade user to free
  Future<void> downgradeToFree(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'isPro': false,
      'subscriptionExpiry': null,
      'subscriptionType': null,
    });
    debugPrint('User $userId downgraded to Free');
  }

  /// Get subscription info for UI display
  Future<Map<String, dynamic>> getSubscriptionInfo() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return {'tier': 'free', 'expiresAt': null};
    }

    if (isAdmin()) {
      return {'tier': 'admin', 'expiresAt': null, 'isLifetime': true};
    }

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        final isPro = data['isPro'] as bool? ?? false;
        final expiry = data['subscriptionExpiry'] as Timestamp?;
        final type = data['subscriptionType'] as String?;

        return {
          'tier': isPro ? 'pro' : 'free',
          'expiresAt': expiry?.toDate(),
          'subscriptionType': type,
          'isLifetime': isPro && expiry == null,
        };
      }
    } catch (e) {
      debugPrint('Error getting subscription info: $e');
    }

    return {'tier': 'free', 'expiresAt': null};
  }

  // ==================== PRO FEATURE CHECKS ====================

  /// Training programs that require pro
  static const List<String> proTrainingPrograms = [
    '5K to 10K',
    '10K to Half Marathon',
    'Half to Full Marathon',
  ];

  /// Check if training program requires pro
  bool isProTrainingProgram(String programName) {
    return proTrainingPrograms.contains(programName);
  }

  /// Workout categories that require pro (all except "All")
  static const List<String> proWorkoutCategories = [
    'Strength',
    'Yoga',
    'HIIT',
    'Meditation',
    'Outdoors',
  ];

  /// Check if workout category requires pro
  bool isProWorkoutCategory(String category) {
    return proWorkoutCategories.contains(category);
  }
}
