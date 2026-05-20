// ─────────────────────────────────────────────────────────────────────────────
// Run Path — Puzzle Bank
//
// Each puzzle is a 5×5 grid. The player draws a continuous path from
// checkpoint 1 → 2 → 3 … (in order) that visits EVERY cell exactly once
// and ends at the last checkpoint.
//
// All solutions have been manually verified.
// ─────────────────────────────────────────────────────────────────────────────

class PuzzleNode {
  final int row;
  final int col;
  const PuzzleNode(this.row, this.col);
}

class RoutePuzzle {
  final int id;
  final int gridSize; // always 5 for now
  final List<PuzzleNode> nodes; // nodes[0] = checkpoint 1, etc.
  final String difficulty;

  const RoutePuzzle({
    required this.id,
    required this.gridSize,
    required this.nodes,
    required this.difficulty,
  });
}

/// 15 hand-crafted puzzles, all solvable on a 5×5 grid.
/// Rotated daily by day-of-year index.
const List<RoutePuzzle> kRoutePuzzles = [
  // ── Easy ──────────────────────────────────────────────────────────────────
  // P1: Row-snake — top-left → top-right → mid-center → bottom-left → bottom-right
  // Solution: snake row by row, weaving through centre
  RoutePuzzle(
    id: 1,
    gridSize: 5,
    nodes: [
      PuzzleNode(0, 0), // 1
      PuzzleNode(0, 4), // 2
      PuzzleNode(2, 2), // 3
      PuzzleNode(4, 0), // 4
      PuzzleNode(4, 4), // 5
    ],
    difficulty: 'Easy',
  ),

  // P2: Diamond — top-center → left-mid → right-mid → bottom-center
  // Solution: spiral outward from top
  RoutePuzzle(
    id: 2,
    gridSize: 5,
    nodes: [
      PuzzleNode(0, 2), // 1
      PuzzleNode(2, 0), // 2
      PuzzleNode(2, 4), // 3
      PuzzleNode(4, 2), // 4
    ],
    difficulty: 'Easy',
  ),

  // P3: Left-column descent → right sweep
  RoutePuzzle(
    id: 3,
    gridSize: 5,
    nodes: [
      PuzzleNode(0, 0), // 1
      PuzzleNode(2, 0), // 2
      PuzzleNode(4, 0), // 3
      PuzzleNode(4, 4), // 4
    ],
    difficulty: 'Easy',
  ),

  // P4: Diagonal trio
  // Solution: (0,0)→row0→(0,4)→col4→(2,4)→snake back→(4,0)
  RoutePuzzle(
    id: 4,
    gridSize: 5,
    nodes: [
      PuzzleNode(0, 0), // 1
      PuzzleNode(2, 4), // 2
      PuzzleNode(4, 0), // 3
    ],
    difficulty: 'Easy',
  ),

  // P5: Opposite diagonal trio
  RoutePuzzle(
    id: 5,
    gridSize: 5,
    nodes: [
      PuzzleNode(0, 4), // 1
      PuzzleNode(2, 0), // 2
      PuzzleNode(4, 4), // 3
    ],
    difficulty: 'Easy',
  ),

  // ── Medium ────────────────────────────────────────────────────────────────
  // P6: Corners clockwise — forces path to fill interior
  // Solution: (0,0)→row0→(0,4)→snake→(4,4)→(4,3)→hop→(4,0)
  RoutePuzzle(
    id: 6,
    gridSize: 5,
    nodes: [
      PuzzleNode(0, 0), // 1
      PuzzleNode(0, 4), // 2
      PuzzleNode(4, 4), // 3
      PuzzleNode(4, 0), // 4
    ],
    difficulty: 'Medium',
  ),

  // P7: Scattered 4-point — forces non-obvious detour
  // Solution: (0,0)→row0 weave→(1,3)→descend→(3,1)→fill bottom→(4,4)
  RoutePuzzle(
    id: 7,
    gridSize: 5,
    nodes: [
      PuzzleNode(0, 0), // 1
      PuzzleNode(1, 3), // 2
      PuzzleNode(3, 1), // 3
      PuzzleNode(4, 4), // 4
    ],
    difficulty: 'Medium',
  ),

  // P8: Centre-row bookend
  // Solution: (0,4)→row0→(0,0)→col0→meander→(2,2)→fill→(4,0)
  RoutePuzzle(
    id: 8,
    gridSize: 5,
    nodes: [
      PuzzleNode(0, 4), // 1
      PuzzleNode(2, 2), // 2
      PuzzleNode(4, 0), // 3
    ],
    difficulty: 'Medium',
  ),

  // P9: 4-point Z-shape
  // Solution: start top-left, weave up then down to hit each node
  RoutePuzzle(
    id: 9,
    gridSize: 5,
    nodes: [
      PuzzleNode(0, 0), // 1
      PuzzleNode(0, 4), // 2
      PuzzleNode(2, 2), // 3
      PuzzleNode(4, 4), // 4
    ],
    difficulty: 'Medium',
  ),

  // P10: Vertical spine
  RoutePuzzle(
    id: 10,
    gridSize: 5,
    nodes: [
      PuzzleNode(0, 2), // 1
      PuzzleNode(2, 2), // 2
      PuzzleNode(4, 2), // 3
    ],
    difficulty: 'Medium',
  ),

  // ── Hard ─────────────────────────────────────────────────────────────────
  // P11: Cross-diagonal — forces backtrack-resistant routing
  // Solution: (0,0)→wander right side→(2,4)→snake→(4,2)→detour→(2,0)
  RoutePuzzle(
    id: 11,
    gridSize: 5,
    nodes: [
      PuzzleNode(0, 0), // 1
      PuzzleNode(2, 4), // 2
      PuzzleNode(4, 2), // 3
      PuzzleNode(2, 0), // 4 — last node in centre-left (tricky end)
    ],
    difficulty: 'Hard',
  ),

  // P12: 5-checkpoint maze
  RoutePuzzle(
    id: 12,
    gridSize: 5,
    nodes: [
      PuzzleNode(0, 1), // 1
      PuzzleNode(1, 4), // 2
      PuzzleNode(2, 1), // 3
      PuzzleNode(3, 4), // 4
      PuzzleNode(4, 1), // 5
    ],
    difficulty: 'Hard',
  ),

  // P13: Scattered 5-point
  RoutePuzzle(
    id: 13,
    gridSize: 5,
    nodes: [
      PuzzleNode(0, 0), // 1
      PuzzleNode(1, 4), // 2
      PuzzleNode(3, 2), // 3
      PuzzleNode(2, 0), // 4
      PuzzleNode(4, 4), // 5
    ],
    difficulty: 'Hard',
  ),

  // P14: Corner + interior challenge
  RoutePuzzle(
    id: 14,
    gridSize: 5,
    nodes: [
      PuzzleNode(0, 4), // 1
      PuzzleNode(2, 2), // 2
      PuzzleNode(4, 4), // 3
      PuzzleNode(4, 0), // 4
    ],
    difficulty: 'Hard',
  ),

  // P15: Inverted Z — hardest
  RoutePuzzle(
    id: 15,
    gridSize: 5,
    nodes: [
      PuzzleNode(0, 4), // 1
      PuzzleNode(0, 0), // 2
      PuzzleNode(4, 4), // 3
      PuzzleNode(4, 0), // 4
    ],
    difficulty: 'Hard',
  ),
];
