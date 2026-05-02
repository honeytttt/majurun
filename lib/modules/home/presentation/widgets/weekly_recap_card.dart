import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:majurun/core/services/remote_config_service.dart';
import 'package:majurun/core/services/subscription_service.dart';
import 'package:majurun/core/services/weekly_summary_service.dart';

/// E2 — Weekly recap card.
///
/// Shown in the feed for 24 h after Sunday 20:00, matching the weekly
/// notification cadence. Reads the prior full week's stats via
/// [WeeklySummaryService] (no new Firestore queries — reuses the same
/// runHistory collection the notification already reads).
///
/// Free tier  : total distance, run count, longest run.
/// Pro tier   : + pace delta vs previous week (upgrade hook label when free).
///
/// Behind Remote Config key [RemoteConfigService.enableWeeklyRecap]
/// (default true). Dismissible for the current session.
class WeeklyRecapCard extends StatefulWidget {
  const WeeklyRecapCard({super.key});

  @override
  State<WeeklyRecapCard> createState() => _WeeklyRecapCardState();
}

class _WeeklyRecapCardState extends State<WeeklyRecapCard> {
  bool _dismissed = false;

  /// Returns the most recent Sunday at 20:00 local time (start of the 24 h
  /// window in which the card is visible).
  static DateTime? _windowStart() {
    final now = DateTime.now();
    // weekday: Mon=1 … Sun=7
    final daysSinceSunday = now.weekday == 7 ? 0 : now.weekday;
    final lastSunday = now.subtract(Duration(days: daysSinceSunday));
    final start = DateTime(lastSunday.year, lastSunday.month, lastSunday.day, 20);
    final end = start.add(const Duration(hours: 24));
    if (now.isAfter(start) && now.isBefore(end)) return start;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    if (FirebaseAuth.instance.currentUser == null) return const SizedBox.shrink();

    // Kill switch
    if (!RemoteConfigService().isWeeklyRecapEnabled) return const SizedBox.shrink();

    final windowStart = _windowStart();
    if (windowStart == null) return const SizedBox.shrink();

    // Recap covers the 7-day week that ended at Sunday 20:00.
    final weekEnd = windowStart;
    final weekStart = weekEnd.subtract(const Duration(days: 7));

    return FutureBuilder<WeeklySummary>(
      future: WeeklySummaryService().getWeekSummary(
        DateTime(weekStart.year, weekStart.month, weekStart.day),
      ),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final recap = snap.data!;
        if (recap.totalRuns == 0) return const SizedBox.shrink();

        return StreamBuilder<bool>(
          stream: SubscriptionService().streamProStatus(),
          builder: (context, proSnap) {
            final isPro = proSnap.data ?? false;
            return _RecapCardBody(
              recap: recap,
              isPro: isPro,
              onDismiss: () => setState(() => _dismissed = true),
            );
          },
        );
      },
    );
  }
}

// ── Card body ─────────────────────────────────────────────────────────────

class _RecapCardBody extends StatelessWidget {
  final WeeklySummary recap;
  final bool isPro;
  final VoidCallback onDismiss;

  const _RecapCardBody({
    required this.recap,
    required this.isPro,
    required this.onDismiss,
  });

  String _formatPace(double secsPerKm) {
    if (secsPerKm <= 0) return '--:--';
    final m = secsPerKm ~/ 60;
    final s = (secsPerKm % 60).round();
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _shareSummary() {
    final dist = recap.totalDistanceKm.toStringAsFixed(1);
    final runs = recap.totalRuns;
    final longest = recap.longestRunKm.toStringAsFixed(1);
    final pace = _formatPace(recap.averagePaceSecondsPerKm);
    return 'My week with MajuRun 🏃‍♂️\n'
        '${recap.totalRuns} run${runs == 1 ? '' : 's'}  •  ${dist}km  •  ${longest}km longest\n'
        'Avg pace: $pace/km\n'
        '#MajuRun #Running #WeeklyRecap';
  }

  @override
  Widget build(BuildContext context) {
    final dist = recap.totalDistanceKm;
    final changePct = recap.distanceChangePercent;
    final changeSign = changePct >= 0 ? '+' : '';
    final changeColor = changePct >= 0 ? Colors.green.shade600 : Colors.red.shade600;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1565C0).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            Row(
              children: [
                const Icon(PhosphorIconsFill.chartBar, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Your Week',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onDismiss,
                  child: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Stat row ────────────────────────────────────────────
            Row(
              children: [
                _Stat(
                  icon: PhosphorIconsDuotone.path,
                  label: 'Distance',
                  value: '${dist.toStringAsFixed(1)} km',
                ),
                _divider(),
                _Stat(
                  icon: PhosphorIconsDuotone.sneaker,
                  label: 'Runs',
                  value: '${recap.totalRuns}',
                ),
                _divider(),
                _Stat(
                  icon: PhosphorIconsDuotone.arrowsOutSimple,
                  label: 'Longest',
                  value: '${recap.longestRunKm.toStringAsFixed(1)} km',
                ),
                // Pro: pace delta vs last week
                if (isPro && recap.averagePaceSecondsPerKm > 0) ...[
                  _divider(),
                  _Stat(
                    icon: PhosphorIconsDuotone.chartLineUp,
                    label: 'vs last week',
                    value: '$changeSign${changePct.toStringAsFixed(0)}%',
                    valueColor: changeColor,
                  ),
                ] else if (!isPro) ...[
                  _divider(),
                  _ProTeaser(),
                ],
              ],
            ),

            const SizedBox(height: 12),

            // ── Share button ────────────────────────────────────────
            GestureDetector(
              onTap: () => SharePlus.instance.share(
                ShareParams(
                  text: _shareSummary(),
                  subject: 'My Running Week',
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white30),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(PhosphorIconsDuotone.paperPlaneTilt, color: Colors.white, size: 15),
                    SizedBox(width: 6),
                    Text(
                      'Share recap',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 32,
        color: Colors.white24,
        margin: const EdgeInsets.symmetric(horizontal: 10),
      );
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white60, size: 13),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 10),
        ),
      ],
    );
  }
}

class _ProTeaser extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(PhosphorIconsFill.lock, color: Colors.white38, size: 13),
        SizedBox(height: 3),
        Text(
          'vs last week',
          style: TextStyle(
            color: Colors.white38,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
        Text(
          'Pro only',
          style: TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ],
    );
  }
}
