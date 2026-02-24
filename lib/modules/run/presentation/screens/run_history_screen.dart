import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:majurun/modules/run/controllers/run_controller.dart';
import 'package:majurun/modules/run/presentation/screens/run_detail_screen.dart';
import 'package:majurun/core/services/badge_service.dart';
import 'package:majurun/modules/profile/presentation/widgets/badge_chip.dart';
import 'package:majurun/core/services/health_sync_service.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';


class RunHistoryScreen extends StatefulWidget {
  final VoidCallback onBack;
  const RunHistoryScreen({super.key, required this.onBack});

  @override
  State<RunHistoryScreen> createState() => _RunHistoryScreenState();
}

class _RunHistoryScreenState extends State<RunHistoryScreen> {
  Future<List<Map<String, dynamic>>>? _historyFuture;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = Provider.of<RunController>(context, listen: false);
      setState(() {
        _historyFuture = controller.getRunHistory();
      });
    });
  }

  Future<void> _refreshHistory() async {
    final controller = Provider.of<RunController>(context, listen: false);
    setState(() {
      _historyFuture = controller.getRunHistory();
    });
    await _historyFuture;
  }

  Future<void> _syncHealthData() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);

    try {
      final service = HealthSyncService();
      final result = await service.syncData(days: 365); // Sync last year

      if (!mounted) return;

      if (result.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: ${result.error}'),
            backgroundColor: Colors.red,
          ),
        );
      } else if (result.imported > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Imported ${result.imported} runs from health apps'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        await _refreshHistory();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No new runs to import'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Consumer<RunController>(
        builder: (context, controller, child) {
          final future = _historyFuture ?? controller.getRunHistory();
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: future,
            builder: (context, snapshot) {
              final runs = snapshot.data ?? [];
              return RefreshIndicator(
                onRefresh: _refreshHistory,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverAppBar(
                      pinned: true,
                      floating: false,
                      expandedHeight: 60,
                      backgroundColor: Colors.white,
                      elevation: 2,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black),
                        onPressed: widget.onBack,
                      ),
                      title: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "MY ",
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              fontSize: 16,
                            ),
                          ),
                          Icon(Icons.directions_run, color: Colors.black, size: 18),
                          Text(
                            " HISTORY",
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      centerTitle: true,
                      actions: [
                        IconButton(
                          icon: _isSyncing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Icon(Icons.sync, color: Colors.black),
                          tooltip: 'Import from Health Apps',
                          onPressed: _isSyncing ? null : _syncHealthData,
                        ),
                        IconButton(
                          icon: const Icon(Icons.share, color: Colors.black),
                          onPressed: () => _shareHistory(context, runs),
                        ),
                      ],
                    ),

                    SliverToBoxAdapter(
                      child: Container(
                        color: Colors.white,
                        child: _buildSummaryHeader(runs),
                      ),
                    ),

                    SliverToBoxAdapter(
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: const Row(
                          children: [
                            Icon(Icons.history, size: 16, color: Colors.grey),
                            SizedBox(width: 8),
                            Text(
                              "RECENT SESSIONS",
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (snapshot.connectionState == ConnectionState.waiting)
                      const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator(color: Colors.black)),
                      )
                    else if (snapshot.hasError)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 48),
                              const SizedBox(height: 16),
                              Text("Unable to load history", style: TextStyle(color: Colors.grey.shade600)),
                              const SizedBox(height: 10),
                              Text("Pull to refresh", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                            ],
                          ),
                        ),
                      )
                    else if (runs.isEmpty)
                      const SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.directions_run, size: 48, color: Colors.grey),
                              SizedBox(height: 16),
                              Text("No sessions yet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                              SizedBox(height: 8),
                              Text("Start your first session.", style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._buildGroupedRunsList(context, runs),

                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ---------------- grouped list by month ----------------
  List<Widget> _buildGroupedRunsList(BuildContext context, List<Map<String, dynamic>> runs) {
    // Sort runs by date descending (newest first)
    final sortedRuns = List<Map<String, dynamic>>.from(runs)
      ..sort((a, b) => _parseDate(b['date']).compareTo(_parseDate(a['date'])));

    // Group runs by month-year
    final Map<String, List<Map<String, dynamic>>> groupedRuns = {};
    final Map<String, double> monthlyTotals = {};

    for (final run in sortedRuns) {
      final date = _parseDate(run['date']);
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';

      groupedRuns.putIfAbsent(key, () => []);
      groupedRuns[key]!.add(run);

      final distVal = run['distance'] ?? 0.0;
      final distance = (distVal is num) ? distVal.toDouble() : 0.0;
      monthlyTotals[key] = (monthlyTotals[key] ?? 0.0) + distance;
    }

    // Sort keys descending (newest month first)
    final sortedKeys = groupedRuns.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final List<Widget> slivers = [];

    for (final key in sortedKeys) {
      final monthRuns = groupedRuns[key]!;
      final totalKm = monthlyTotals[key] ?? 0.0;
      final date = _parseDate(monthRuns.first['date']);
      final monthName = DateFormat('MMM').format(date).toUpperCase();
      final year = date.year;

      // Month header
      slivers.add(
        SliverToBoxAdapter(
          child: _buildMonthHeader(monthName, year, totalKm),
        ),
      );

      // Runs for this month
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildRunCard(context, monthRuns[index]),
              ),
              childCount: monthRuns.length,
            ),
          ),
        ),
      );
    }

    return slivers;
  }

  Widget _buildMonthHeader(String month, int year, double totalKm) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade500,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.calendar_month, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    month,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    year.toString(),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade600],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.directions_run, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  "${totalKm.toStringAsFixed(1)} KM",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- helpers ----------------
  String _getSourceLabel(String source) {
    final lower = source.toLowerCase();
    if (lower.contains('strava')) return 'STRAVA';
    if (lower.contains('nike')) return 'NIKE';
    if (lower.contains('garmin')) return 'GARMIN';
    if (lower.contains('fitbit')) return 'FITBIT';
    if (lower.contains('samsung')) return 'SAMSUNG';
    if (lower.contains('google')) return 'GOOGLE';
    if (lower.contains('apple') || lower.contains('health')) return 'HEALTH';
    return 'IMPORTED';
  }

  bool _isTrainingRun(Map<String, dynamic> run) {
    final type = run['type']?.toString().toLowerCase();
    if (type == 'training') return true;
    if (run['week'] != null && run['day'] != null) return true;
    final weekDay = run['weekDay']?.toString().toLowerCase();
    if (weekDay != null && weekDay.contains('week') && weekDay.contains('day')) return true;
    return false;
  }

  String _weekDayLabel(Map<String, dynamic> run) {
    final week = run['week'];
    final day = run['day'];
    if (week != null && day != null) return "Wk $week • Day $day";
    final weekDay = run['weekDay']?.toString();
    if (weekDay != null && weekDay.isNotEmpty) {
      return weekDay.replaceAll("Week", "Wk").replaceAll(",", " •");
    }
    return "";
  }

  bool? _completedFlag(Map<String, dynamic> run) {
    final v = run['completed'];
    if (v is bool) return v;
    if (v is String) {
      if (v.toLowerCase() == 'true') return true;
      if (v.toLowerCase() == 'false') return false;
    }
    return null;
  }

  DateTime _parseDate(dynamic raw) {
    if (raw is DateTime) return raw;
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  // Robust parsing for points: LatLng, GeoPoint, Map(lat/lng), Map(latitude/longitude)
  List<LatLng> _extractLatLngList(dynamic raw) {
    if (raw == null) return <LatLng>[];
    if (raw is List<LatLng>) return raw;
    if (raw is List) {
      final out = <LatLng>[];
      for (final p in raw) {
        if (p is LatLng) {
          out.add(p);
        } else if (p is GeoPoint) {
          out.add(LatLng(p.latitude, p.longitude));
        } else if (p is Map) {
          final lat = (p['lat'] ?? p['latitude']);
          final lng = (p['lng'] ?? p['longitude']);
          if (lat is num && lng is num) out.add(LatLng(lat.toDouble(), lng.toDouble()));
        }
      }
      return out;
    }
    return <LatLng>[];
  }

  // ✅ Preview-only sanitization: removes GPS jump spikes + downsample for web/static map URL size.
  List<LatLng> _sanitizeAndDownsample(List<LatLng> points, {double maxJumpMeters = 120, int maxPoints = 220}) {
    if (points.length < 2) return points;

    final filtered = <LatLng>[points.first];
    for (int i = 1; i < points.length; i++) {
      final d = _haversineMeters(filtered.last, points[i]);
      if (d <= maxJumpMeters) filtered.add(points[i]);
    }

    if (filtered.length <= maxPoints) return filtered;

    final step = (filtered.length / maxPoints).ceil();
    final out = <LatLng>[];
    for (int i = 0; i < filtered.length; i += step) {
      out.add(filtered[i]);
    }
    if (out.last != filtered.last) out.add(filtered.last);
    return out;
  }

  double _haversineMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLng = _degToRad(b.longitude - a.longitude);
    final la1 = _degToRad(a.latitude);
    final la2 = _degToRad(b.latitude);

    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(la1) * math.cos(la2) * math.sin(dLng / 2) * math.sin(dLng / 2);

    return 2 * r * math.asin(math.min(1, math.sqrt(h)));
  }

  double _degToRad(double deg) => deg * (math.pi / 180);

  // ---------------- summary (kept) ----------------
  Widget _buildSummaryHeader(List<Map<String, dynamic>> runs) {
    final stats = _calculateStatsFromRuns(runs);
    final records = _getPersonalRecords(runs);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.blue.shade400, Colors.blue.shade600]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(child: _buildStatWhite("Distance", "${stats['totalKm'].toStringAsFixed(1)} km")),
                Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.3)),
                Expanded(child: _buildStatWhite("Time", stats['totalTime'])),
                Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.3)),
                Expanded(child: _buildStatWhite("Avg Pace", stats['avgPace'])),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard("Avg HR", "${stats['avgBpm']}", Icons.favorite, Colors.red)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard("Streak", "${stats['streak']}", Icons.local_fire_department, Colors.orange)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard("Sessions", "${stats['totalRuns']}", Icons.check_circle, Colors.green)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard("Calories", "${stats['totalCalories']}", Icons.whatshot, Colors.deepOrange)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildRecordCard(
                  "Top Pace",
                  records['bestPace'] ?? '--:--',
                  records['bestPaceDate'] ?? '',
                  Icons.flash_on,
                  Colors.amber,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRecordCard(
                  "Longest Distance",
                  records['longestDistance'] ?? '-- km',
                  records['longestDate'] ?? '',
                  Icons.star,
                  Colors.purple,
                ),
              ),
            ],
          ),
          // Badges Section
          _buildBadgesSection(),
        ],
      ),
    );
  }

  Widget _buildBadgesSection() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();

    return StreamBuilder<List<RunnerBadge>>(
      stream: BadgeService().streamUserBadges(userId),
      builder: (context, snapshot) {
        final badges = snapshot.data ?? [];
        if (badges.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.emoji_events, size: 16, color: Colors.amber),
                SizedBox(width: 8),
                Text(
                  "BADGES",
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            BadgesDisplay(badges: badges, showEmpty: false),
          ],
        );
      },
    );
  }

  Map<String, dynamic> _calculateStatsFromRuns(List<Map<String, dynamic>> runs) {
    if (runs.isEmpty) {
      return {
        'totalKm': 0.0,
        'totalTime': '0:00',
        'avgPace': '0:00',
        'avgBpm': 0,
        'streak': 0,
        'totalRuns': 0,
        'totalCalories': 0,
      };
    }

    double totalKm = 0.0;
    int totalSeconds = 0;
    int totalBpm = 0;
    int totalCalories = 0;
    int bpmCount = 0;

    for (final run in runs) {
      final distVal = run['distance'] ?? 0.0;
      totalKm += (distVal is num) ? distVal.toDouble() : 0.0;

      final durVal = run['durationSeconds'] ?? 0;
      totalSeconds += (durVal is num) ? durVal.toInt() : 0;

      final calVal = run['calories'] ?? 0;
      totalCalories += (calVal is num) ? calVal.toInt() : 0;

      final bpm = run['avgBpm'] ?? run['bpm'];
      if (bpm != null && bpm is int && bpm > 0) {
        totalBpm += bpm;
        bpmCount++;
      }
    }

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final totalTime = hours > 0
        ? "$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}"
        : "$minutes:${seconds.toString().padLeft(2, '0')}";

    String avgPace = '0:00';
    if (totalKm > 0 && totalSeconds > 0) {
      final avgPaceSeconds = totalSeconds / totalKm;
      final paceMinutes = avgPaceSeconds ~/ 60;
      final paceSeconds = (avgPaceSeconds % 60).round();
      avgPace = "$paceMinutes:${paceSeconds.toString().padLeft(2, '0')}";
    }

    final avgBpm = bpmCount > 0 ? (totalBpm / bpmCount).round() : 0;

    final now = DateTime.now();
    int streak = 0;

    final sortedRuns = List<Map<String, dynamic>>.from(runs)
      ..sort((a, b) => _parseDate(b['date']).compareTo(_parseDate(a['date'])));

    for (int i = 0; i < sortedRuns.length; i++) {
      final runDate = _parseDate(sortedRuns[i]['date']);
      final daysDiff = now.difference(runDate).inDays;
      if (daysDiff <= i + 1) {
        streak = i + 1;
      } else {
        break;
      }
    }

    return {
      'totalKm': totalKm,
      'totalTime': totalTime,
      'avgPace': avgPace,
      'avgBpm': avgBpm,
      'streak': streak,
      'totalRuns': runs.length,
      'totalCalories': totalCalories,
    };
  }

  Map<String, String> _getPersonalRecords(List<Map<String, dynamic>> runs) {
    if (runs.isEmpty) {
      return {'bestPace': '--:--', 'bestPaceDate': '', 'longestDistance': '-- km', 'longestDate': ''};
    }

    Map<String, dynamic>? bestPaceRun;
    double bestPaceValue = double.infinity;

    for (final run in runs) {
      final paceStr = run['pace'] as String?;
      if (paceStr != null) {
        final parts = paceStr.split(':');
        if (parts.length == 2) {
          final p0 = int.tryParse(parts[0]);
          final p1 = int.tryParse(parts[1]);
          final paceSeconds = (p0 != null && p1 != null) ? p0 * 60 + p1 : 0;
          if (paceSeconds < bestPaceValue && paceSeconds > 0) {
            bestPaceValue = paceSeconds.toDouble();
            bestPaceRun = run;
          }
        }
      }
    }

    Map<String, dynamic>? longestRun;
    double longestDistance = 0.0;

    for (final run in runs) {
      final distance = (run['distance'] ?? 0.0);
      final dist = (distance is num) ? distance.toDouble() : 0.0;
      if (dist > longestDistance) {
        longestDistance = dist;
        longestRun = run;
      }
    }

    return {
      'bestPace': bestPaceRun?['pace'] ?? '--:--',
      'bestPaceDate': bestPaceRun != null ? DateFormat('MMM d').format(_parseDate(bestPaceRun['date'])) : '',
      'longestDistance': longestDistance > 0 ? '${longestDistance.toStringAsFixed(1)} km' : '-- km',
      'longestDate': longestRun != null ? DateFormat('MMM d').format(_parseDate(longestRun['date'])) : '',
    };
  }

  // ---------------- cards ----------------
  Widget _buildRunCard(BuildContext context, Map<String, dynamic> run) {
    final date = _parseDate(run['date']);

    final durationSecondsVal = run['durationSeconds'] ?? 0;
    final durationSeconds = (durationSecondsVal is num) ? durationSecondsVal.toInt() : 0;

    final distanceVal = run['distance'] ?? 0.0;
    final distance = (distanceVal is num) ? distanceVal.toDouble() : 0.0;

    final startTime = DateFormat('HH:mm').format(date);
    final endTime = DateFormat('HH:mm').format(date.add(Duration(seconds: durationSeconds)));

    final pace = run['pace'] ?? "0:00";

    final caloriesVal = run['calories'] ?? 0;
    final calories = (caloriesVal is num) ? caloriesVal.toInt() : 0;

    final avgBpmRaw = run['avgBpm'] ?? run['bpm'] ?? 0;
    final avgBpm = (avgBpmRaw is num) ? avgBpmRaw.toInt() : 0;

    final isTraining = _isTrainingRun(run);
    final isProRun = !isTraining && (run['planTitle'] != "Free Run");
    final isExternal = run['isExternal'] == true;
    final externalSource = run['source']?.toString() ?? '';

    final status = _completedFlag(run);
    final weekDayLabel = _weekDayLabel(run);
    final statusLabel = status == null ? null : (status ? "Completed" : "In Progress");

    // We still keep mapImageUrl for non-web fallback or legacy, but on Web we prefer route
    final mapImageUrl = (run['mapImageUrl'] ?? '').toString();
    final hasMapImage = mapImageUrl.isNotEmpty;

    final raw = _extractLatLngList(run['routePoints']);
    final routePoints = _sanitizeAndDownsample(raw);
    final hasRoute = routePoints.length >= 2;

    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    final timeString = "$minutes:${seconds.toString().padLeft(2, '0')}";

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => RunDetailScreen(runData: run)));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isExternal
                            ? [Colors.purple.shade400, Colors.purple.shade600]
                            : isTraining
                                ? [Colors.green.shade400, Colors.green.shade700]
                                : isProRun
                                    ? [Colors.blue.shade400, Colors.blue.shade600]
                                    : [Colors.grey.shade700, Colors.grey.shade900],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          date.day.toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(DateFormat('MMM').format(date), style: const TextStyle(color: Colors.white, fontSize: 10)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "${DateFormat('EEE').format(date)} • $startTime–$endTime",
                              style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            if (isExternal)
                              _badge(label: _getSourceLabel(externalSource), icon: Icons.cloud_download, colors: [Colors.purple.shade400, Colors.purple.shade600])
                            else if (isTraining)
                              _badge(label: "SESSION", icon: Icons.fitness_center, colors: [Colors.green.shade400, Colors.green.shade700])
                            else if (isProRun)
                              _badge(label: "PRO", icon: Icons.auto_awesome, colors: [Colors.blue.shade400, Colors.blue.shade600]),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${distance.toStringAsFixed(1)} km",
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),

                        // ✅ FIX: correct OR condition (was broken by newline in your file) [1](https://necms-my.sharepoint.com/personal/hanumaiah_ta_nec_com_sg/Documents/Microsoft%20Copilot%20Chat%20Files/run_history_screen.dart)
                        if (isTraining && (weekDayLabel.isNotEmpty || statusLabel != null)) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (weekDayLabel.isNotEmpty) _chip(text: weekDayLabel, icon: Icons.calendar_today, color: Colors.green),
                              if (statusLabel != null)
                                _chip(
                                  text: statusLabel,
                                  icon: statusLabel == "Completed" ? Icons.check_circle : Icons.timelapse,
                                  color: statusLabel == "Completed" ? Colors.green : Colors.orange,
                                ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _historyStat("Time", timeString, Icons.timer_outlined, Colors.blue),
                            const SizedBox(width: 15),
                            _historyStat("Pace", "$pace /km", Icons.speed, Colors.green),
                            const SizedBox(width: 15),
                            _historyStat("Cals", "$calories", Icons.whatshot, Colors.orange),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.favorite, size: 14, color: Colors.red.shade400),
                            const SizedBox(width: 4),
                            Text(
                              "Avg HR: $avgBpm",
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ],
              ),
            ),

            // ✅ ALWAYS prefer route on Web when route exists
            if (hasRoute)
              _buildRoutePreviewSmart(routePoints)
            else if (hasMapImage)
              _buildNetworkPreview(mapImageUrl)
            else
              _noRoutePlaceholder(),
          ],
        ),
      ),
    );
  }

  // Web: Static map image (tiles); Mobile: GoogleMap (original behavior)
  // Interactive map for all platforms
  Widget _buildRoutePreviewSmart(List<LatLng> routePoints) {
    return _buildMiniRouteMap(routePoints);
  }

  Widget _noRoutePlaceholder() {
    return Container(
      height: 120,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, color: Colors.grey.shade300, size: 32),
            const SizedBox(height: 8),
            Text('No map preview', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // ---------------- UI atoms ----------------
  Widget _badge({required String label, required IconData icon, required List<Color> colors}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 10, color: Colors.white),
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _chip({required String text, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildNetworkPreview(String url) {
    return Container(
      height: 120,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(url, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => _noRoutePlaceholder()),
    );
  }

  Widget _historyStat(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
            Text(label, style: TextStyle(fontSize: 8, color: Colors.grey.shade600)),
          ],
        ),
      ],
    );
  }

  // ---------------- share ----------------
  void _shareHistory(BuildContext context, List<Map<String, dynamic>> runs) {
    final stats = _calculateStatsFromRuns(runs);
    final message = """
🏃 Session Summary
📏 Distance: ${stats['totalKm'].toStringAsFixed(1)} km
⏱️ Time: ${stats['totalTime']}
🔥 Sessions: ${stats['totalRuns']}
⚡ Streak: ${stats['streak']} days
Built with MajuRun 💪
""";
    Share.share(message);
  }

  // ---------------- existing mini map (mobile only) ----------------
  Widget _buildMiniRouteMap(List<LatLng> routePoints) {
    final bounds = _calculateBounds(routePoints);
    final initialPosition = CameraPosition(
      target: LatLng(
        (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
        (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
      ),
      zoom: 13,
    );

    return Container(
      height: 120,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: GoogleMap(
        initialCameraPosition: initialPosition,
        polylines: {
          Polyline(
            polylineId: const PolylineId('route'),
            points: routePoints,
            color: const Color(0xFF4285F4),
            width: 5,
          ),
        },
        markers: {
          Marker(
            markerId: const MarkerId('start'),
            position: routePoints.first,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          ),
          Marker(
            markerId: const MarkerId('end'),
            position: routePoints.last,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
        },
        zoomControlsEnabled: true,
        zoomGesturesEnabled: true,
        scrollGesturesEnabled: false,
        mapToolbarEnabled: false,
        rotateGesturesEnabled: false,
        tiltGesturesEnabled: false,
        mapType: MapType.normal,
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        onMapCreated: (GoogleMapController controller) {
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted) controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
          });
        },
      ),
    );
  }

  LatLngBounds _calculateBounds(List<LatLng> points) {
    double south = points.first.latitude;
    double north = points.first.latitude;
    double west = points.first.longitude;
    double east = points.first.longitude;

    for (final point in points) {
      if (point.latitude < south) south = point.latitude;
      if (point.latitude > north) north = point.latitude;
      if (point.longitude < west) west = point.longitude;
      if (point.longitude > east) east = point.longitude;
    }
    return LatLngBounds(southwest: LatLng(south, west), northeast: LatLng(north, east));
  }

  // ---------------- stat widgets (kept) ----------------
  Widget _buildStatWhite(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildRecordCard(String label, String value, String date, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                if (date.isNotEmpty) Text(date, style: const TextStyle(fontSize: 8, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}