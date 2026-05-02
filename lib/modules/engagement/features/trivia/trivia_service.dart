import 'package:shared_preferences/shared_preferences.dart';
import 'trivia_questions.dart';

/// Manages daily trivia state — which question to show and whether the user
/// has already answered or dismissed it today.
class TriviaService {
  TriviaService._();

  static const String _answeredPrefix = 'eng_trivia_answered_';
  static const String _selectedPrefix = 'eng_trivia_selected_';
  static const String _dismissedPrefix = 'eng_trivia_dismissed_';

  // ── Question selection ───────────────────────────────────────────────────

  /// Returns today's question (rotates through all 30 by day-of-year).
  static TriviaQuestion todayQuestion() {
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
    return kTriviaQuestions[dayOfYear % kTriviaQuestions.length];
  }

  // ── State reads ──────────────────────────────────────────────────────────

  static Future<bool> hasAnsweredToday() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_answeredPrefix${_todayKey()}') ?? false;
  }

  static Future<bool> hasDismissedToday() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_dismissedPrefix${_todayKey()}') ?? false;
  }

  /// Returns the selected option index, or -1 if not yet answered.
  static Future<int> selectedAnswerToday() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_selectedPrefix${_todayKey()}') ?? -1;
  }

  // ── State writes ─────────────────────────────────────────────────────────

  static Future<void> recordAnswer(int selectedIndex) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _todayKey();
    await prefs.setBool('$_answeredPrefix$key', true);
    await prefs.setInt('$_selectedPrefix$key', selectedIndex);
  }

  static Future<void> dismissToday() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_dismissedPrefix${_todayKey()}', true);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}
