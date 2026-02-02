import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;

class RunDetailScreen extends StatefulWidget {
  final Map<String, dynamic> runData;
  
  const RunDetailScreen({super.key, required this.runData});

  @override
  State<RunDetailScreen> createState() => _RunDetailScreenState();
}

class _RunDetailScreenState extends State<RunDetailScreen> {
  String _mapVisualization = 'pace'; // 'pace' or 'elevation'
  String _splitDistance = '1km'; // '1km', '2km', '5km'
  
  @override
  Widget build(BuildContext context) {
    final date = widget.runData['date'] as DateTime;
    final distance = widget.runData['distance']?.toStringAsFixed(2) ?? "0.0";
    final durationSeconds = widget.runData['durationSeconds'] ?? 0;
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;
    final timeString = hours > 0 
        ? "$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}"
        : "$minutes:${seconds.toString().padLeft(2, '0')}";
    final pace = widget.runData['pace'] ?? "0:00";
    final calories = widget.runData['calories'] ?? 0;
    final avgBpm = widget.runData['avgBpm'] ?? widget.runData['bpm'] ?? 0;
    
    // Try different possible keys for route points
    List<LatLng>? routePoints;
    
    if (widget.runData.containsKey('routePoints') && widget.runData['routePoints'] != null) {
      routePoints = widget.runData['routePoints'] as List<LatLng>?;
    } else if (widget.runData.containsKey('route') && widget.runData['route'] != null) {
      routePoints = widget.runData['route'] as List<LatLng>?;
    } else if (widget.runData.containsKey('path') && widget.runData['path'] != null) {
      routePoints = widget.runData['path'] as List<LatLng>?;
    }


    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
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
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.black),
            onPressed: () => _shareRun(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date and Time Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE, MMM d, yyyy').format(date),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('h:mm a').format(date),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            // Main Stats Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0A0A0A),
                    Color(0xFF1A1A1A),
                    Color(0xFF00FF87),
                  ],
                  stops: [0.0, 0.7, 1.0],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00FF87).withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMainStat("DISTANCE", "$distance km"),
                      _buildMainStat("TIME", timeString),
                      _buildMainStat("PACE", "$pace /km"),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSecondaryStat(Icons.favorite, "AVG BPM", "$avgBpm"),
                      _buildSecondaryStat(Icons.local_fire_department, "CALORIES", "$calories"),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Route Map with Visualization Toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "ROUTE MAP",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      if (routePoints != null && routePoints.isNotEmpty)
                        Row(
                          children: [
                            _buildMapToggle("Pace", "pace"),
                            const SizedBox(width: 8),
                            _buildMapToggle("Elevation", "elevation"),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  if (routePoints != null && routePoints.isNotEmpty)
                    _buildRouteMap(routePoints)
                  else
                    Container(
                      height: 300,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.map_outlined, color: Colors.grey.shade400, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'No route data available',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (routePoints != null && routePoints.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildMapLegend(),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Splits Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "SPLITS",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      _buildSplitSelector(),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _buildSplitsList(),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildMainStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryStat(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF00FF87), size: 16),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMapToggle(String label, String value) {
    final isSelected = _mapVisualization == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _mapVisualization = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildRouteMap(List<LatLng> routePoints) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CustomPaint(
          painter: ColoredRoutePainter(
            points: routePoints,
            visualizationType: _mapVisualization,
          ),
          child: Container(),
        ),
      ),
    );
  }

  Widget _buildMapLegend() {
    if (_mapVisualization == 'pace') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem(Colors.green, "Faster Pace"),
          const SizedBox(width: 20),
          _buildLegendItem(Colors.red, "Slower Pace"),
        ],
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem(Colors.blue.shade800, "Higher Elevation"),
          const SizedBox(width: 20),
          _buildLegendItem(Colors.blue.shade200, "Lower Elevation"),
        ],
      );
    }
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildSplitSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSplitOption("1km"),
          _buildSplitOption("2km"),
          _buildSplitOption("5km"),
        ],
      ),
    );
  }

  Widget _buildSplitOption(String distance) {
    final isSelected = _splitDistance == distance;
    return GestureDetector(
      onTap: () {
        setState(() {
          _splitDistance = distance;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          distance.toUpperCase(),
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSplitsList() {
    final distance = widget.runData['distance'] ?? 0.0;
    final splitKm = _splitDistance == '1km' ? 1.0 : _splitDistance == '2km' ? 2.0 : 5.0;
    final numSplits = (distance / splitKm).ceil();
    
    return Column(
      children: List.generate(numSplits, (index) {
        final splitNum = index + 1;
        final actualDistance = (splitNum * splitKm > distance) 
            ? (distance - (index * splitKm)) 
            : splitKm;
        
        // Generate sample pace and elevation data
        final basePace = 5 + (index % 3) * 0.5; // minutes per km
        final paceMinutes = basePace.floor();
        final paceSeconds = ((basePace - paceMinutes) * 60).floor();
        final paceString = "$paceMinutes:${paceSeconds.toString().padLeft(2, '0')}";
        
        final elevationChange = (index % 5) * 10 - 20; // -20 to +30 meters
        final elevationColor = elevationChange > 0 
            ? Colors.orange.shade700 
            : elevationChange < 0 
                ? Colors.blue.shade700 
                : Colors.grey;
        
        // Pace color: faster = green, slower = red
        final paceColor = basePace < 5.5 ? Colors.green : Colors.red;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    "$splitNum",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${actualDistance.toStringAsFixed(2)} km",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.speed, size: 12, color: paceColor),
                        const SizedBox(width: 4),
                        Text(
                          paceString,
                          style: TextStyle(
                            fontSize: 12,
                            color: paceColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.terrain, size: 12, color: elevationColor),
                        const SizedBox(width: 4),
                        Text(
                          "${elevationChange > 0 ? '+' : ''}${elevationChange}m",
                          style: TextStyle(
                            fontSize: 12,
                            color: elevationColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  void _shareRun() {
    final date = widget.runData['date'] as DateTime;
    final distance = widget.runData['distance']?.toStringAsFixed(2) ?? "0.0";
    final durationSeconds = widget.runData['durationSeconds'] ?? 0;
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;
    final timeString = hours > 0 
        ? "$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}"
        : "$minutes:${seconds.toString().padLeft(2, '0')}";
    final pace = widget.runData['pace'] ?? "0:00";
    final calories = widget.runData['calories'] ?? 0;

    final shareText = '''
🏃 My MajuRun - ${DateFormat('MMM d, yyyy').format(date)} 🏃

📍 Distance: $distance km
⏱️ Time: $timeString
⚡ Pace: $pace /km
🔥 Calories: $calories

Keep running! 🚀
''';
    
    Share.share(shareText);
  }
}

// Custom painter for colored route visualization
class ColoredRoutePainter extends CustomPainter {
  final List<LatLng> points;
  final String visualizationType;

  ColoredRoutePainter({
    required this.points,
    required this.visualizationType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // Find the bounds of the coordinates
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    // Map coordinates to the widget size
    double latRange = maxLat - minLat;
    double lngRange = maxLng - minLng;
    
    // Maintain aspect ratio
    double range = latRange > lngRange ? latRange : lngRange;
    if (range == 0) range = 1;

    final paint = Paint()
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Draw segments with different colors
    for (int i = 0; i < points.length - 1; i++) {
      final progress = i / points.length;
      
      // Determine color based on visualization type
      if (visualizationType == 'pace') {
        // Pace visualization: green (fast) to red (slow)
        final paceValue = math.sin(progress * math.pi * 3) * 0.5 + 0.5;
        paint.color = Color.lerp(Colors.green, Colors.red, paceValue)!;
      } else {
        // Elevation visualization: light blue (low) to dark blue (high)
        final elevationValue = math.sin(progress * math.pi * 2) * 0.5 + 0.5;
        paint.color = Color.lerp(Colors.blue.shade200, Colors.blue.shade800, elevationValue)!;
      }

      // Scale points
      double x1 = (points[i].longitude - minLng) / range * size.width * 0.9 + size.width * 0.05;
      double y1 = (maxLat - points[i].latitude) / range * size.height * 0.9 + size.height * 0.05;
      double x2 = (points[i + 1].longitude - minLng) / range * size.width * 0.9 + size.width * 0.05;
      double y2 = (maxLat - points[i + 1].latitude) / range * size.height * 0.9 + size.height * 0.05;

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }

    // Draw start and end markers
    final markerPaint = Paint()..style = PaintingStyle.fill;
    
    // Start marker (green)
    double startX = (points.first.longitude - minLng) / range * size.width * 0.9 + size.width * 0.05;
    double startY = (maxLat - points.first.latitude) / range * size.height * 0.9 + size.height * 0.05;
    markerPaint.color = Colors.green;
    canvas.drawCircle(Offset(startX, startY), 10, markerPaint);
    markerPaint.color = Colors.white;
    canvas.drawCircle(Offset(startX, startY), 5, markerPaint);
    
    // End marker (red)
    double endX = (points.last.longitude - minLng) / range * size.width * 0.9 + size.width * 0.05;
    double endY = (maxLat - points.last.latitude) / range * size.height * 0.9 + size.height * 0.05;
    markerPaint.color = Colors.red;
    canvas.drawCircle(Offset(endX, endY), 10, markerPaint);
    markerPaint.color = Colors.white;
    canvas.drawCircle(Offset(endX, endY), 5, markerPaint);
  }

  @override
  bool shouldRepaint(ColoredRoutePainter oldDelegate) {
    return oldDelegate.visualizationType != visualizationType ||
           oldDelegate.points != points;
  }
}