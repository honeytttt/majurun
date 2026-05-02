import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages daily game rotation and play tracking.
///
/// Games rotate on a 3-day cycle:
///   day % 3 == 0 → Route Riddle
///   day % 3 == 1 → Pace Pulse
///   day % 3 == 2 → Gear Matcher
///
/// Fully isolated — no imports from core run/feed modules.
class GamesService {
  GamesService._();

  static const _prefKeyPlayed = 'games_played_date';
  static const _collectionPlays = 'engagement_game_plays';

  static GameType get todaysGame {
    final day = DateTime.now().difference(DateTime(2024)).inDays;
    switch (day % 3) {
      case 0:
        return GameType.routeRiddle;
      case 1:
        return GameType.pacePulse;
      default:
        return GameType.gearMatcher;
    }
  }

  /// Returns true if the user has already played today's game.
  static Future<bool> hasPlayedToday() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefKeyPlayed) ?? '';
    return stored == _todayKey;
  }

  /// Marks today's game as played (locally + Firestore play counter).
  static Future<void> markPlayed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyPlayed, _todayKey);

    // Write play to Firestore for the "X friends played" counter.
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final docId = '${_todayKey}_${todaysGame.name}';
      await FirebaseFirestore.instance
          .collection(_collectionPlays)
          .doc(docId)
          .set({
        'date': _todayKey,
        'gameType': todaysGame.name,
        'players': FieldValue.arrayUnion([uid]),
        'count': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (_) {
      // Non-critical — local play state already saved.
    }
  }

  /// Returns how many users have played today's game.
  static Future<int> todaysPlayCount() async {
    try {
      final docId = '${_todayKey}_${todaysGame.name}';
      final doc = await FirebaseFirestore.instance
          .collection(_collectionPlays)
          .doc(docId)
          .get();
      if (!doc.exists) return 0;
      return (doc.data()?['count'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static String get _todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

enum GameType { routeRiddle, pacePulse, gearMatcher }
