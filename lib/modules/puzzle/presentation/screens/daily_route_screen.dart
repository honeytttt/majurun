import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:majurun/core/services/daily_puzzle_service.dart';
import 'package:majurun/modules/puzzle/data/route_puzzle_bank.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DailyRouteScreen — "Run Path" number-connection game
//
// Rules:
//   • 5×5 grid of cells.
//   • Numbered checkpoints must be connected in order (1 → 2 → 3 …).
//   • The drawn path must visit EVERY cell exactly once.
//   • The path must END at the last checkpoint.
//   • Drag your finger to draw the path; drag back to erase.
// ─────────────────────────────────────────────────────────────────────────────

class GridCell {
  final int row, col;
  const GridCell(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      other is GridCell && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);
}

class DailyRouteScreen extends StatefulWidget {
  const DailyRouteScreen({super.key});

  @override
  State<DailyRouteScreen> createState() => _DailyRouteScreenState();
}

class _DailyRouteScreenState extends State<DailyRouteScreen>
    with SingleTickerProviderStateMixin {
  static const _green = Color(0xFF00E676);
  static const _dark = Color(0xFF0F0F1F);

  late final RoutePuzzle _puzzle;
  final List<GridCell> _path = [];
  bool _solved = false;
  bool _drawing = false;
  PuzzleStats? _finalStats;

  late AnimationController _winCtrl;
  late Animation<double> _winScale;

  @override
  void initState() {
    super.initState();
    _puzzle = _pickTodaysPuzzle();
    _winCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _winScale = CurvedAnimation(parent: _winCtrl, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _winCtrl.dispose();
    super.dispose();
  }

  RoutePuzzle _pickTodaysPuzzle() {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year)).inDays;
    return kRoutePuzzles[dayOfYear % kRoutePuzzles.length];
  }

  // ── Path helpers ──────────────────────────────────────────────────────────

  GridCell? _cellAt(Offset local, double cellSize) {
    final col = (local.dx / cellSize).floor();
    final row = (local.dy / cellSize).floor();
    if (row < 0 || row >= _puzzle.gridSize || col < 0 || col >= _puzzle.gridSize) {
      return null;
    }
    return GridCell(row, col);
  }

  bool _isAdjacent(GridCell a, GridCell b) =>
      (a.row - b.row).abs() + (a.col - b.col).abs() == 1;

  int _checkpointIndex(GridCell cell) =>
      _puzzle.nodes.indexWhere((n) => n.row == cell.row && n.col == cell.col);

  /// Returns the 0-based index of the next checkpoint the path must visit.
  int _nextCheckpointIndex() {
    int last = -1;
    for (final cell in _path) {
      final ci = _checkpointIndex(cell);
      if (ci > last) last = ci;
    }
    return last + 1;
  }

  // ── Gesture handlers ─────────────────────────────────────────────────────

  void _onPanStart(Offset pos, double cellSize) {
    if (_solved) return;
    final cell = _cellAt(pos, cellSize);
    if (cell == null) return;

    final firstNode = _puzzle.nodes.first;
    final startCell = GridCell(firstNode.row, firstNode.col);

    if (_path.isEmpty) {
      // Must start at checkpoint 1
      if (cell == startCell) {
        setState(() {
          _path.add(cell);
          _drawing = true;
        });
      }
    } else {
      // Touch anywhere in existing path → trim back to that point
      final idx = _path.indexOf(cell);
      if (idx >= 0) {
        setState(() {
          _path.removeRange(idx + 1, _path.length);
          _drawing = true;
        });
      } else if (cell == _path.last) {
        setState(() => _drawing = true);
      }
    }
  }

  void _onPanUpdate(Offset pos, double cellSize) {
    if (!_drawing || _solved || _path.isEmpty) return;
    final cell = _cellAt(pos, cellSize);
    if (cell == null) return;

    // Same as current end — nothing to do
    if (cell == _path.last) return;

    // Dragging back into the path — trim
    final existingIdx = _path.indexOf(cell);
    if (existingIdx >= 0) {
      setState(() => _path.removeRange(existingIdx + 1, _path.length));
      return;
    }

    // Must be orthogonally adjacent to the end of the path
    if (!_isAdjacent(_path.last, cell)) return;

    // If this cell is a checkpoint, it must be exactly the next expected one
    final cpIdx = _checkpointIndex(cell);
    if (cpIdx >= 0 && cpIdx != _nextCheckpointIndex()) return;

    setState(() => _path.add(cell));
    _checkWin();
  }

  void _onPanEnd() {
    setState(() => _drawing = false);
  }

  void _checkWin() {
    if (_path.length != _puzzle.gridSize * _puzzle.gridSize) return;
    final lastNode = _puzzle.nodes.last;
    if (_path.last != GridCell(lastNode.row, lastNode.col)) return;
    // All cells filled and ended at last checkpoint
    _onSolved();
  }

  Future<void> _onSolved() async {
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.heavyImpact();
    setState(() => _solved = true);
    _winCtrl.forward();
    final stats = await DailyPuzzleService().completeToday(1);
    if (mounted) setState(() => _finalStats = stats);
  }

  void _reset() {
    HapticFeedback.selectionClick();
    setState(() {
      _path.clear();
      _drawing = false;
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dark,
      appBar: AppBar(
        backgroundColor: _dark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            const Text(
              'RUN PATH',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 3,
              ),
            ),
            Text(
              _puzzle.difficulty,
              style: TextStyle(
                color: _puzzle.difficulty == 'Easy'
                    ? _green
                    : _puzzle.difficulty == 'Medium'
                        ? Colors.orange
                        : Colors.redAccent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white54),
            tooltip: 'Reset',
            onPressed: _solved ? null : _reset,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Instructions
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              'Connect checkpoints 1 → ${_puzzle.nodes.length} in order. Fill every cell.',
              style: const TextStyle(color: Colors.white38, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),

          // Grid
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final gridPx = math.min(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    final cellSize = gridPx / _puzzle.gridSize;
                    return Stack(
                      children: [
                        // Render grid
                        CustomPaint(
                          size: Size(gridPx, gridPx),
                          painter: _GridPainter(
                            puzzle: _puzzle,
                            path: List.unmodifiable(_path),
                            cellSize: cellSize,
                            solved: _solved,
                          ),
                        ),
                        // Gesture layer
                        if (!_solved)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanStart: (d) =>
                                _onPanStart(d.localPosition, cellSize),
                            onPanUpdate: (d) =>
                                _onPanUpdate(d.localPosition, cellSize),
                            onPanEnd: (_) => _onPanEnd(),
                            child: SizedBox(width: gridPx, height: gridPx),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),

          // Bottom area
          _buildBottom(),
        ],
      ),
    );
  }

  Widget _buildBottom() {
    if (_solved) {
      return _buildWinPanel();
    }
    // Progress hint
    final totalCells = _puzzle.gridSize * _puzzle.gridSize;
    final filled = _path.length;
    final nextCp = _nextCheckpointIndex();
    final nextLabel = nextCp < _puzzle.nodes.length ? '${nextCp + 1}' : '✓';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Next checkpoint: $nextLabel',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              Text(
                '$filled / $totalCells cells',
                style: TextStyle(
                  color: filled == totalCells ? _green : Colors.white38,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: filled / totalCells,
              minHeight: 5,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(_green),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _reset,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white54,
                side: const BorderSide(color: Colors.white12),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Reset Path'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWinPanel() {
    final stats = _finalStats;
    return ScaleTransition(
      scale: _winScale,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _green.withValues(alpha: 0.4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏁', style: TextStyle(fontSize: 42)),
            const SizedBox(height: 8),
            const Text(
              'Route Complete!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (stats != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _stat('🔥', '${stats.currentStreak}', 'Streak'),
                  _stat('🏆', '${stats.longestStreak}', 'Best'),
                  _stat('📅', '${stats.totalPlayed}', 'Played'),
                ],
              ),
              if (stats.currentStreak > 1) ...[
                const SizedBox(height: 12),
                Text(
                  '${stats.currentStreak}-day streak! Back tomorrow for a new route.',
                  style: const TextStyle(
                      color: _green, fontSize: 13, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ],
            ] else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text(
                  'Back to Feed',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String emoji, String value, String label) => Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom painter — draws the grid, path, and checkpoint nodes
// ─────────────────────────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  final RoutePuzzle puzzle;
  final List<GridCell> path;
  final double cellSize;
  final bool solved;

  static const _green = Color(0xFF00E676);
  static const _cellBg = Color(0xFF14142B);
  static const _gridLine = Color(0xFF2D2D44);

  const _GridPainter({
    required this.puzzle,
    required this.path,
    required this.cellSize,
    required this.solved,
  });

  Offset _center(int row, int col) => Offset(
        col * cellSize + cellSize / 2,
        row * cellSize + cellSize / 2,
      );

  @override
  void paint(Canvas canvas, Size size) {
    final gs = puzzle.gridSize;
    final pathSet = <GridCell>{...path};

    // ── Cell backgrounds ────────────────────────────────────────────────────
    final bgPaint = Paint()..color = _cellBg;
    final visitedPaint = Paint()..color = _green.withValues(alpha: 0.12);

    for (var r = 0; r < gs; r++) {
      for (var c = 0; c < gs; c++) {
        final rect = Rect.fromLTWH(
          c * cellSize + 1.5,
          r * cellSize + 1.5,
          cellSize - 3,
          cellSize - 3,
        );
        final cell = GridCell(r, c);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          pathSet.contains(cell) ? visitedPaint : bgPaint,
        );
      }
    }

    // ── Grid lines ─────────────────────────────────────────────────────────
    final linePaint = Paint()
      ..color = _gridLine
      ..strokeWidth = 1.5;
    for (var i = 0; i <= gs; i++) {
      canvas.drawLine(
          Offset(i * cellSize, 0), Offset(i * cellSize, size.height), linePaint);
      canvas.drawLine(
          Offset(0, i * cellSize), Offset(size.width, i * cellSize), linePaint);
    }

    // ── Path line ──────────────────────────────────────────────────────────
    if (path.length >= 2) {
      final pathPaint = Paint()
        ..color = solved ? _green : _green.withValues(alpha: 0.8)
        ..strokeWidth = cellSize * 0.32
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final p = Path();
      p.moveTo(_center(path[0].row, path[0].col).dx,
          _center(path[0].row, path[0].col).dy);
      for (var i = 1; i < path.length; i++) {
        p.lineTo(_center(path[i].row, path[i].col).dx,
            _center(path[i].row, path[i].col).dy);
      }
      canvas.drawPath(p, pathPaint);
    }

    // ── Checkpoint nodes ───────────────────────────────────────────────────
    for (var i = 0; i < puzzle.nodes.length; i++) {
      final node = puzzle.nodes[i];
      final center = _center(node.row, node.col);
      final cell = GridCell(node.row, node.col);
      final reached = pathSet.contains(cell);
      final radius = cellSize * 0.36;

      // Shadow/glow for unreached next checkpoint
      if (!reached) {
        canvas.drawCircle(
          center,
          radius + 4,
          Paint()..color = Colors.white.withValues(alpha: 0.06),
        );
      }

      // Circle fill
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = reached ? _green : const Color(0xFF1E1E3A),
      );

      // Circle border
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = reached ? _green : Colors.white38
          ..style = PaintingStyle.stroke
          ..strokeWidth = reached ? 0 : 2,
      );

      // Number label
      final label = '${i + 1}';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: reached ? Colors.black : Colors.white,
            fontSize: cellSize * 0.30,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        center - Offset(tp.width / 2, tp.height / 2),
      );
    }

    // ── Win sparkle overlay ────────────────────────────────────────────────
    if (solved) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = _green.withValues(alpha: 0.05),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      old.path != path || old.solved != solved;
}
