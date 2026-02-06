import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:majurun/modules/run/controllers/run_controller.dart';
import 'package:majurun/modules/run/presentation/screens/run_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Safe Timestamp parsing

class RunHistoryScreen extends StatefulWidget {
  final VoidCallback onBack;
  const RunHistoryScreen({super.key, required this.onBack});

  @override
  State<RunHistoryScreen> createState() => _RunHistoryScreenState();
}

class _RunHistoryScreenState extends State<RunHistoryScreen> {
  Future<List<Map<String, dynamic>>>? _historyFuture;

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
                        child: Center(
                          child: CircularProgressIndicator(color: Colors.black),
                        ),
                      )
                    else if (snapshot.hasError)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 48),
                              const SizedBox(height: 16),
                              Text(
                                "Unable to load history",
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Pull to refresh",
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                              ),
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
                              Text(
                                "No sessions yet",
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Start your first session.",
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildRunCard(context, runs[index]),
                            ),
                            childCount: runs.length,
                          ),
                        ),
                      ),

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
    if (week != null && day != null) return "Week $week • Day $day";
    final weekDay = run['weekDay']?.toString();
    if (weekDay != null && weekDay.isNotEmpty) return weekDay.replaceAll(',', ' •');
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

  // -----------------------------
  // Summary + stats (kept)
  // -----------------------------
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
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
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
        ],
      ),
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

      totalSeconds += (run['durationSeconds'] ?? 0) as int;
      totalCalories += (run['calories'] ?? 0) as int;

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
      return {
        'bestPace': '--:--',
        'bestPaceDate': '',
        'longestDistance': '-- km',
        'longestDate': '',
      };
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

  Widget _buildStatWhite(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w600),
        ),
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

  Widget _buildRunCard(BuildContext context, Map<String, dynamic> run) {
    final date = _parseDate(run['date']);
    final distance = (run['distance'] is num) ? (run['distance'] as num).toDouble() : 0.0;
    final durationSeconds = run['durationSeconds'] ?? 0;

    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    final timeString = "$minutes:${seconds.toString().padLeft(2, '0')}";

    final pace = run['pace'] ?? "8:00";
    final calories = run['calories'] ?? 0;
    final avgBpm = run['avgBpm'] ?? run['bpm'] ?? 145;

    final isTraining = _isTrainingRun(run);
    final isProRun = !isTraining && (run['planTitle'] != "Free Run");
    final status = _completedFlag(run);

    final weekDayLabel = _weekDayLabel(run);
    final statusLabel = status == null ? null : (status ? "Completed" : "Partial");

    final dayOfMonth = date.day;
    final dayOfWeek = _getDayOfWeek(date.weekday);
    final month = _getMonth(date.month);

    final startTime = DateFormat('HH:mm').format(date);
    final endTime = DateFormat('HH:mm').format(date.add(Duration(seconds: durationSeconds)));

    List<LatLng>? routePoints;
    try {
      if (run.containsKey('routePoints') && run['routePoints'] != null) {
        final points = run['routePoints'];
        if (points is List<LatLng>) {
          routePoints = points;
        } else if (points is List) {
          routePoints = points.whereType<LatLng>().toList();
        }
      }
    } catch (_) {}

    final mapImageUrl = run['mapImageUrl']?.toString();
    final hasMapImage = mapImageUrl != null && mapImageUrl.isNotEmpty;

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => RunDetailScreen(runData: run)));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 2))],
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
                        colors: isTraining
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
                        Text(dayOfMonth.toString(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(month, style: const TextStyle(color: Colors.white, fontSize: 10)),
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
                            Text("$dayOfWeek • $startTime – $endTime",
                                style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            if (isTraining)
                              _badge(
                                label: "SESSION", // ✅ requested label
                                icon: Icons.fitness_center,
                                colors: [Colors.green.shade400, Colors.green.shade700],
                              )
                            else if (isProRun)
                              _badge(
                                label: "PRO",
                                icon: Icons.auto_awesome,
                                colors: [Colors.blue.shade400, Colors.blue.shade600],
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text("${distance.toStringAsFixed(1)} km",
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
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
                            Text("Avg HR: $avgBpm",
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
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
            if (hasMapImage)
              _buildNetworkPreview(mapImageUrl)
            else if (routePoints != null && routePoints.isNotEmpty)
              _buildMiniRouteMap(routePoints)
            else
              Container(
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
              ),
          ],
        ),
      ),
    );
  }

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
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade50,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, color: Colors.grey.shade300, size: 32),
                  const SizedBox(height: 8),
                  Text('Preview unavailable', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                ],
              ),
            ),
          );
        },
      ),
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

  // Mini map helpers (unchanged)
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
            patterns: [PatternItem.dash(20), PatternItem.gap(5)],
          ),
        },
        markers: {
          Marker(
            markerId: const MarkerId('start'),
            position: routePoints.first,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: const InfoWindow(title: 'Start'),
          ),
          Marker(
            markerId: const MarkerId('end'),
            position: routePoints.last,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: const InfoWindow(title: 'End'),
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
            if (mounted) {
              controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
            }
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

    return LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
  }

  String _getDayOfWeek(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  String _getMonth(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}