import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// VO2max estimate card using the Jack Daniels VDOT formula.
///
/// Formula (Daniels & Gilbert):
///   VO2 at pace  = -4.60 + 0.182258·v + 0.000104·v²     (v = m/min)
///   %VO2max at t = 0.8 + 0.1894393·e^(-0.012778·t)
///                      + 0.2989558·e^(-0.1932605·t)      (t = minutes)
///   VO2max = VO2 / (%VO2max / 100)
///
/// Uses the best effort run (highest sustained pace for ≥3 km) from the
/// last 90 days in training_history.
class Vo2MaxCard extends StatefulWidget {
  const Vo2MaxCard({super.key});

  @override
  State<Vo2MaxCard> createState() => _Vo2MaxCardState();
}

class _Vo2MaxCardState extends State<Vo2MaxCard> {
  late Future<_Vo2Result?> _future;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _future = uid.isEmpty ? Future<_Vo2Result?>.value() : _calculate(uid);
  }

  static Future<_Vo2Result?> _calculate(String uid) async {
    final cutoff = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 90)));

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('training_history')
        .orderBy('completedAt', descending: true)
        .limit(50)
        .get();

    // Find best-effort run: highest pace where distance >= 3 km
    double bestVo2max = 0;
    String? bestRunLabel;
    DateTime? bestDate;

    for (final doc in snap.docs) {
      final data = doc.data();
      final completedAt = data['completedAt'];
      if (completedAt is! Timestamp) continue;
      if (completedAt.toDate().isBefore(cutoff.toDate())) continue;

      final distKm = (data['distanceKm'] as num?)?.toDouble() ?? 0.0;
      final durSecs = (data['durationSeconds'] as num?)?.toInt() ?? 0;

      if (distKm < 3.0 || durSecs <= 0) continue;

      // velocity in meters per minute
      final vMpm = (distKm * 1000) / (durSecs / 60.0);
      // duration in minutes
      final tMin = durSecs / 60.0;

      // Oxygen cost at this velocity
      final vo2AtPace = -4.60 + 0.182258 * vMpm + 0.000104 * vMpm * vMpm;

      // Fraction of VO2max sustained at this duration
      final pctVo2max = 0.8 +
          0.1894393 * math.exp(-0.012778 * tMin) +
          0.2989558 * math.exp(-0.1932605 * tMin);

      final vo2max = vo2AtPace / pctVo2max;

      if (vo2max > bestVo2max) {
        bestVo2max = vo2max;
        final paceMin = (durSecs / 60.0 / distKm).floor();
        final paceSec = ((durSecs / 60.0 / distKm - paceMin) * 60).round();
        bestRunLabel =
            '${distKm.toStringAsFixed(1)} km @ $paceMin:${paceSec.toString().padLeft(2, '0')}/km';
        bestDate = completedAt.toDate();
      }
    }

    if (bestVo2max < 10) return null; // sanity check
    return _Vo2Result(
      vo2max: bestVo2max,
      runLabel: bestRunLabel ?? '',
      date: bestDate ?? DateTime.now(),
    );
  }

  // Fitness category from VO2max (ml/kg/min), age-adjusted categories
  // Using general adult male/female averages (simplified):
  static String _category(double v) {
    if (v >= 55) return 'Superior';
    if (v >= 47) return 'Excellent';
    if (v >= 42) return 'Good';
    if (v >= 37) return 'Fair';
    if (v >= 30) return 'Average';
    return 'Below Average';
  }

  static Color _categoryColor(double v) {
    if (v >= 55) return const Color(0xFF00E676);
    if (v >= 47) return const Color(0xFF69F0AE);
    if (v >= 42) return const Color(0xFF29B6F6);
    if (v >= 37) return const Color(0xFFFFD700);
    if (v >= 30) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  // Gauge arc fraction 0–1 (20 = lowest, 70 = max we show)
  static double _gaugeFraction(double v) =>
      ((v - 20) / 50.0).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Vo2Result?>(
      future: _future,
      builder: (context, snap) {
        Widget body;

        if (snap.connectionState == ConnectionState.waiting) {
          body = const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(
                  color: Color(0xFF00E676), strokeWidth: 2),
            ),
          );
        } else if (snap.data == null) {
          body = const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(),
                SizedBox(height: 12),
                Text(
                  'Run at least 3 km to get your VO2max estimate.',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
          );
        } else {
          final result = snap.data!;
          final cat = _category(result.vo2max);
          final color = _categoryColor(result.vo2max);
          body = Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Header(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Gauge
                    SizedBox(
                      width: 90,
                      height: 90,
                      child: CustomPaint(
                        painter: _GaugePainter(
                          fraction: _gaugeFraction(result.vo2max),
                          color: color,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                result.vo2max.toStringAsFixed(1),
                                style: TextStyle(
                                  color: color,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'mL/kg/min',
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 9),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              cat,
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Based on: ${result.runLabel}',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(result.date),
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Scale legend
                _ScaleLegend(currentVo2: result.vo2max),
              ],
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: body,
        );
      },
    );
  }

  static String _formatDate(DateTime d) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.monitor_heart_outlined,
            color: Color(0xFF00E676), size: 20),
        SizedBox(width: 8),
        Text(
          'VO2max Estimate',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Spacer(),
        Tooltip(
          message:
              'Estimated using Jack Daniels VDOT formula from your best recent run.',
          child: Icon(Icons.info_outline,
              color: Colors.white24, size: 16),
        ),
      ],
    );
  }
}

// ─── Scale Legend ─────────────────────────────────────────────────────────────

class _ScaleLegend extends StatelessWidget {
  final double currentVo2;
  const _ScaleLegend({required this.currentVo2});

  @override
  Widget build(BuildContext context) {
    const levels = [
      ('Below Avg', 20.0, Color(0xFFF44336)),
      ('Average', 30.0, Color(0xFFFF9800)),
      ('Fair', 37.0, Color(0xFFFFD700)),
      ('Good', 42.0, Color(0xFF29B6F6)),
      ('Excellent', 47.0, Color(0xFF69F0AE)),
      ('Superior', 55.0, Color(0xFF00E676)),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: levels.map((l) {
        final isActive = currentVo2 >= l.$2;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: isActive
                ? l.$3.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? l.$3.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            l.$1,
            style: TextStyle(
              color: isActive ? l.$3 : Colors.white24,
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Gauge Painter ────────────────────────────────────────────────────────────

class _GaugePainter extends CustomPainter {
  final double fraction;
  final Color color;
  const _GaugePainter({required this.fraction, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;

    // Track (270° arc — bottom opens)
    const startAngle = 135 * math.pi / 180;
    const sweepAngle = 270 * math.pi / 180;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );

    // Progress
    if (fraction > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle * fraction,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.fraction != fraction || old.color != color;
}

// ─── Data ────────────────────────────────────────────────────────────────────

class _Vo2Result {
  final double vo2max;
  final String runLabel;
  final DateTime date;
  const _Vo2Result(
      {required this.vo2max, required this.runLabel, required this.date});
}
