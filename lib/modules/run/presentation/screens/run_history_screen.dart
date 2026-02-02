import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:majurun/modules/run/controllers/run_controller.dart';
import 'package:majurun/modules/run/presentation/screens/run_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RunHistoryScreen extends StatefulWidget {
  final VoidCallback onBack;
  const RunHistoryScreen({super.key, required this.onBack});

  @override
  State<RunHistoryScreen> createState() => _RunHistoryScreenState();
}

class _RunHistoryScreenState extends State<RunHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Consumer<RunController>(
        builder: (context, controller, child) {
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: controller.getRunHistory(),
            builder: (context, snapshot) {
              final runs = snapshot.data ?? [];

              return CustomScrollView(
                slivers: [
                  // App Bar
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
                        onPressed: () => _shareHistory(context),
                      ),
                    ],
                  ),

                  // Summary Header
                  SliverToBoxAdapter(
                    child: Container(
                      color: Colors.white,
                      child: _buildSummaryHeader(controller),
                    ),
                  ),

                  // Section divider
                  SliverToBoxAdapter(
                    child: Container(
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
                  ),

                  // Content based on state
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
                              "Error loading history",
                              style: TextStyle(color: Colors.grey.shade600),
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
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildRunCard(context, runs[index]),
                            );
                          },
                          childCount: runs.length,
                        ),
                      ),
                    ),

                  // Bottom padding
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 20),
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
    // Use Google Maps Static API for actual map tiles
    final staticMapUrl = _buildStaticMapUrl(routePoints);

    return Container(
      height: 120,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        staticMapUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 120,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
              strokeWidth: 2,
              color: Colors.blue,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade100,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_outlined, color: Colors.grey.shade400, size: 32),
                  const SizedBox(height: 4),
                  Text(
                    'Map unavailable',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _buildStaticMapUrl(List<LatLng> routePoints) {
    const apiKey = 'AIzaSyA9sCbH0hZRUO2wxk9IClyZC9DNcHCZBNY';

    // Calculate center
    double minLat = routePoints.first.latitude;
    double maxLat = routePoints.first.latitude;
    double minLng = routePoints.first.longitude;
    double maxLng = routePoints.first.longitude;

    for (final point in routePoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;

    // Build encoded polyline
    final encodedPath = _encodePolyline(routePoints);

    final url = StringBuffer('https://maps.googleapis.com/maps/api/staticmap?');
    url.write('center=$centerLat,$centerLng');
    url.write('&size=400x150');
    url.write('&scale=2');
    url.write('&maptype=roadmap');
    url.write('&path=color:0x4285F4FF|weight:3|enc:$encodedPath');
    url.write('&markers=color:green|size:tiny|${routePoints.first.latitude},${routePoints.first.longitude}');
    url.write('&markers=color:red|size:tiny|${routePoints.last.latitude},${routePoints.last.longitude}');
    url.write('&key=$apiKey');

    return url.toString();
  }

  String _encodePolyline(List<LatLng> points) {
    final encoded = StringBuffer();
    int prevLat = 0;
    int prevLng = 0;

    for (final point in points) {
      final lat = (point.latitude * 1e5).round();
      final lng = (point.longitude * 1e5).round();

      _encodeValue(lat - prevLat, encoded);
      _encodeValue(lng - prevLng, encoded);

      prevLat = lat;
      prevLng = lng;
    }

    return encoded.toString();
  }

  void _encodeValue(int value, StringBuffer encoded) {
    int v = value < 0 ? ~(value << 1) : (value << 1);

    while (v >= 0x20) {
      encoded.writeCharCode((0x20 | (v & 0x1f)) + 63);
      v >>= 5;
    }
    encoded.writeCharCode(v + 63);
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
