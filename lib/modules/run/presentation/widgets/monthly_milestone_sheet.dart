import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MilestonePeriod { weekly, monthly }

/// Full-screen achievement overlay — shown when a weekly or monthly km milestone is crossed.
class MonthlyMilestoneSheet extends StatefulWidget {
  final double milestoneKm;
  final MilestonePeriod period;
  final VoidCallback onDismiss;

  const MonthlyMilestoneSheet({
    super.key,
    required this.milestoneKm,
    required this.period,
    required this.onDismiss,
  });

  // ── Monthly check ────────────────────────────────────────────────────────────

  /// Returns the first uncelebrated monthly milestone crossed this run, or null.
  static Future<double?> checkMonthly({required double runDistanceKm}) async {
    const milestones = [50.0, 100.0, 150.0, 200.0, 300.0];
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    try {
      final now = DateTime.now();
      final periodKey = 'monthly_${now.year}-${now.month.toString().padLeft(2, '0')}';
      final start = Timestamp.fromDate(DateTime(now.year, now.month));
      final end = Timestamp.fromDate(DateTime(now.year, now.month + 1));

      final total = await _queryTotal(uid, start, end);
      return _firstCrossed(milestones, total, runDistanceKm, periodKey);
    } catch (_) {}
    return null;
  }

  // ── Weekly check ─────────────────────────────────────────────────────────────

  /// Returns the first uncelebrated weekly milestone crossed this run, or null.
  static Future<double?> checkWeekly({required double runDistanceKm}) async {
    const milestones = [20.0, 40.0, 60.0, 80.0];
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    try {
      final now = DateTime.now();
      // ISO week: Monday = start of week
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final weekStart = DateTime(monday.year, monday.month, monday.day);
      final weekEnd = weekStart.add(const Duration(days: 7));

      // ISO week number for dedup key
      final weekNum = _isoWeek(now);
      final periodKey = 'weekly_${now.year}-W${weekNum.toString().padLeft(2, '0')}';

      final start = Timestamp.fromDate(weekStart);
      final end = Timestamp.fromDate(weekEnd);

      final total = await _queryTotal(uid, start, end);
      return _firstCrossed(milestones, total, runDistanceKm, periodKey);
    } catch (_) {}
    return null;
  }

  // ── Shared helpers ────────────────────────────────────────────────────────────

  static Future<double> _queryTotal(String uid, Timestamp start, Timestamp end) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('training_history')
        .where('completedAt', isGreaterThanOrEqualTo: start)
        .where('completedAt', isLessThan: end)
        .get();

