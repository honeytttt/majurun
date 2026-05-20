import 'package:flutter/material.dart';
import 'package:majurun/core/services/daily_trivia_service.dart';
import 'package:majurun/modules/puzzle/presentation/screens/daily_trivia_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DailyTriviaCard — feed card for the daily running trivia quiz.
// ─────────────────────────────────────────────────────────────────────────────

class DailyTriviaCard extends StatefulWidget {
  const DailyTriviaCard({super.key});

  @override
  State<DailyTriviaCard> createState() => _DailyTriviaCardState();
}

class _DailyTriviaCardState extends State<DailyTriviaCard> {
  final _service = DailyTriviaService();
  TriviaStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stats = await _service.loadStatsLocal();
    if (mounted) setState(() { _stats = stats; _loading = false; });
  }

  Future<void> _open() async {
    if (_stats?.hasPlayedToday ?? false) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DailyTriviaScreen()),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    final stats  = _stats ?? const TriviaStats();
    final played = stats.hasPlayedToday;
    final streak = stats.currentStreak;

    return GestureDetector(
      onTap: played ? null : _open,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: played
                ? [const Color(0xFF1A2A1A), const Color(0xFF0D1A10)]
                : [const Color(0xFF1E1A2E), const Color(0xFF130F1F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: played
                ? const Color(0xFF00E676).withValues(alpha: 0.4)
                : const Color(0xFF3D2D54),
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: played
                    ? const Color(0xFF00E676).withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                played ? Icons.check_circle_outline_rounded : Icons.quiz_rounded,
                color: played ? const Color(0xFF00E676) : Colors.white70,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    played ? "Today's trivia done! ✓" : 'Daily Running Trivia',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    played
                        ? streak > 1
                            ? '🔥 $streak-day streak — come back tomorrow!'
                            : 'See you tomorrow for new questions!'
                        : streak > 0
                            ? '🔥 $streak-day streak — keep it going!'
                            : '5 running questions · Test your knowledge',
                    style: TextStyle(
                      color: played
                          ? const Color(0xFF00E676).withValues(alpha: 0.8)
                          : Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (!played)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF9C6FDE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Play',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                ),
              )
            else
              const Icon(Icons.star_rounded, color: Color(0xFF00E676), size: 22),
          ],
        ),
      ),
    );
  }
}
