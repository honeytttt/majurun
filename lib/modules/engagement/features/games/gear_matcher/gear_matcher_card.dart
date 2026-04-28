import 'package:flutter/material.dart';
import '../games_service.dart';

class GearMatcherCard extends StatefulWidget {
  final VoidCallback onDismiss;
  const GearMatcherCard({super.key, required this.onDismiss});

  @override
  State<GearMatcherCard> createState() => _GearMatcherCardState();
}

class _GearMatcherCardState extends State<GearMatcherCard> {
  // Each pair: shoe emoji + terrain
  static const _pairs = [
    _Pair(shoe: '👟', shoeLabel: 'Road Racer', terrain: '🛣️', terrainLabel: 'Road'),
    _Pair(shoe: '🥾', shoeLabel: 'Trail Boot', terrain: '🌲', terrainLabel: 'Trail'),
    _Pair(shoe: '👞', shoeLabel: 'Spike', terrain: '🏟️', terrainLabel: 'Track'),
    _Pair(shoe: '🏔️', shoeLabel: 'Cushioned', terrain: '🏖️', terrainLabel: 'Sand/Beach'),
  ];

  // User's current matches: shoe index → terrain index
  final Map<int, int?> _matches = {0: null, 1: null, 2: null, 3: null};
  int? _selectedShoe;
  bool _revealed = false;
  int _playCount = 0;

  @override
  void initState() {
    super.initState();
    GamesService.todaysPlayCount().then((c) {
      if (mounted) setState(() => _playCount = c);
    });
  }

  void _onTapShoe(int shoeIdx) {
    if (_revealed) return;
    setState(() => _selectedShoe = shoeIdx);
  }

  void _onTapTerrain(int terrainIdx) {
    if (_revealed || _selectedShoe == null) return;
    // Check if this terrain is already matched to another shoe
    final existing = _matches.entries
        .where((e) => e.value == terrainIdx && e.key != _selectedShoe)
        .toList();
    for (final e in existing) {
      _matches[e.key] = null;
    }
    setState(() {
      _matches[_selectedShoe!] = terrainIdx;
      _selectedShoe = null;
    });
  }

  bool get _allMatched => _matches.values.every((v) => v != null);

  int get _correctCount => _matches.entries
      .where((e) => e.value != null && e.value == e.key)
      .length;

  Future<void> _submit() async {
    setState(() => _revealed = true);
    await GamesService.markPlayed();
    if (mounted) setState(() => _playCount++);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 4),
          _buildInstruction(),
          _buildGame(),
          if (_revealed) _buildReveal(),
          if (!_revealed && _allMatched) _buildSubmitButton(),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
      child: Row(
        children: [
          const Text('👟', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'GEAR MATCHER',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ),
          if (_playCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$_playCount runners played',
                style: const TextStyle(color: Color(0xFFFFD700), fontSize: 10),
              ),
            ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.4), size: 18),
            onPressed: widget.onDismiss,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildInstruction() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        _selectedShoe == null
            ? 'Tap a shoe, then tap its matching terrain'
            : 'Now tap the terrain for ${_pairs[_selectedShoe!].shoeLabel}',
        style: TextStyle(
          color: _selectedShoe == null
              ? Colors.white.withValues(alpha: 0.5)
              : const Color(0xFFFFD700),
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildGame() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Shoes column
          Expanded(
            child: Column(
              children: List.generate(_pairs.length, (i) {
                final matched = _matches[i] != null;
                final selected = _selectedShoe == i;
                final correct = _revealed && _matches[i] == i;
                final wrong = _revealed && _matches[i] != null && _matches[i] != i;
                return GestureDetector(
                  onTap: () => _onTapShoe(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFFFD700).withValues(alpha: 0.2)
                          : correct
                              ? const Color(0xFF00E676).withValues(alpha: 0.15)
                              : wrong
                                  ? Colors.red.withValues(alpha: 0.15)
                                  : matched
                                      ? const Color(0xFF1A1A1A)
                                      : const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFFFFD700)
                            : correct
                                ? const Color(0xFF00E676)
                                : wrong
                                    ? Colors.red
                                    : Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_pairs[i].shoe, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _pairs[i].shoeLabel,
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          // Connector arrows
          Column(
            children: List.generate(_pairs.length, (i) {
              final matchedTo = _matches[i];
              return Container(
                height: 50,
                width: 40,
                alignment: Alignment.center,
                child: matchedTo != null
                    ? Text(
                        '→',
                        style: TextStyle(
                          color: _revealed
                              ? (matchedTo == i ? const Color(0xFF00E676) : Colors.red)
                              : const Color(0xFFFFD700),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : Icon(Icons.more_horiz, color: Colors.white.withValues(alpha: 0.15), size: 18),
              );
            }),
          ),
          // Terrains column
          Expanded(
            child: Column(
              children: List.generate(_pairs.length, (i) {
                final isMatched = _matches.values.contains(i);
                return GestureDetector(
                  onTap: () => _onTapTerrain(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMatched && _selectedShoe == null
                          ? const Color(0xFF1A1A1A)
                          : _selectedShoe != null
                              ? const Color(0xFF1DA1F2).withValues(alpha: 0.1)
                              : const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _selectedShoe != null
                            ? const Color(0xFF1DA1F2).withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_pairs[i].terrain, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _pairs[i].terrainLabel,
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFD700),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: const Text('Check My Answers', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildReveal() {
    final score = _correctCount;
    final total = _pairs.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Text(
        score == total
            ? '🏆 Perfect! $score/$total — You know your gear!'
            : '⚡ $score/$total correct — Road Racer → Road, Trail Boot → Trail, Spike → Track, Cushioned → Sand.',
        style: TextStyle(
          color: score == total ? const Color(0xFFFFD700) : Colors.white70,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Text(
        _revealed ? 'Right gear = fewer injuries!' : 'Match each shoe to its ideal terrain',
        style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11),
      ),
    );
  }
}

class _Pair {
  final String shoe;
  final String shoeLabel;
  final String terrain;
  final String terrainLabel;

  const _Pair({
    required this.shoe,
    required this.shoeLabel,
    required this.terrain,
    required this.terrainLabel,
  });
}