    double total = 0.0;
    for (final doc in snap.docs) {
      total += (doc.data()['distanceKm'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }

  static Future<double?> _firstCrossed(
    List<double> milestones,
    double total,
    double runKm,
    String periodKey,
  ) async {
    final prev = total - runKm;
    final prefs = await SharedPreferences.getInstance();
    for (final milestone in milestones) {
      if (prev < milestone && total >= milestone) {
        final key = '${periodKey}_${milestone.toInt()}';
        if (!(prefs.getBool(key) ?? false)) {
          await prefs.setBool(key, true);
          return milestone;
        }
      }
    }
    return null;
  }

  /// ISO 8601 week number.
  static int _isoWeek(DateTime date) {
    final thursday = date.add(Duration(days: 4 - date.weekday));
    final firstThursday = DateTime(thursday.year, 1, 1);
    final dayDiff = thursday.difference(firstThursday).inDays;
    return 1 + dayDiff ~/ 7;
  }

  @override
  State<MonthlyMilestoneSheet> createState() => _MonthlyMilestoneSheetState();
}

class _MonthlyMilestoneSheetState extends State<MonthlyMilestoneSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  bool get _isWeekly => widget.period == MilestonePeriod.weekly;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _label => _isWeekly ? 'New weekly achievement' : 'New achievement';

  String get _headline {
    final km = widget.milestoneKm.toInt();
    if (_isWeekly) {
      if (km >= 80) return 'ELITE WEEK — UNSTOPPABLE!';
      if (km >= 60) return 'INCREDIBLE WEEKLY HAUL!';
      if (km >= 40) return 'OUTSTANDING WEEK!';
      return 'AWESOME WEEKLY RECORD!';
    } else {
      if (km >= 300) return 'ELITE MONTHLY RUNNER!';
      if (km >= 200) return 'INCREDIBLE MONTHLY RECORD!';
      if (km >= 150) return 'OUTSTANDING MONTH!';
      if (km >= 100) return 'CENTURY MONTH ACHIEVED!';
      return 'AWESOME MONTHLY RECORD!';
    }
  }

  String get _subtitle {
    final km = widget.milestoneKm.toInt();
    return _isWeekly
        ? 'You ran more than ${km}K this week'
        : 'You ran more than ${km}K this month';
  }

  void _share() {
    final km = widget.milestoneKm.toInt();
    final period = _isWeekly ? 'week' : 'month';
    SharePlus.instance.share(ShareParams(
      text: '🏃 Just crushed ${km}km this $period with MajuRun! $_headline #MajuRun #Running',
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            children: [
              const SizedBox(height: 56),
              Text(
                _label,
                style: const TextStyle(
                  color: Color(0xFF00E676),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              ScaleTransition(
                scale: _scale,
                child: SizedBox(
                  width: 260,
                  height: 260,
                  child: CustomPaint(
                    painter: _SpeedometerPainter(isWeekly: _isWeekly),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isWeekly)
                            Text(
                              'WEEK',
                              style: TextStyle(
                                color: const Color(0xFF00E676).withValues(alpha: 0.7),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                              ),
                            ),
                          Text(
                            '${widget.milestoneKm.toInt()}KM',
                            style: const TextStyle(
                              color: Color(0xFF00E676),
                              fontSize: 52,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _headline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF00E676),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 15,
                ),
              ),
              const Spacer(flex: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _share,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Share',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: widget.onDismiss,
                child: const Text(
                  'Next',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeedometerPainter extends CustomPainter {
  final bool isWeekly;
  const _SpeedometerPainter({this.isWeekly = false});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const green = Color(0xFF00E676);

    final arcPaint = Paint()
      ..color = green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final arcRect = Rect.fromCircle(center: center, radius: radius);

    // Top arc
    canvas.drawArc(arcRect, math.pi * 1.11, math.pi * 0.78, false, arcPaint);
    // Bottom arc
    canvas.drawArc(arcRect, math.pi * 0.11, math.pi * 0.78, false, arcPaint);

    // Tick marks
    final tickPaint = Paint()
      ..color = green
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const totalTicks = 64;
    for (int i = 0; i < totalTicks; i++) {
      final angle = (2 * math.pi * i / totalTicks) - math.pi / 2;
      final norm = (angle + math.pi * 2.5) % (2 * math.pi);

      if (norm < 0.32 || norm > math.pi * 2 - 0.32) continue;
      if (norm > math.pi - 0.32 && norm < math.pi + 0.32) continue;

      final isMajor = i % 4 == 0;
      final tickLen = isMajor ? 13.0 : 7.0;
      tickPaint
        ..strokeWidth = isMajor ? 2.0 : 1.2
        ..color = green.withValues(alpha: isMajor ? 1.0 : 0.7);

      final outer = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      final inner = Offset(
        center.dx + (radius - tickLen) * math.cos(angle),
        center.dy + (radius - tickLen) * math.sin(angle),
      );
      canvas.drawLine(inner, outer, tickPaint);
    }

    // Horizontal accent lines flanking the text
    final linePaint = Paint()
      ..color = green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final topLineY = isWeekly ? center.dy - 30 : center.dy - 22;
    canvas.drawLine(Offset(center.dx - 60, topLineY),
        Offset(center.dx + 60, topLineY), linePaint);
    canvas.drawLine(Offset(center.dx - 60, center.dy + 32),
        Offset(center.dx + 60, center.dy + 32), linePaint);
  }

  @override
  bool shouldRepaint(_SpeedometerPainter old) => old.isWeekly != isWeekly;
}
