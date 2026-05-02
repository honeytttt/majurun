import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:majurun/core/services/remote_config_service.dart';
import 'package:majurun/core/services/subscription_service.dart';

/// P3 — Advanced split insights panel (Pro-only).
///
/// Renders below the standard splits list on [RunDetailScreen] when:
///   - Remote Config [RemoteConfigService.isAdvancedSplitsEnabled] is true, AND
///   - The user is a Pro subscriber (streamed from [SubscriptionService]).
///
/// Shows four insight blocks derived purely from the locally-available
/// [kmSplits] array — no extra Firestore reads:
///   1. Per-km pace deviation from run average (mini bar chart)
///   2. Fade % — how much slower the last km was vs the first
///   3. Projected race finish times at current fitness (Riegel formula)
///   4. Weekly training ratio recommendation (easy / threshold / interval)
///
/// Free users see a locked teaser card with an upgrade prompt.
class ProSplitInsights extends StatelessWidget {
  /// The full runData map from Firestore (same object passed to RunDetailScreen).
  final Map<String, dynamic> runData;

  const ProSplitInsights({super.key, required this.runData});

  @override
  Widget build(BuildContext context) {
    if (!RemoteConfigService().isAdvancedSplitsEnabled) return const SizedBox.shrink();

    final rawSplits = runData['kmSplits'];
    if (rawSplits is! List || rawSplits.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<bool>(
      stream: SubscriptionService().streamProStatus(),
      builder: (context, snap) {
        final isPro = snap.data ?? false;
        if (!isPro) return const _ProTeaser();
        return _InsightsPanel(splits: List<Map>.from(rawSplits));
      },
    );
  }
}

// ── Locked teaser for free users ─────────────────────────────────────────

class _ProTeaser extends StatelessWidget {
  const _ProTeaser();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF5F5F5), Color(0xFFEEEEEE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(PhosphorIconsFill.lock,
                color: Color(0xFFFFA000), size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Advanced Split Insights',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Pace trend, fade %, projected race times & training ratio — Pro only.',
                  style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Go Pro',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Full insights panel ───────────────────────────────────────────────────

class _InsightsPanel extends StatelessWidget {
  final List<Map> splits;
  const _InsightsPanel({required this.splits});

  // ── Helpers ──────────────────────────────────────────────────────────────

  double _paceToSecs(dynamic raw) {
    final s = raw?.toString() ?? '';
    final parts = s.split(':');
    if (parts.length != 2) return 300;
    return (int.tryParse(parts[0]) ?? 5) * 60.0 + (int.tryParse(parts[1]) ?? 0);
  }

  String _secsToStr(double secs) {
    if (secs <= 0) return '--:--';
    final m = secs ~/ 60;
    final s = (secs % 60).round();
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Riegel formula: T2 = T1 × (D2/D1)^1.06
  /// Converts a pace (s/km) over a known distance to a projected finish time.
  String _riegelTime(double paceSecsPerKm, double knownKm, double targetKm) {
    if (paceSecsPerKm <= 0 || knownKm <= 0) return '--:--';
    final t1 = paceSecsPerKm * knownKm;
    final t2 = t1 * math.pow(targetKm / knownKm, 1.06);
    final totalSecs = t2.round();
    final h = totalSecs ~/ 3600;
    final m = (totalSecs % 3600) ~/ 60;
    final s = totalSecs % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final paceSecs = splits.map((s) => _paceToSecs(s['pace'])).toList();
    final avgPace = paceSecs.reduce((a, b) => a + b) / paceSecs.length;
    final runDistKm = splits.length.toDouble(); // each split = 1 km

    final firstPace = paceSecs.first;
    final lastPace = paceSecs.last;
    final fadePercent = firstPace > 0
        ? ((lastPace - firstPace) / firstPace * 100)
        : 0.0;

    final fastestPace = paceSecs.reduce((a, b) => a < b ? a : b);
    final slowestPace = paceSecs.reduce((a, b) => a > b ? a : b);
    final paceRange = slowestPace - fastestPace;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),

        // ── Section header ──────────────────────────────────────────
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'PRO',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'SPLIT INSIGHTS',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── 1. Pace trend mini-chart ────────────────────────────────
        _SectionCard(
          icon: PhosphorIconsDuotone.chartBar,
          title: 'Pace trend',
          child: Column(
            children: splits.asMap().entries.map((e) {
              final idx = e.key;
              final pace = paceSecs[idx];
              final deviation = avgPace - pace; // positive = faster than avg
              final maxDev = paceRange > 0 ? paceRange / 2 : 1.0;
              final isFaster = deviation >= 0;
              final barColor = isFaster ? Colors.green.shade600 : Colors.red.shade500;
              final barFraction = deviation.abs() / maxDev.abs().clamp(1.0, double.infinity);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '${idx + 1}',
                        style: const TextStyle(fontSize: 11, color: Colors.black54),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Negative deviation bar (slower — right of centre)
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!isFaster)
                            Flexible(
                              flex: (barFraction * 100).round().clamp(1, 100),
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: barColor,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(4),
                                    bottomLeft: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          if (isFaster) const Spacer(),
                        ],
                      ),
                    ),
                    Container(width: 2, height: 14, color: Colors.black26),
                    // Positive deviation bar (faster — right of centre)
                    Expanded(
                      child: Row(
                        children: [
                          if (isFaster)
                            Flexible(
                              flex: (barFraction * 100).round().clamp(1, 100),
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: barColor,
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(4),
                                    bottomRight: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          if (!isFaster) const Spacer(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 40,
                      child: Text(
                        _secsToStr(pace),
                        style: TextStyle(
                          fontSize: 11,
                          color: isFaster ? Colors.green.shade700 : Colors.red.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 10),

        // ── 2. Fade % + projected times ────────────────────────────
        Row(
          children: [
            Expanded(
              child: _SectionCard(
                icon: PhosphorIconsDuotone.trendDown,
                title: 'Fade',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${fadePercent >= 0 ? '+' : ''}${fadePercent.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: fadePercent > 5
                            ? Colors.red.shade600
                            : fadePercent < -2
                                ? Colors.green.shade600
                                : Colors.black87,
                      ),
                    ),
                    Text(
                      fadePercent > 5
                          ? 'Significant fade — try negative splits'
                          : fadePercent < -2
                              ? 'Negative split — strong finish!'
                              : 'Even pace — well done',
                      style: const TextStyle(fontSize: 11, color: Colors.black54, height: 1.3),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SectionCard(
                icon: PhosphorIconsDuotone.flagCheckered,
                title: 'Projected times',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RaceTime(label: '5K', time: _riegelTime(avgPace, runDistKm, 5.0)),
                    _RaceTime(label: '10K', time: _riegelTime(avgPace, runDistKm, 10.0)),
                    _RaceTime(label: 'HM', time: _riegelTime(avgPace, runDistKm, 21.0975)),
                    _RaceTime(label: 'FM', time: _riegelTime(avgPace, runDistKm, 42.195)),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // ── 3. Training ratio recommendation ───────────────────────
        _SectionCard(
          icon: PhosphorIconsDuotone.calendar,
          title: 'Training mix this week',
          child: _TrainingRatio(weeklyKm: runDistKm),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Colors.black45),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _RaceTime extends StatelessWidget {
  final String label;
  final String time;

  const _RaceTime({required this.label, required this.time});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
          Text(time,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _TrainingRatio extends StatelessWidget {
  final double weeklyKm;
  const _TrainingRatio({required this.weeklyKm});

  @override
  Widget build(BuildContext context) {
    // Standard 80/10/10 polarised model, adapted by weekly volume.
    final easy = weeklyKm > 40
        ? 0.80
        : weeklyKm > 20
            ? 0.75
            : 0.70;
    final threshold = weeklyKm > 40
        ? 0.10
        : weeklyKm > 20
            ? 0.15
            : 0.20;
    final interval = 1.0 - easy - threshold;

    String pct(double v) => '${(v * 100).round()}%';

    return Column(
      children: [
        _RatioRow(label: 'Easy', color: Colors.green.shade400, fraction: easy, pct: pct(easy)),
        const SizedBox(height: 6),
        _RatioRow(label: 'Threshold', color: Colors.orange.shade400, fraction: threshold, pct: pct(threshold)),
        const SizedBox(height: 6),
        _RatioRow(label: 'Interval', color: Colors.red.shade400, fraction: interval, pct: pct(interval)),
        const SizedBox(height: 8),
        Text(
          weeklyKm > 40
              ? 'High volume — 80/10/10 polarised base'
              : weeklyKm > 20
                  ? 'Building — balanced pyramid'
                  : 'Lower volume — focus on easy aerobic base',
          style: const TextStyle(fontSize: 11, color: Colors.black45, height: 1.3),
        ),
      ],
    );
  }
}

class _RatioRow extends StatelessWidget {
  final String label;
  final Color color;
  final double fraction;
  final String pct;

  const _RatioRow({
    required this.label,
    required this.color,
    required this.fraction,
    required this.pct,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 30,
          child: Text(
            pct,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
