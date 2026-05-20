import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:majurun/modules/puzzle/data/puzzle_question_bank.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DailyTriviaService — streak tracking + question selection for the daily
// running-trivia quiz (5 questions per day).
//
// Separate from DailyPuzzleService (Run Path game) so each game has its own
// independent streak.
//
// Firestore path: users/{uid}/triviaStats/stats
// ─────────────────────────────────────────────────────────────────────────────

class TriviaStats {
  final int currentStreak;
  final int longestStreak;
  final int totalPlayed;
  final String? lastPlayedDate; // 'YYYY-MM-DD' or null

  const TriviaStats({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalPlayed = 0,
    this.lastPlayedDate,
  });

  bool get hasPlayedToday {
    if (lastPlayedDate == null) return false;
    return lastPlayedDate == DailyTriviaService.todayKey;
  }

  factory TriviaStats.fromMap(Map<String, dynamic> data) => TriviaStats(
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

class DailyTriviaService {
  static const int questionsPerDay = 5;

  static String get todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String get _yesterdayKey {
    final d = DateTime.now().subtract(const Duration(days: 1));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  // SharedPreferences keys (different prefix from puzzle_ to keep them separate)
  static const _prefStreak  = 'trivia_current_streak';
  static const _prefLongest = 'trivia_longest_streak';
  static const _prefTotal   = 'trivia_total_played';
  static const _prefLastDate = 'trivia_last_played_date';

  /// Returns today's 5 questions deterministically by day-of-year.
  List<PuzzleQuestion> getTodaysQuestions() {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year)).inDays;
    final pool = kPuzzleQuestions.length;
    final start = (dayOfYear * questionsPerDay) % pool;
    return List.generate(
      questionsPerDay,
      (i) => kPuzzleQuestions[(start + i) % pool],
    );
  }

  Future<TriviaStats> loadStatsLocal() async {
    final prefs = await SharedPreferences.getInstance();
    return TriviaStats(
      currentStreak: prefs.getInt(_prefStreak) ?? 0,
      longestStreak: prefs.getInt(_prefLongest) ?? 0,
      totalPlayed:   prefs.getInt(_prefTotal) ?? 0,
      lastPlayedDate: prefs.getString(_prefLastDate),
    );
  }

  Future<TriviaStats> loadStatsRemote() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return const TriviaStats();
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('triviaStats')
          .doc('stats')
          .get();
      if (!doc.exists) return const TriviaStats();
      return TriviaStats.fromMap(doc.data()!);
    } catch (e) {
      debugPrint('⚠️ DailyTriviaService: failed to load remote stats: $e');
      return const TriviaStats();
    }
  }

  /// Call after the user finishes today's quiz.
  /// [score] = number of correct answers out of [questionsPerDay].
  Future<TriviaStats> completeToday(int score) async {
    final current = await loadStatsLocal();
    if (current.hasPlayedToday) return current;

    final wasYesterday = current.lastPlayedDate == _yesterdayKey;
    final newStreak  = wasYesterday ? current.currentStreak + 1 : 1;
    final newLongest = newStreak > current.longestStreak ? newStreak : current.longestStreak;
    final newTotal   = current.totalPlayed + 1;

    final updated = TriviaStats(
      currentStreak: newStreak,
      longestStreak: newLongest,
      totalPlayed:   newTotal,
      lastPlayedDate: todayKey,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefStreak, newStreak);
    await prefs.setInt(_prefLongest, newLongest);
    await prefs.setInt(_prefTotal, newTotal);
    await prefs.setString(_prefLastDate, todayKey);

    _saveRemote(updated);
    debugPrint('🧠 Trivia completed. Streak: $newStreak  Score: $score/$questionsPerDay');
    return updated;
  }

  void _saveRemote(TriviaStats stats) {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('triviaStats')
          .doc('stats')
          .set(stats.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ DailyTriviaService: failed to save remote stats: $e');
    }
  }
}
