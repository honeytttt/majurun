import 'package:flutter/material.dart';
import '../games_service.dart';
import 'pace_pulse_data.dart';

class PacePulseCard extends StatefulWidget {
  final VoidCallback onDismiss;
  const PacePulseCard({super.key, required this.onDismiss});

  @override
  State<PacePulseCard> createState() => _PacePulseCardState();
}

class _PacePulseCardState extends State<PacePulseCard> {
  late PacePulseScenario _scenario;
  String? _selected;
  bool _revealed = false;
  int _playCount = 0;

  @override
  void initState() {
    super.initState();
    final day = DateTime.now().difference(DateTime(2024)).inDays;
    _scenario = kPacePulseBank[day % kPacePulseBank.length];
    GamesService.todaysPlayCount().then((c) {
      if (mounted) setState(() => _playCount = c);
    });
  }

  Future<void> _pick(String zone) async {
    if (_revealed) return;
    setState(() {
      _selected = zone;
      _revealed = true;
    });
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
        border: Border.all(color: const Color(0xFF1DA1F2).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildStats(),
          _buildPrompt(),
          if (_revealed) _buildReveal() else _buildOptions(),
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
          const Text('💓', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'PACE PULSE',
              style: TextStyle(
                color: Color(0xFF1DA1F2),
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
                color: const Color(0xFF1DA1F2).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$_playCount runners played',
                style: const TextStyle(color: Color(0xFF1DA1F2), fontSize: 10),
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

  Widget _buildStats() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statChip('❤️', _scenario.heartRate),
          _statChip('⛰️', _scenario.elevation),
          _statChip('👟', _scenario.surface),
          _statChip('🌡️', _scenario.temperature),
        ],
      ),
    );
  }

  Widget _statChip(String emoji, String value) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildPrompt() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        'What effort zone is this runner in?',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildOptions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _scenario.options.map((zone) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ElevatedButton(
                onPressed: () => _pick(zone),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E1E1E),
                  foregroundColor: Colors.white,
                  side: BorderSide(color: const Color(0xFF1DA1F2).withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  zone,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReveal() {
    final correct = _selected == _scenario.correctZone;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                correct ? '✅ Right zone!' : '❌ Not quite!',
                style: TextStyle(
                  color: correct ? const Color(0xFF00E676) : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              if (!correct) ...[
                const SizedBox(width: 8),
                Text(
                  'Answer: ${_scenario.correctZone}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _scenario.explanation,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Text(
        _revealed ? 'Knowledge gained! See you tomorrow.' : 'Train smarter · daily coaching tip',
        style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11),
      ),
    );
  }
}
