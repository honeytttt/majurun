import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:majurun/core/widgets/empty_state_widget.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  List<Map<String, dynamic>>? _runs;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _fetchRuns();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _fetchRuns() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _error = true);
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('training_history')
          .orderBy('completedAt', descending: true)
          .limit(50)
          .get();

      final runs = snap.docs.map((d) {
        final data = d.data();
        data['_id'] = d.id;
        return data;
      }).toList();

      if (mounted) setState(() => _runs = runs);
    } catch (e) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        title: const Text(
          'Analytics',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0D0D1A),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tab,
          labelColor: const Color(0xFF00E676),
          unselectedLabelColor: Colors.white38,
          indicatorColor: const Color(0xFF00E676),
          tabs: const [
            Tab(text: 'Pace Trend'),
            Tab(text: 'Distance'),
            Tab(text: 'Heart Rate'),
          ],
        ),
      ),
      body: _error
          ? const EmptyStateWidget(
              icon: Icons.wifi_off_rounded,
              title: 'Could not load data',
              subtitle: 'Check your connection and try again.',
            )
          : _runs == null
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00E676)),
                )
              : TabBarView(
                  controller: _tab,
                  children: [
                    _PaceTrendTab(runs: _runs!),
                    _DistanceTab(runs: _runs!),
                    _HeartRateTab(runs: _runs!),
                  ],
                ),
    );
  }
}

// ── Pace Trend ──────────────────────────────────────────────────────────────

class _PaceTrendTab extends StatelessWidget {
  final List<Map<String, dynamic>> runs;
  const _PaceTrendTab({required this.runs});

  @override
  Widget build(BuildContext context) {
    final valid = runs
        .where((r) {
          final pace = r['pace'] as String?;
          return pace != null && pace.contains(':');
        })
        .take(8)
        .toList()
        .reversed
        .toList();

    if (valid.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.speed_rounded,
        title: 'No pace data',
        subtitle: 'Complete some runs to see your pace trend.',
      );
    }

    final spots = <FlSpot>[];
    double minY = double.infinity;
    double maxY = 0;

    for (int i = 0; i < valid.length; i++) {
      final pace = valid[i]['pace'] as String;
      final parts = pace.split(':');
      if (parts.length != 2) continue;
      final m = double.tryParse(parts[0]) ?? 0;
      final s = double.tryParse(parts[1]) ?? 0;
      final decimal = m + s / 60.0;
      spots.add(FlSpot(i.toDouble(), decimal));
      if (decimal < minY) minY = decimal;
      if (decimal > maxY) maxY = decimal;
    }

