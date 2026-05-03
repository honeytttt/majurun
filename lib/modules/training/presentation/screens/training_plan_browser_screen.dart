import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:majurun/core/services/subscription_service.dart';
import 'package:majurun/modules/training/data/training_plans_data.dart';
import 'package:majurun/modules/training/presentation/screens/training_plan_detail_screen.dart';
import 'package:majurun/modules/training/presentation/screens/training_schedule_screen.dart';
import 'package:majurun/modules/training/services/training_service.dart';

/// Full-screen plan browser — shows all training plans grouped by difficulty
/// with an "Active Plan" banner at the top when a plan is in progress.
class TrainingPlanBrowserScreen extends StatefulWidget {
  const TrainingPlanBrowserScreen({super.key});

  @override
  State<TrainingPlanBrowserScreen> createState() =>
      _TrainingPlanBrowserScreenState();
}

class _TrainingPlanBrowserScreenState
    extends State<TrainingPlanBrowserScreen> {
  bool _isPro = false;

  @override
  void initState() {
    super.initState();
    SubscriptionService().isProUser().then((v) {
      if (mounted) setState(() => _isPro = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final training = context.watch<TrainingService>();
    final plans = allTrainingPlans;

    // Group by difficulty label
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final plan in plans) {
      final diff = plan['difficulty'] as String? ?? 'Other';
      groups.putIfAbsent(diff, () => []).add(plan);
    }
    const order = ['Beginner', 'Intermediate', 'Advanced', 'Expert', 'Other'];

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        title: const Text('Training Plans'),
        backgroundColor: const Color(0xFF0D0D1A),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          // ── Active plan banner ──────────────────────────────────────────
          if (training.isActive && training.activePlan != null)
            _ActivePlanBanner(training: training),

          // ── Plans grouped by difficulty ─────────────────────────────────
          for (final diff in order)
            if (groups.containsKey(diff)) ...[
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(
                  diff.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF00E676),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              ...groups[diff]!.map((plan) => _PlanCard(
                    plan: plan,
                    isPro: _isPro,
                    isActive: training.activePlanTitle == plan['title'],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TrainingPlanDetailScreen(
                          planTitle: plan['title'] as String? ?? '',
                          planImageUrl: plan['imageUrl'] as String? ?? '',
                          planData: plan,
                        ),
                      ),
                    ),
                  )),
            ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Active plan banner ────────────────────────────────────────────────────

class _ActivePlanBanner extends StatelessWidget {
  final TrainingService training;
  const _ActivePlanBanner({required this.training});

  @override
  Widget build(BuildContext context) {
    final plan = training.activePlan!;
    final totalWeeks = plan['totalWeeks'] as int? ?? 1;
    final progress = training.getProgressPercentage();
    final remaining = training.getRemainingWorkouts();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => TrainingScheduleScreen(training: training)),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D1A0D), Color(0xFF162416)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: const Color(0xFF00E676).withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.play_circle_rounded,
                      color: Color(0xFF00E676), size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'ACTIVE PLAN',
                    style: TextStyle(
                      color: Color(0xFF00E676),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Week ${training.currentWeek} of $totalWeeks',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                plan['title'] as String? ?? '',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF00E676)),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(progress * 100).round()}% complete',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12),
                  ),
                  Text(
                    '$remaining workout${remaining == 1 ? '' : 's'} remaining',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _BannerButton(
                      label: 'View Schedule',
                      icon: Icons.calendar_today_rounded,
                      color: Colors.white12,
                      textColor: Colors.white70,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                TrainingScheduleScreen(training: training)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _BannerButton(
                      label: "Today's Run",
                      icon: Icons.directions_run_rounded,
                      color: const Color(0xFF00E676).withValues(alpha: 0.15),
                      textColor: const Color(0xFF00E676),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TrainingPlanDetailScreen(
                            planTitle: plan['title'] as String? ?? '',
                            planImageUrl: plan['imageUrl'] as String? ?? '',
                            planData: plan,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _BannerButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 14),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Individual plan card ──────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final bool isPro;
  final bool isActive;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.isPro,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final planIsPro = plan['isPro'] as bool? ?? false;
    final locked = planIsPro && !isPro;
    final imageUrl = plan['imageUrl'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF00E676).withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Cover image
                if (imageUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    color: Colors.black.withValues(alpha: locked ? 0.7 : 0.45),
                    colorBlendMode: BlendMode.darken,
                    errorWidget: (_, __, ___) => Container(
                        color: const Color(0xFF12122A)),
                  )
                else
                  Container(color: const Color(0xFF12122A)),

                // Content overlay
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              plan['title'] as String? ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              [
                                plan['duration'] as String? ?? '',
                                plan['frequency'] as String? ?? '',
                              ].where((s) => s.isNotEmpty).join(' · '),
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      // Badges
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (isActive)
                            _badge('Active', const Color(0xFF00E676)),
                          if (locked)
                            _badge('PRO', const Color(0xFFFFD700)),
                        ],
                      ),
                    ],
                  ),
                ),

                // Lock overlay
                if (locked)
                  const Positioned(
                    bottom: 14,
                    left: 14,
                    child: Icon(Icons.lock_rounded,
                        color: Colors.white54, size: 16),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      );
}
