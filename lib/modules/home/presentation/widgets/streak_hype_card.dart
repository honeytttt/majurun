import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// E1 — Streak hype panel.
///
/// Pinned above the feed when the user has an active streak (currentStreak > 0).
/// Reads directly from the users/{uid} document so it always reflects the
/// latest streak written by StreakService after a run.
///
/// Tappable → opens [StreakHistorySheet] with full history.
/// Dismissible for the current session (not persisted — reappears on relaunch).
class StreakHypeCard extends StatefulWidget {
  const StreakHypeCard({super.key});

  @override
  State<StreakHypeCard> createState() => _StreakHypeCardState();
}

class _StreakHypeCardState extends State<StreakHypeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) return const SizedBox.shrink();

        final currentStreak = (data['currentStreak'] as int?) ?? 0;
        final longestStreak = (data['longestStreak'] as int?) ?? 0;

        if (currentStreak <= 0) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: GestureDetector(
            onTap: () => _showStreakSheet(context, currentStreak, longestStreak),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _gradientFor(currentStreak),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _shadowColor(currentStreak),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Animated fire icon — scales on the pulse animation
                  ScaleTransition(
                    scale: _pulseAnim,
                    child: Icon(
                      PhosphorIconsFill.fire,
                      color: Colors.white,
                      size: _fireSize(currentStreak),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _headline(currentStreak),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          longestStreak > currentStreak
                              ? 'Best: $longestStreak days  •  Tap for history'
                              : 'Personal best!  •  Tap for history',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Streak count badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$currentStreak',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Dismiss
                  GestureDetector(
                    onTap: () => setState(() => _dismissed = true),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white54, size: 18),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  List<Color> _gradientFor(int streak) {
    if (streak >= 30) {
      // Champion — deep purple/gold
      return [const Color(0xFF7B2FF7), const Color(0xFFE8A000)];
    } else if (streak >= 14) {
      // Platinum — steel blue/teal
      return [const Color(0xFF1565C0), const Color(0xFF00897B)];
    } else if (streak >= 7) {
      // Gold — amber/orange
      return [Colors.orange.shade600, Colors.orange.shade900];
    } else {
      // Active — brand green gradient
      return [const Color(0xFF00C853), const Color(0xFF00796B)];
    }
  }

  Color _shadowColor(int streak) {
    if (streak >= 30) return const Color(0xFF7B2FF7).withValues(alpha: 0.4);
    if (streak >= 14) return Colors.blue.withValues(alpha: 0.35);
    if (streak >= 7) return Colors.orange.withValues(alpha: 0.4);
    return const Color(0xFF00C853).withValues(alpha: 0.3);
  }

  double _fireSize(int streak) {
    if (streak >= 30) return 38;
    if (streak >= 14) return 34;
    if (streak >= 7) return 30;
    return 26;
  }

  String _headline(int streak) {
    if (streak == 1) return '1-Day Streak — Keep it going! 🔥';
    if (streak < 7) return '$streak-Day Streak — You\'re on fire!';
    if (streak < 14) return '$streak Days — Beast mode activated 🔥';
    if (streak < 30) return '$streak Days — Unstoppable! 💪';
    return '$streak Days — LEGENDARY RUNNER 👑';
  }

  void _showStreakSheet(
      BuildContext context, int currentStreak, int longestStreak) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _StreakHistorySheet(
        currentStreak: currentStreak,
        longestStreak: longestStreak,
      ),
    );
  }
}

// ── Streak History Sheet ─────────────────────────────────────────────────────

class _StreakHistorySheet extends StatelessWidget {
  final int currentStreak;
  final int longestStreak;
  const _StreakHistorySheet(
      {required this.currentStreak, required this.longestStreak});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Title row
          Row(
            children: [
              Icon(PhosphorIconsFill.fire,
                  color: Colors.orange.shade600, size: 28),
              const SizedBox(width: 10),
              const Text(
                'Your Streak',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Stats row
          Row(
            children: [
              _StatBlock(
                label: 'Current',
                value: '$currentStreak',
                unit: 'days',
                icon: PhosphorIconsFill.fire,
                color: Colors.orange.shade600,
              ),
              const SizedBox(width: 16),
              _StatBlock(
                label: 'Personal Best',
                value: '$longestStreak',
                unit: 'days',
                icon: PhosphorIconsFill.trophy,
                color: const Color(0xFFFFB300),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Milestone progress
          _MilestoneProgress(currentStreak: currentStreak),
          const SizedBox(height: 20),

          // Tip
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(PhosphorIconsDuotone.lightbulb,
                    color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Run every day to keep your streak alive. Missing a day resets it to zero.',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _StatBlock({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            Text(
              unit,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MilestoneProgress extends StatelessWidget {
  final int currentStreak;
  const _MilestoneProgress({required this.currentStreak});

  @override
  Widget build(BuildContext context) {
    // Milestones: 3, 7, 14, 30
    final milestones = [3, 7, 14, 30];
    final nextMilestone = milestones.firstWhere(
      (m) => m > currentStreak,
      orElse: () => 0,
    );

    if (nextMilestone == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7B2FF7), Color(0xFFE8A000)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.stars_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'LEGENDARY — 30+ day streak!',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    final prevMilestone =
        milestones.lastWhere((m) => m <= currentStreak, orElse: () => 0);
    final progress = nextMilestone > prevMilestone
        ? (currentStreak - prevMilestone) / (nextMilestone - prevMilestone)
        : 1.0;
    final daysLeft = nextMilestone - currentStreak;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Next milestone: $nextMilestone days',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              '$daysLeft day${daysLeft == 1 ? '' : 's'} to go',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade600),
          ),
        ),
      ],
    );
  }
}