    final yPad = (maxY - minY) * 0.2 + 0.5;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PACE TREND — last 8 runs',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                backgroundColor: const Color(0xFF12122A),
                minY: (minY - yPad).clamp(0, double.infinity),
                maxY: maxY + yPad,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFF00E676),
                    barWidth: 2.5,
                    dotData: FlDotData(
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                        radius: 4,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: const Color(0xFF00E676),
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF00E676).withValues(alpha: 0.08),
                    ),
                  ),
                ],
                gridData: FlGridData(
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: Color(0xFF1A1A3A),
                    strokeWidth: 1,
                  ),
                  getDrawingVerticalLine: (_) => const FlLine(
                    color: Color(0xFF1A1A3A),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final m = v.toInt();
                        final s = ((v - m) * 60).round();
                        return Text(
                          '$m:${s.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.white38, fontSize: 10),
                        );
                      },
                      reservedSize: 44,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) => Text(
                        'R${v.toInt() + 1}',
                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    
                  ),
                  topTitles: const AxisTitles(
                    
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Distance Bar Chart ───────────────────────────────────────────────────────

class _DistanceTab extends StatelessWidget {
  final List<Map<String, dynamic>> runs;
  const _DistanceTab({required this.runs});

  @override
  Widget build(BuildContext context) {
    // Group runs by ISO week (last 8 weeks)
    final now = DateTime.now();
    final weeks = List.generate(8, (i) {
      final start = now.subtract(Duration(days: now.weekday - 1 + 7 * (7 - i)));
      return start;
    });

    final weeklyKm = List<double>.filled(8, 0);

    for (final run in runs) {
      final raw = run['completedAt'];
      DateTime? date;
      if (raw is Timestamp) {
        date = raw.toDate();
      } else if (raw is DateTime) {
        date = raw;
      }
      if (date == null) continue;

      final distKm = (run['distanceKm'] as num?)?.toDouble() ?? 0.0;

      for (int i = 0; i < weeks.length; i++) {
        final weekStart = weeks[i];
        final weekEnd = weekStart.add(const Duration(days: 7));
        if (!date.isBefore(weekStart) && date.isBefore(weekEnd)) {
          weeklyKm[i] += distKm;
          break;
        }
      }
    }

    final maxY = weeklyKm.reduce((a, b) => a > b ? a : b);

    if (maxY == 0) {
      return const EmptyStateWidget(
        icon: Icons.bar_chart_rounded,
        title: 'No distance data',
        subtitle: 'Complete some runs to see weekly distance.',
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WEEKLY DISTANCE — last 8 weeks',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: BarChart(
              BarChartData(
                backgroundColor: const Color(0xFF12122A),
                maxY: maxY * 1.25,
                barGroups: List.generate(8, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: weeklyKm[i],
                        color: const Color(0xFF00E676),
                        width: 18,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY * 1.25,
                          color: const Color(0xFF1A1A2E),
                        ),
                      ),
                    ],
                  );
                }),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}',
                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                      reservedSize: 32,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) => Text(
                        'W${v.toInt() + 1}',
                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    
                  ),
                  topTitles: const AxisTitles(
                    
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF1A1A2E),
                    getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                      '${rod.toY.toStringAsFixed(1)} km',
                      const TextStyle(
                        color: Color(0xFF00E676),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Heart Rate ───────────────────────────────────────────────────────────────

class _HeartRateTab extends StatelessWidget {
  final List<Map<String, dynamic>> runs;
  const _HeartRateTab({required this.runs});

  @override
  Widget build(BuildContext context) {
    final valid = runs
        .where((r) {
          final bpm = (r['avgBpm'] as num?)?.toInt() ?? 0;
          return bpm > 0;
        })
        .take(8)
        .toList()
        .reversed
        .toList();

    if (valid.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.favorite_border_rounded,
        title: 'Enable heart rate monitoring',
        subtitle: 'Connect a wearable or grant Health app permissions to see HR data.',
      );
    }

    final spots = <FlSpot>[];
    double minY = double.infinity;
    double maxY = 0;

    for (int i = 0; i < valid.length; i++) {
      final bpm = (valid[i]['avgBpm'] as num?)?.toDouble() ?? 0.0;
      spots.add(FlSpot(i.toDouble(), bpm));
      if (bpm < minY) minY = bpm;
      if (bpm > maxY) maxY = bpm;
    }

    final yPad = (maxY - minY) * 0.2 + 5;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'HEART RATE — last 8 runs',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                backgroundColor: const Color(0xFF12122A),
                minY: (minY - yPad).clamp(0, double.infinity),
                maxY: maxY + yPad,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.redAccent,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                        radius: 4,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: Colors.redAccent,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.redAccent.withValues(alpha: 0.08),
                    ),
                  ),
                ],
                gridData: FlGridData(
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: Color(0xFF1A1A3A),
                    strokeWidth: 1,
                  ),
                  getDrawingVerticalLine: (_) => const FlLine(
                    color: Color(0xFF1A1A3A),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}',
                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                      reservedSize: 36,
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) => Text(
                        'R${v.toInt() + 1}',
                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    
                  ),
                  topTitles: const AxisTitles(
                    
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
