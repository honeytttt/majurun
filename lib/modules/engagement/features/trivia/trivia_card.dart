import 'package:flutter/material.dart';
import 'trivia_questions.dart';
import 'trivia_service.dart';

/// Engagement Feature 2 — Daily Trivia Card.
///
/// Self-contained stateful widget showing today's running trivia question.
/// All state is stored in SharedPreferences — no Firebase, no server.
/// [onDismiss] is called when the user taps ✕ to hide the card for today.
class TriviaCard extends StatefulWidget {
  final VoidCallback? onDismiss;
  const TriviaCard({super.key, this.onDismiss});

  @override
  State<TriviaCard> createState() => _TriviaCardState();
}

class _TriviaCardState extends State<TriviaCard>
    with SingleTickerProviderStateMixin {
  late final TriviaQuestion _q;
  int _selectedIndex = -1; // -1 = not answered yet
  bool _loading = true;
  late final AnimationController _revealCtrl;
  late final Animation<double> _revealAnim;

  static const _green = Color(0xFF00E676);
  static const _correctColor = Color(0xFF00C853);
  static const _wrongColor = Color(0xFFE53935);

  @override
  void initState() {
    super.initState();
    _q = TriviaService.todayQuestion();
    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _revealAnim =
        CurvedAnimation(parent: _revealCtrl, curve: Curves.easeOut);
    _loadState();
  }

  @override
  void dispose() {
    _revealCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final answered = await TriviaService.hasAnsweredToday();
    if (!mounted) return;
    if (answered) {
      final sel = await TriviaService.selectedAnswerToday();
      setState(() {
        _selectedIndex = sel;
        _loading = false;
      });
      _revealCtrl.value = 1.0;
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _onOptionTap(int index) async {
    if (_selectedIndex >= 0) return;
    await TriviaService.recordAnswer(index);
    if (!mounted) return;
    setState(() => _selectedIndex = index);
    _revealCtrl.forward();
  }

  Future<void> _handleDismiss() async {
    await TriviaService.dismissToday();
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              _q.question,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildOptions(),
          if (_selectedIndex >= 0)
            FadeTransition(
              opacity: _revealAnim,
              child: _buildExplanation(),
            ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _green.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_q.categoryEmoji, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 5),
                Text(
                  _q.category.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF00B96B),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Daily Quiz',
            style: TextStyle(fontSize: 12, color: Colors.black38),
          ),
          const Spacer(),
          // Only show dismiss when not yet answered
          if (_selectedIndex < 0)
            GestureDetector(
              onTap: _handleDismiss,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.close_rounded, size: 18, color: Colors.black38),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOptions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: List.generate(_q.options.length, (i) {
          final isSelected = _selectedIndex == i;
          final answered = _selectedIndex >= 0;
          final isCorrect = i == _q.correctIndex;

          Color bg = Colors.white;
          Color borderColor = const Color(0xFFE8E8E8);
          Color textColor = Colors.black87;
          Widget? trailing;

          if (answered) {
            if (isCorrect) {
              bg = _correctColor.withValues(alpha: 0.08);
              borderColor = _correctColor;
              textColor = _correctColor;
              trailing = const Icon(Icons.check_circle_rounded,
                  size: 18, color: _correctColor);
            } else if (isSelected) {
              bg = _wrongColor.withValues(alpha: 0.08);
              borderColor = _wrongColor;
              textColor = _wrongColor;
              trailing =
                  const Icon(Icons.cancel_rounded, size: 18, color: _wrongColor);
            }
          }

          return GestureDetector(
            onTap: answered ? null : () => _onOptionTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (isSelected || (answered && isCorrect))
                      ? borderColor
                      : const Color(0xFFE8E8E8),
                  width: (isSelected || (answered && isCorrect)) ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _q.options[i],
                      style: TextStyle(
                        fontSize: 14,
                        color: textColor,
                        fontWeight: answered && (isCorrect || isSelected)
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing,
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildExplanation() {
    final correct = _selectedIndex == _q.correctIndex;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: correct
            ? _correctColor.withValues(alpha: 0.06)
            : _wrongColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                correct
                    ? Icons.emoji_events_rounded
                    : Icons.lightbulb_outline_rounded,
                size: 16,
                color: correct ? _correctColor : _wrongColor,
              ),
              const SizedBox(width: 6),
              Text(
                correct ? 'Correct! 🎉' : "Not quite — here's why:",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: correct ? _correctColor : _wrongColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _q.explanation,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined, size: 12, color: Colors.black38),
          const SizedBox(width: 4),
          Text(
            _selectedIndex >= 0
                ? 'Come back tomorrow for a new question!'
                : 'New question every day',
            style: const TextStyle(fontSize: 11, color: Colors.black38),
          ),
        ],
      ),
    );
  }
}
