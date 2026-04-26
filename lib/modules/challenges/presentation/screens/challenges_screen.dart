import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:majurun/core/services/daily_challenge_service.dart';
import 'package:majurun/core/theme/app_effects.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DailyChallengeService _service = DailyChallengeService();
  String? _userId;

  List<Map<String, dynamic>> _dailyChallenges = [];
  List<Map<String, dynamic>> _weeklyChallenges = [];
  List<Map<String, dynamic>> _monthlyChallenges = [];

  bool _loadingDaily = true;
  bool _loadingWeekly = true;
  bool _loadingMonthly = true;
  bool _claimingBonus = false;
  bool _bonusClaimed = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (_userId == null) return;
    await Future.wait([
      _loadDaily(),
      _loadWeekly(),
      _loadMonthly(),
    ]);
  }

  Future<void> _loadDaily() async {
    setState(() => _loadingDaily = true);
    final challenges = await _service.getDailyChallenges(_userId!);
    if (mounted) setState(() { _dailyChallenges = challenges; _loadingDaily = false; });
  }

  Future<void> _loadWeekly() async {
    setState(() => _loadingWeekly = true);
    final challenges = await _service.getWeeklyChallenges(_userId!);
    if (mounted) setState(() { _weeklyChallenges = challenges; _loadingWeekly = false; });
  }

  Future<void> _loadMonthly() async {
    setState(() => _loadingMonthly = true);
    final challenges = await _service.getMonthlyChallenges(_userId!);
    if (mounted) setState(() { _monthlyChallenges = challenges; _loadingMonthly = false; });
  }

  bool get _allDailyComplete =>
      _dailyChallenges.isNotEmpty &&
      _dailyChallenges.every((c) => c['completed'] == true);

  Future<void> _logManualChallenge(Map<String, dynamic> challenge) async {
    if (_userId == null) return;
    final type = challenge['type'] as String;
    // Only allow manual completion for non-run challenges
    if (type == 'distance' || type == 'morning_run') return;

    final target = (challenge['target'] as num).toDouble();
    await _service.updateChallengeProgress(
      userId: _userId!,
      challengeId: challenge['id'],
      progress: target, // mark as fully done
    );
    await _loadDaily();
  }

  Future<void> _claimBonus() async {
    if (_userId == null || _claimingBonus) return;
    setState(() => _claimingBonus = true);
    final xp = await _service.claimDailyBonus(_userId!);
    if (!mounted) return;
    setState(() { _claimingBonus = false; _bonusClaimed = xp > 0; });
    if (xp > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Text('🎉 ', style: TextStyle(fontSize: 18)),
            Text('+$xp XP bonus claimed!', style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
          backgroundColor: const Color(0xFF00E676),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Challenges',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00E676),
          labelColor: const Color(0xFF00E676),
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'DAILY'),
            Tab(text: 'WEEKLY'),
            Tab(text: 'MONTHLY'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDailyTab(),
          _buildChallengeList(_weeklyChallenges, _loadingWeekly),
          _buildChallengeList(_monthlyChallenges, _loadingMonthly),
        ],
      ),
    );
  }

  Widget _buildDailyTab() {
    if (_loadingDaily) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)));
    }

    final completed = _dailyChallenges.where((c) => c['completed'] == true).length;
    final total = _dailyChallenges.length;

    return RefreshIndicator(
      color: const Color(0xFF00E676),
      backgroundColor: const Color(0xFF1A1A2E),
      onRefresh: _loadDaily,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Progress header
          _buildDailyHeader(completed, total),
          const SizedBox(height: 16),

          // Challenge cards
          ..._dailyChallenges.map((c) => _buildDailyChallengeCard(c)),

          // Bonus claim section
          if (_allDailyComplete) ...[
            const SizedBox(height: 16),
            _buildBonusCard(),
          ],

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildDailyHeader(int completed, int total) {
    final progress = total > 0 ? completed / total : 0.0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2A1A), Color(0xFF0D1F1D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.3)),
        boxShadow: AppEffects.neonGlow(color: const Color(0xFF00E676), opacity: 0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Today\'s Challenges',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 4),
                  Text('Complete all 3 for bonus XP!',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$completed / $total',
                  style: const TextStyle(
                    color: Color(0xFF00E676),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E676)),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyChallengeCard(Map<String, dynamic> challenge) {
    final completed = challenge['completed'] == true;
    final progress = (challenge['progress'] as num?)?.toDouble() ?? 0.0;
    final target = (challenge['target'] as num).toDouble();
    final progressRatio = (target > 0 ? (progress / target).clamp(0.0, 1.0) : 0.0);
    final xp = challenge['xpReward'] as int? ?? 0;
    final type = challenge['type'] as String? ?? '';
    final isManual = type != 'distance' && type != 'morning_run';
    final unit = challenge['unit'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: completed
            ? const Color(0xFF00E676).withValues(alpha: 0.08)
            : const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: completed
              ? const Color(0xFF00E676).withValues(alpha: 0.5)
              : const Color(0xFF2D2D44),
        ),
        boxShadow: AppEffects.softShadow(),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: completed
                        ? const Color(0xFF00E676).withValues(alpha: 0.2)
                        : const Color(0xFF2D2D44),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    completed ? Icons.check_circle : _iconForType(type),
                    color: completed ? const Color(0xFF00E676) : Colors.white70,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        challenge['name'] as String,
                        style: TextStyle(
                          color: completed ? const Color(0xFF00E676) : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          decoration: completed ? TextDecoration.lineThrough : null,
                          decorationColor: const Color(0xFF00E676),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        challenge['description'] as String,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+$xp XP',
                    style: const TextStyle(
                      color: Color(0xFFFFD700),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Progress bar + text
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progressRatio,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        completed ? const Color(0xFF00E676) : const Color(0xFF4FC3F7),
                      ),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  type == 'distance'
                      ? '${progress.toStringAsFixed(1)}/${target.toStringAsFixed(0)} $unit'
                      : completed
                          ? 'Done!'
                          : '0/${target.toStringAsFixed(0)} $unit',
                  style: TextStyle(
                    color: completed ? const Color(0xFF00E676) : Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (!completed && isManual) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _logManualChallenge(challenge),
                  icon: const Icon(Icons.add_task, size: 16),
                  label: const Text('Mark as Done'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00E676),
                    side: const BorderSide(color: Color(0xFF00E676), width: 1),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBonusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A1F00), Color(0xFF1A1400)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
        boxShadow: AppEffects.neonGlow(color: const Color(0xFFFFD700), opacity: 0.15),
      ),
      child: Column(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 8),
          const Text(
            'All Challenges Complete!',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'Claim your daily bonus XP',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _bonusClaimed ? null : _claimBonus,
              style: ElevatedButton.styleFrom(
                backgroundColor: _bonusClaimed ? Colors.grey : const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _claimingBonus
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : Text(
                      _bonusClaimed ? 'Bonus Claimed ✓' : 'Claim +50 XP Bonus',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeList(List<Map<String, dynamic>> challenges, bool loading) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)));
    }
    if (challenges.isEmpty) {
      return const Center(
        child: Text('No challenges available', style: TextStyle(color: Colors.white54)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: challenges.length,
      itemBuilder: (_, i) => _buildSimpleChallengeCard(challenges[i]),
    );
  }

  Widget _buildSimpleChallengeCard(Map<String, dynamic> challenge) {
    final completed = challenge['completed'] == true;
    final progress = (challenge['progress'] as num?)?.toDouble() ?? 0.0;
    final target = (challenge['target'] as num).toDouble();
    final progressRatio = target > 0 ? (progress / target).clamp(0.0, 1.0) : 0.0;
    final xp = challenge['xpReward'] as int? ?? 0;
    final type = challenge['type'] as String? ?? '';
    final unit = challenge['unit'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: completed
            ? const Color(0xFF00E676).withValues(alpha: 0.08)
            : const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: completed
              ? const Color(0xFF00E676).withValues(alpha: 0.5)
              : const Color(0xFF2D2D44),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: completed
                  ? const Color(0xFF00E676).withValues(alpha: 0.2)
                  : const Color(0xFF2D2D44),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              completed ? Icons.check_circle : _iconForType(type),
              color: completed ? const Color(0xFF00E676) : Colors.white70,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  challenge['name'] as String,
                  style: TextStyle(
                    color: completed ? const Color(0xFF00E676) : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressRatio,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      completed ? const Color(0xFF00E676) : const Color(0xFF4FC3F7),
                    ),
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${progress.toStringAsFixed(1)} / ${target.toStringAsFixed(0)} $unit',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '+$xp XP',
              style: const TextStyle(
                color: Color(0xFFFFD700),
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'distance':
      case 'morning_run':
        return Icons.directions_run;
      case 'workout_duration':
      case 'workout_count':
      case 'workout_variety':
        return Icons.fitness_center;
      case 'stretch':
        return Icons.self_improvement;
      case 'water':
        return Icons.water_drop;
      case 'streak':
        return Icons.local_fire_department;
      default:
        return Icons.emoji_events;
    }
  }
}
