import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RunDetailScreen extends StatefulWidget {
  final Map<String, dynamic> runData;
  static const String _apiKey = 'AIzaSyA9sCbH0hZRUO2wxk9IClyZC9DNcHCZBNY';

  const RunDetailScreen({super.key, required this.runData});

  @override
  State<RunDetailScreen> createState() => _RunDetailScreenState();
}

class _RunDetailScreenState extends State<RunDetailScreen> {
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
      final points = widget.runData['routePoints'];
      if (points is List<LatLng>) {
        routePoints = points;
      } else if (points is List) {
        routePoints = points.whereType<LatLng>().toList();
      }
    } else if (widget.runData.containsKey('route') && widget.runData['route'] != null) {
      final points = widget.runData['route'];
      if (points is List<LatLng>) {
        routePoints = points;
      } else if (points is List) {
        routePoints = points.whereType<LatLng>().toList();
      }
    } else if (widget.runData.containsKey('path') && widget.runData['path'] != null) {
      final points = widget.runData['path'];
      if (points is List<LatLng>) {
        routePoints = points;
      } else if (points is List) {
        routePoints = points.whereType<LatLng>().toList();
      }
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

            // Route Map
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "ROUTE MAP",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
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

  Widget _buildRouteMap(List<LatLng> routePoints) {
    final staticMapUrl = _buildStaticMapUrl(routePoints);

    return Container(
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        staticMapUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 300,
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
                  Icon(Icons.map_outlined, color: Colors.grey.shade400, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Map unavailable',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
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

    final encodedPath = _encodePolyline(routePoints);

    final url = StringBuffer('https://maps.googleapis.com/maps/api/staticmap?');
    url.write('center=$centerLat,$centerLng');
    url.write('&size=600x400');
    url.write('&scale=2');
    url.write('&maptype=roadmap');
    url.write('&path=color:0x4285F4FF|weight:4|enc:$encodedPath');
    url.write('&markers=color:green|size:small|${routePoints.first.latitude},${routePoints.first.longitude}');
    url.write('&markers=color:red|size:small|${routePoints.last.latitude},${routePoints.last.longitude}');
    url.write('&key=${RunDetailScreen._apiKey}');

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
