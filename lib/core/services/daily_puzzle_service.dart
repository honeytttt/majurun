import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DailyPuzzleService — streak tracking for the daily "Run Path" game.
//
// Streak: stored in both SharedPreferences (offline / fast) and Firestore
// (cross-device persistence). Firestore is the source of truth.
//
// Firestore path: users/{uid}/puzzleStats/stats
// ─────────────────────────────────────────────────────────────────────────────

class PuzzleStats {
  final int currentStreak;
  final int longestStreak;
  final int totalPlayed;
  final String? lastPlayedDate; // 'YYYY-MM-DD' or null

  const PuzzleStats({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalPlayed = 0,
    this.lastPlayedDate,
  });

  bool get hasPlayedToday {
    if (lastPlayedDate == null) return false;
    return lastPlayedDate == DailyPuzzleService.todayKey;
  }

  factory PuzzleStats.fromMap(Map<String, dynamic> data) => PuzzleStats(
        currentStreak: (data['currentStreak'] as num?)?.toInt() ?? 0,
        longestStreak: (data['longestStreak'] as num?)?.toInt() ?? 0,
        totalPlayed: (data['totalPlayed'] as num?)?.toInt() ?? 0,
        lastPlayedDate: data['lastPlayedDate'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'totalPlayed': totalPlayed,
        'lastPlayedDate': lastPlayedDate,
      };
}

class DailyPuzzleService {
  static String get todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String get _yesterdayKey {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
  }

  // SharedPreferences keys
  static const String _prefStreak = 'puzzle_current_streak';
  static const String _prefLongest = 'puzzle_longest_streak';
  static const String _prefTotal = 'puzzle_total_played';
  static const String _prefLastDate = 'puzzle_last_played_date';

  /// Load stats from SharedPreferences (fast / offline).
  Future<PuzzleStats> loadStatsLocal() async {
    final prefs = await SharedPreferences.getInstance();
    return PuzzleStats(
      currentStreak: prefs.getInt(_prefStreak) ?? 0,
      longestStreak: prefs.getInt(_prefLongest) ?? 0,
      totalPlayed: prefs.getInt(_prefTotal) ?? 0,
      lastPlayedDate: prefs.getString(_prefLastDate),
    );
  }

  /// Load stats from Firestore (source of truth, requires network).
  Future<PuzzleStats> loadStatsRemote() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return const PuzzleStats();
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('puzzleStats')
          .doc('stats')
          .get();
      if (!doc.exists) return const PuzzleStats();
      return PuzzleStats.fromMap(doc.data()!);
    } catch (e) {
      debugPrint('⚠️ DailyPuzzleService: failed to load remote stats: $e');
      return const PuzzleStats();
    }
  }

  /// Call after the player completes today's puzzle.
  /// Returns the updated stats with the new streak.
  Future<PuzzleStats> completeToday(int score) async {
    final current = await loadStatsLocal();

    // Already played today — don't double-count
    if (current.hasPlayedToday) return current;

    final wasYesterday = current.lastPlayedDate == _yesterdayKey;
    final newStreak = wasYesterday ? current.currentStreak + 1 : 1;
    final newLongest =
        newStreak > current.longestStreak ? newStreak : current.longestStreak;
    final newTotal = current.totalPlayed + 1;

    final updated = PuzzleStats(
      currentStreak: newStreak,
      longestStreak: newLongest,
      totalPlayed: newTotal,
      lastPlayedDate: todayKey,
    );

    // Persist locally (immediate)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefStreak, newStreak);
    await prefs.setInt(_prefLongest, newLongest);
    await prefs.setInt(_prefTotal, newTotal);
    await prefs.setString(_prefLastDate, todayKey);

    // Persist to Firestore (fire-and-forget)
    _saveRemote(updated);

    debugPrint('🧩 Puzzle solved. Streak: $newStreak');
    return updated;
  }

  void _saveRemote(PuzzleStats stats) {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('puzzleStats')
          .doc('stats')
          .set(stats.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ DailyPuzzleService: failed to save remote stats: $e');
    }
  }
}
