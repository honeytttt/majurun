import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:majurun/modules/run/controllers/run_controller.dart';
import 'package:majurun/modules/run/presentation/screens/run_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;

class RunHistoryScreen extends StatefulWidget {
  final VoidCallback onBack;
  const RunHistoryScreen({super.key, required this.onBack});

  @override
  State<RunHistoryScreen> createState() => _RunHistoryScreenState();
}

class _RunHistoryScreenState extends State<RunHistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate header opacity based on scroll
    final headerOpacity = (1 - (_scrollOffset / 200)).clamp(0.0, 1.0);
    final isCollapsed = _scrollOffset > 100;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: AnimatedOpacity(
          opacity: isCollapsed ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: const Row(
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
        ),
        backgroundColor: Colors.white,
        elevation: isCollapsed ? 2 : 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: widget.onBack,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.black),
            onPressed: () => _shareHistory(context),
          ),
        ],
      ),
      body: Consumer<RunController>(
        builder: (context, controller, child) {
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: controller.getRunHistory(),
            builder: (context, snapshot) {
              final runs = snapshot.data ?? [];

              return ListView(
                controller: _scrollController,
                padding: EdgeInsets.zero,
                children: [
                  // Animated header that fades out on scroll
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: headerOpacity > 0 ? null : 0,
                    child: Opacity(
                      opacity: headerOpacity,
                      child: Container(
                        color: Colors.white,
                        child: Column(
                          children: [
                            // Title (only when not collapsed)
                            if (headerOpacity > 0.5)
                              const Padding(
                                padding: EdgeInsets.only(top: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "MY ",
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                        fontSize: 18,
                                      ),
                                    ),
                                    Icon(Icons.directions_run, color: Colors.black, size: 20),
                                    Text(
                                      " HISTORY",
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            // Stats header
                            _buildSummaryHeader(controller),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Section divider
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: const Row(
                      children: [
                        Icon(Icons.history, size: 16, color: Colors.grey),
                        SizedBox(width: 8),
                        Text(
                          "RECENT ACTIVITIES",
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

                  // Run cards
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const SizedBox(
                      height: 400,
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.black),
                      ),
                    )
                  else if (snapshot.hasError)
                    SizedBox(
                      height: 400,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              "Error loading history",
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (runs.isEmpty)
                    const SizedBox(
                      height: 400,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.directions_run, size: 48, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              "No runs yet",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Start your first run!",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: runs.map((run) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildRunCard(context, run),
                        )).toList(),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSummaryHeader(RunController controller) {
    final records = _getPersonalRecords();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // First row with gradient background
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
                Expanded(child: _buildStatWhite("Total KM", "${controller.historyDistance.toStringAsFixed(1)} km")),
                Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.3)),
                Expanded(child: _buildStatWhite("Total Time", controller.totalHistoryTimeStr)),
                Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.3)),
                Expanded(child: _buildStatWhite("Avg Pace", _calculateAveragePace(controller))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Second row
          Row(
            children: [
              Expanded(child: _buildStatCard("Avg BPM", "145", Icons.favorite, Colors.red)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard("Streak", "${controller.runStreak}", Icons.local_fire_department, Colors.orange)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard("Runs", "${controller.totalRuns}", Icons.check_circle, Colors.green)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard("Cal", "2.4k", Icons.whatshot, Colors.deepOrange)),
            ],
          ),
          const SizedBox(height: 12),
          // Personal records
          Row(
            children: [
              Expanded(
                child: _buildRecordCard(
                  "Best Pace",
                  records['bestPace'] ?? '--:--',
                  records['bestPaceDate'] ?? '',
                  Icons.flash_on,
                  Colors.amber,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRecordCard(
                  "Longest Run",
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

  Widget _buildStatWhite(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.9),
            fontWeight: FontWeight.w600,
          ),
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
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: Colors.grey,
            ),
          ),
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
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    color: color.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (date.isNotEmpty)
                  Text(
                    date,
                    style: const TextStyle(
                      fontSize: 8,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, String> _getPersonalRecords() {
    return {
      'bestPace': '4:32',
      'bestPaceDate': 'Jan 15',
      'longestDistance': '21.1 km',
      'longestDate': 'Dec 20',
    };
  }

  String _calculateAveragePace(RunController controller) {
    if (controller.totalRuns == 0) return "0:00";
    return "5:30";
  }

  void _shareHistory(BuildContext context) {
    final controller = Provider.of<RunController>(context, listen: false);
    final message = """
🏃 My Running Stats

📊 Total Distance: ${controller.historyDistance.toStringAsFixed(1)} km
⏱️ Total Time: ${controller.totalHistoryTimeStr}
🔥 Total Runs: ${controller.totalRuns}
⚡ Streak: ${controller.runStreak} days

Keep running with MajuRun! 💪
""";
    Share.share(message);
  }

  Widget _buildRunCard(BuildContext context, Map<String, dynamic> run) {
    final date = run['date'] as DateTime;
    final distance = run['distance']?.toStringAsFixed(1) ?? "0.0";
    final durationSeconds = run['durationSeconds'] ?? 0;
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    final timeString = "$minutes:${seconds.toString().padLeft(2, '0')}";
    final pace = run['pace'] ?? "8:00";
    final calories = run['calories'] ?? 0;
    final avgBpm = run['avgBpm'] ?? run['bpm'] ?? 145;
    final isProRun = run['planTitle'] != "Free Run";
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
    } catch (e) {
      debugPrint('⚠️ Error parsing routePoints: $e');
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RunDetailScreen(runData: run),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
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
                        colors: isProRun 
                            ? [Colors.blue.shade400, Colors.blue.shade600]
                            : [Colors.grey.shade700, Colors.grey.shade900],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: (isProRun ? Colors.blue : Colors.grey).withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          dayOfMonth.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          month,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
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
                              "$dayOfWeek at $startTime - $endTime",
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            if (isProRun)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.blue.shade400, Colors.blue.shade600],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.auto_awesome, size: 10, color: Colors.white),
                                    SizedBox(width: 3),
                                    Text(
                                      "PRO",
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "$distance km",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _historyStat("Time", timeString, Icons.timer_outlined, Colors.blue),
                            const SizedBox(width: 15),
                            _historyStat("Pace", "$pace /km", Icons.speed, Colors.green),
                            const SizedBox(width: 15),
                            _historyStat("Cal", "$calories", Icons.whatshot, Colors.orange),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.favorite, size: 14, color: Colors.red.shade400),
                            const SizedBox(width: 4),
                            Text(
                              "Avg BPM: $avgBpm",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
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
            if (routePoints != null && routePoints.isNotEmpty)
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
                      Text(
                        'No route data',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 11,
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

  Widget _historyStat(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 8, color: Colors.grey.shade600),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniRouteMap(List<LatLng> routePoints) {
    return Container(
      height: 120,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: MiniRoutePainter(routePoints: routePoints),
        child: Container(),
      ),
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

class MiniRoutePainter extends CustomPainter {
  final List<LatLng> routePoints;
  MiniRoutePainter({required this.routePoints});

  @override
  void paint(Canvas canvas, Size size) {
    if (routePoints.length < 2) return;

    double minLat = routePoints.first.latitude;
    double maxLat = routePoints.first.latitude;
    double minLng = routePoints.first.longitude;
    double maxLng = routePoints.first.longitude;

    for (final point in routePoints) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    final latRange = maxLat - minLat;
    final lngRange = maxLng - minLng;
    if (latRange == 0 || lngRange == 0) return;

    const padding = 0.05;
    final paddedLatRange = latRange * (1 + 2 * padding);
    final paddedLngRange = lngRange * (1 + 2 * padding);

    Offset mapToCanvas(LatLng point) {
      final x = ((point.longitude - minLng + lngRange * padding) / paddedLngRange) * size.width;
      final y = size.height - ((point.latitude - minLat + latRange * padding) / paddedLatRange) * size.height;
      return Offset(x, y);
    }

    for (int i = 0; i < routePoints.length - 1; i++) {
      final start = mapToCanvas(routePoints[i]);
      final end = mapToCanvas(routePoints[i + 1]);
      final progress = i / (routePoints.length - 1);
      final paceValue = 0.5 + 0.3 * math.sin(progress * math.pi * 3);
      final color = Color.lerp(Colors.green, Colors.red, paceValue)!;

      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = color
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }

    final startPos = mapToCanvas(routePoints.first);
    canvas.drawCircle(startPos, 6, Paint()..color = Colors.green);
    canvas.drawCircle(startPos, 3, Paint()..color = Colors.white);

    final endPos = mapToCanvas(routePoints.last);
    canvas.drawCircle(endPos, 6, Paint()..color = Colors.red);
    canvas.drawCircle(endPos, 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(MiniRoutePainter oldDelegate) => oldDelegate.routePoints != routePoints;
}