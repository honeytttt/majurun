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
                        onPressed: () => _shareHistory(context, runs),
                      ),
                    ],
                  ),

                  // Summary Header
                  SliverToBoxAdapter(
                    child: Container(
                      color: Colors.white,
                      child: _buildSummaryHeader(runs),
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

  Widget _buildSummaryHeader(List<Map<String, dynamic>> runs) {
    final stats = _calculateStatsFromRuns(runs);
    final records = _getPersonalRecords(runs);

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
                Expanded(child: _buildStatWhite("Total KM", "${stats['totalKm'].toStringAsFixed(1)} km")),
                Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.3)),
                Expanded(child: _buildStatWhite("Total Time", stats['totalTime'])),
                Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.3)),
                Expanded(child: _buildStatWhite("Avg Pace", stats['avgPace'])),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Second row
          Row(
            children: [
              Expanded(child: _buildStatCard("Avg BPM", "${stats['avgBpm']}", Icons.favorite, Colors.red)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard("Streak", "${stats['streak']}", Icons.local_fire_department, Colors.orange)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard("Runs", "${stats['totalRuns']}", Icons.check_circle, Colors.green)),
              const SizedBox(width: 8),
              Expanded(child: _buildStatCard("Cal", "${stats['totalCalories']}", Icons.whatshot, Colors.deepOrange)),
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
      totalKm += (run['distance'] ?? 0.0) as double;
      totalSeconds += (run['durationSeconds'] ?? 0) as int;
      totalCalories += (run['calories'] ?? 0) as int;
      
      final bpm = run['avgBpm'] ?? run['bpm'];
      if (bpm != null && bpm > 0) {
        totalBpm += bpm as int;
        bpmCount++;
      }
    }

    // Format total time
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    
    String totalTime;
    if (hours > 0) {
      totalTime = "$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    } else {
      totalTime = "$minutes:${seconds.toString().padLeft(2, '0')}";
    }

    // Calculate average pace
    String avgPace = '0:00';
    if (totalKm > 0 && totalSeconds > 0) {
      final avgPaceSeconds = totalSeconds / totalKm;
      final paceMinutes = avgPaceSeconds ~/ 60;
      final paceSeconds = (avgPaceSeconds % 60).round();
      avgPace = "$paceMinutes:${paceSeconds.toString().padLeft(2, '0')}";
    }

    // Calculate average BPM
    int avgBpm = bpmCount > 0 ? (totalBpm / bpmCount).round() : 0;

    // Calculate streak
    final now = DateTime.now();
    int streak = 0;
    final sortedRuns = List<Map<String, dynamic>>.from(runs)
      ..sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    
    for (int i = 0; i < sortedRuns.length; i++) {
      final runDate = sortedRuns[i]['date'] as DateTime;
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

    // Find best pace (lowest pace value)
    Map<String, dynamic>? bestPaceRun;
    double bestPaceValue = double.infinity;
    
    for (final run in runs) {
      final paceStr = run['pace'] as String?;
      if (paceStr != null) {
        final parts = paceStr.split(':');
        if (parts.length == 2) {
          final paceSeconds = int.parse(parts[0]) * 60 + int.parse(parts[1]);
          if (paceSeconds < bestPaceValue && paceSeconds > 0) {
            bestPaceValue = paceSeconds.toDouble();
            bestPaceRun = run;
          }
        }
      }
    }

    // Find longest run
    Map<String, dynamic>? longestRun;
    double longestDistance = 0.0;
    
    for (final run in runs) {
      final distance = (run['distance'] ?? 0.0) as double;
      if (distance > longestDistance) {
        longestDistance = distance;
        longestRun = run;
      }
    }

    return {
      'bestPace': bestPaceRun?['pace'] ?? '--:--',
      'bestPaceDate': bestPaceRun != null ? DateFormat('MMM d').format(bestPaceRun['date'] as DateTime) : '',
      'longestDistance': longestDistance > 0 ? '${longestDistance.toStringAsFixed(1)} km' : '-- km',
      'longestDate': longestRun != null ? DateFormat('MMM d').format(longestRun['date'] as DateTime) : '',
    };
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

  void _shareHistory(BuildContext context, List<Map<String, dynamic>> runs) {
    final stats = _calculateStatsFromRuns(runs);
    final message = """
🏃 My Running Stats

📊 Total Distance: ${stats['totalKm'].toStringAsFixed(1)} km
⏱️ Total Time: ${stats['totalTime']}
🔥 Total Runs: ${stats['totalRuns']}
⚡ Streak: ${stats['streak']} days

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
              controller.animateCamera(
                CameraUpdate.newLatLngBounds(bounds, 60),
              );
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