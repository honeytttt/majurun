import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:majurun/modules/run/controllers/post_controller.dart';

/// Posts one motivational card + one education card to the global feed each day.
///
/// The first user to open the app on a given calendar day triggers the posts.
/// A `dailyContent/<YYYY-MM-DD>` Firestore document is used as a global mutex so
/// the content is posted exactly once, even with many concurrent users.
class DailyContentService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final PostController _post = PostController();

  /// Call once from HomeScreen.initState(). Safe to call repeatedly — it's a no-op
  /// after the first user triggers it for the day.
  static Future<void> maybePostDailyContent() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;

    final docRef = _db.collection('dailyContent').doc(today);

    try {
      // Atomically claim the slot(s) so only one user posts per type per day.
      await _db.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        final data = snap.data() ?? {};

        final updates = <String, dynamic>{};
        if (!(data['motivationalPosted'] as bool? ?? false)) {
          updates['motivationalPosted'] = true;
          updates['postedBy'] = user.uid;
          updates['date'] = FieldValue.serverTimestamp();
        }
        if (!(data['educationPosted'] as bool? ?? false)) {
          updates['educationPosted'] = true;
          updates['postedBy'] = user.uid;
          updates['date'] = FieldValue.serverTimestamp();
        }
        if (updates.isNotEmpty) {
          tx.set(docRef, updates, SetOptions(merge: true));
        }
      });

      // Re-read to know which slots we won (another device may have beaten us).
      final committed = await docRef.get();
      final data = committed.data() ?? {};
      final wonMotivational = (data['motivationalPosted'] as bool? ?? false) &&
          (data['postedBy'] as String?) == user.uid;
      final wonEducation = (data['educationPosted'] as bool? ?? false) &&
          (data['postedBy'] as String?) == user.uid;

      String username = 'MajuRun';
      try {
        final userDoc = await _db.collection('users').doc(user.uid).get();
        username = userDoc.data()?['displayName'] as String? ?? user.displayName ?? 'MajuRun';
      } catch (_) {}

      if (wonMotivational) {
        final imageUrl = PostController.motivationalImageForDay(dayOfYear);
        await _post.createMotivationalPost(
          imageUrl: imageUrl,
          userId: user.uid,
          username: username,
        );
        debugPrint('💪 Daily motivational post published for $today');
      }

      if (wonEducation) {
        final imageUrl = PostController.educationImageForDay(dayOfYear);
        await _post.createEducationPost(
          imageUrl: imageUrl,
          userId: user.uid,
          username: username,
        );
        debugPrint('📚 Daily education post published for $today');
      }
    } catch (e) {
      debugPrint('⚠️ DailyContentService: $e');
    }
  }
}
