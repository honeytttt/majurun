import 'package:flutter/material.dart';
import 'package:majurun/core/services/daily_puzzle_service.dart';
import 'package:majurun/modules/puzzle/data/route_puzzle_bank.dart';
import 'package:majurun/modules/puzzle/presentation/screens/daily_route_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DailyPuzzleCard — feed card for the "Run Path" daily number-connection game.
// Shows the user's streak and whether today's puzzle has been completed.
// ─────────────────────────────────────────────────────────────────────────────

class DailyPuzzleCard extends StatefulWidget {
  const DailyPuzzleCard({super.key});

  @override
  State<DailyPuzzleCard> createState() => _DailyPuzzleCardState();
}

class _DailyPuzzleCardState extends State<DailyPuzzleCard> {
  final _service = DailyPuzzleService();
  PuzzleStats? _stats;
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
      MaterialPageRoute(builder: (_) => const DailyRouteScreen()),
    );
    _load(); // refresh streak after returning
  }

  RoutePuzzle get _todaysPuzzle {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year)).inDays;
    return kRoutePuzzles[dayOfYear % kRoutePuzzles.length];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    final stats = _stats ?? const PuzzleStats();
    final played = stats.hasPlayedToday;
    final streak = stats.currentStreak;
    final puzzle = _todaysPuzzle;

    return GestureDetector(
      onTap: played ? null : _open,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: played
                ? [const Color(0xFF1A2A1A), const Color(0xFF0D1A10)]
                : [const Color(0xFF1A1A2E), const Color(0xFF0F0F1F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: played
                ? const Color(0xFF00E676).withValues(alpha: 0.4)
                : const Color(0xFF2D2D44),
          ),
        ),
        child: Row(
          children: [
            // Mini grid preview (3×3 dots)
            _MiniGrid(played: played),
            const SizedBox(width: 14),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    played ? 'Route Complete! ✓' : 'Run Path',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    played
                        ? streak > 1
                            ? '🔥 $streak-day streak — back tomorrow!'
                            : 'See you tomorrow for a new puzzle!'
                        : streak > 0
                            ? '🔥 $streak-day streak · ${puzzle.difficulty} · Connect all checkpoints'
                            : '${puzzle.difficulty} · Connect checkpoints in order',
                    style: TextStyle(
                      color: played
                          ? const Color(0xFF00E676).withValues(alpha: 0.85)
                          : Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),
            if (!played)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Play',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              )
            else
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF00E676), size: 24),
          ],
        ),
      ),
    );
  }
}

/// Small decorative 3×3 grid icon that hints at the game mechanic.
class _MiniGrid extends StatelessWidget {
  final bool played;
  const _MiniGrid({required this.played});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF00E676);
    const size = 44.0;
    const cellCount = 3;
    const cellPx = (size - 4) / cellCount;

    // Simple path: top-left → top-right → mid-right → mid-left → bottom-left → bottom-right
    const pathCells = [(0, 0), (0, 1), (0, 2), (1, 2), (1, 0), (2, 0), (2, 2)];
    final pathSet = pathCells.toSet();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: played ? green.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: played ? green.withValues(alpha: 0.3) : Colors.white12,
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: CustomPaint(
        painter: _MiniGridPainter(
          pathSet: pathSet,
          cellPx: cellPx,
          played: played,
        ),
      ),
    );
  }
}

class _MiniGridPainter extends CustomPainter {
  final Set<(int, int)> pathSet;
  final double cellPx;
  final bool played;

  const _MiniGridPainter({
    required this.pathSet,
    required this.cellPx,
    required this.played,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const green = Color(0xFF00E676);
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(c * cellPx + 1, r * cellPx + 1, cellPx - 2, cellPx - 2),
          const Radius.circular(2),
        );
        final inPath = pathSet.contains((r, c));
        canvas.drawRRect(
          rect,
          Paint()
            ..color = inPath
                ? green.withValues(alpha: played ? 0.5 : 0.25)
                : Colors.white.withValues(alpha: 0.04),
        );
      }
    }
    // Draw number dots for nodes 1 and last
    for (final (nr, nc) in [(0, 0), (2, 2)]) {
      canvas.drawCircle(
        Offset(nc * cellPx + cellPx / 2, nr * cellPx + cellPx / 2),
        cellPx * 0.3,
        Paint()..color = green.withValues(alpha: played ? 0.9 : 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniGridPainter old) => old.played != played;
}
