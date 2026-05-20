import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:majurun/core/services/daily_trivia_service.dart';
import 'package:majurun/modules/puzzle/data/puzzle_question_bank.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DailyTriviaScreen — 5-question daily running trivia quiz
// ─────────────────────────────────────────────────────────────────────────────

class DailyTriviaScreen extends StatefulWidget {
  const DailyTriviaScreen({super.key});

  @override
  State<DailyTriviaScreen> createState() => _DailyTriviaScreenState();
}

class _DailyTriviaScreenState extends State<DailyTriviaScreen>
    with SingleTickerProviderStateMixin {
  final _service = DailyTriviaService();

  List<PuzzleQuestion> _questions = const [];
  bool _loadError = false;
  int _currentIndex = 0;
  int? _selectedOption;
  bool _answered = false;
  int _score = 0;
  bool _finished = false;
  TriviaStats? _finalStats;

  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  static const _green = Color(0xFF00E676);
  static const _dark  = Color(0xFF1A1A2E);
  static const _correctBg = Color(0xFF1A2A1A);
  static const _wrongBg   = Color(0xFF2A1A1A);

  @override
  void initState() {
    super.initState();
    try {
      _questions = _service.getTodaysQuestions();
    } catch (e) {
      _loadError = true;
      debugPrint('⚠️ DailyTriviaScreen: failed to load questions: $e');
    }
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  void _onOptionTap(int index) {
    if (_answered) return;
    HapticFeedback.selectionClick();
    if (index == _questions[_currentIndex].correctIndex) {
      HapticFeedback.mediumImpact();
      _score++;
    }
    setState(() { _selectedOption = index; _answered = true; });
  }

  Future<void> _next() async {
    if (_currentIndex < _questions.length - 1) {
      await _slideCtrl.reverse();
      setState(() {
        _currentIndex++;
        _selectedOption = null;
        _answered = false;
      });
      _slideCtrl.forward();
    } else {
      final stats = await _service.completeToday(_score);
      setState(() { _finished = true; _finalStats = stats; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError || _questions.isEmpty) {
      return Scaffold(
        backgroundColor: _dark,
        appBar: AppBar(
          backgroundColor: _dark,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Text(
            'No trivia available today.\nCheck back tomorrow!',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: _dark,
      appBar: AppBar(
        backgroundColor: _dark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Daily Trivia',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: _finished ? _buildResults() : _buildQuestion(),
    );
  }

  // ── Question view ─────────────────────────────────────────────────────────
  Widget _buildQuestion() {
    final q = _questions[_currentIndex];
    final progress = (_currentIndex + 1) / _questions.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Question ${_currentIndex + 1} of ${_questions.length}',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  Text(
                    '$_score correct',
                    style: const TextStyle(
                        color: _green, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(_green),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.quiz_rounded, color: _green, size: 26),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    q.question,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  ...List.generate(q.options.length, (i) => _buildOption(i, q)),
                  if (_answered) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: Colors.white54, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              q.explanation,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: Text(
                          _currentIndex < _questions.length - 1
                              ? 'Next Question'
                              : 'See Results',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOption(int index, PuzzleQuestion q) {
    Color borderColor = Colors.white12;
    Color bgColor = Colors.white.withValues(alpha: 0.05);
    Color textColor = Colors.white;
    Widget? trailingIcon;

    if (_answered) {
      final isCorrect  = index == q.correctIndex;
      final isSelected = index == _selectedOption;
      if (isCorrect) {
        borderColor = _green;
        bgColor     = _correctBg;
        textColor   = _green;
        trailingIcon = const Icon(Icons.check_circle_rounded, color: _green, size: 20);
      } else if (isSelected) {
        borderColor = const Color(0xFFEF4444);
        bgColor     = _wrongBg;
        textColor   = const Color(0xFFEF4444);
        trailingIcon = const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 20);
      } else {
        textColor   = Colors.white38;
        borderColor = Colors.white.withValues(alpha: 0.05);
        bgColor     = Colors.transparent;
      }
    }

    final labels = ['A', 'B', 'C', 'D'];

    return GestureDetector(
      onTap: () => _onOptionTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _answered && index == q.correctIndex
                    ? _green.withValues(alpha: 0.2)
                    : Colors.white12,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  labels[index],
                  style: TextStyle(
                      color: textColor, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                q.options[index],
                style: TextStyle(
                    color: textColor, fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
            if (trailingIcon != null) ...[
              const SizedBox(width: 8),
              trailingIcon,
            ],
          ],
        ),
      ),
    );
  }

  // ── Results view ──────────────────────────────────────────────────────────
  Widget _buildResults() {
    final stats = _finalStats!;
    final pct = (_score / _questions.length * 100).round();
    final allCorrect = _score == _questions.length;
    final emoji = allCorrect ? '🏆' : _score >= 3 ? '🏅' : '💪';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 72)),
            const SizedBox(height: 20),
            Text(
              allCorrect ? 'Perfect Score!' : _score >= 3 ? 'Well done!' : 'Keep practising!',
              style: const TextStyle(
                  color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '$_score out of ${_questions.length} correct ($pct%)',
              style: const TextStyle(color: Colors.white60, fontSize: 16),
            ),
            const SizedBox(height: 36),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statBox('🔥', '${stats.currentStreak}', 'Day Streak'),
                _statBox('🏆', '${stats.longestStreak}', 'Best Streak'),
                _statBox('📅', '${stats.totalPlayed}', 'Total Played'),
              ],
            ),
            const SizedBox(height: 36),
            if (stats.currentStreak > 1)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department_rounded,
                        color: _green, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${stats.currentStreak}-day streak! Come back tomorrow to keep it going.',
                        style: const TextStyle(
                            color: _green, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text(
                  'Back to Feed',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Come back tomorrow for 5 new questions',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBox(String emoji, String value, String label) => Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      );
}
