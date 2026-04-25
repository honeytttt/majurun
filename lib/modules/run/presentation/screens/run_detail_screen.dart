import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:majurun/core/utils/map_marker_builder.dart';
import 'package:majurun/core/widgets/unified_metric_tile.dart';


class RunDetailScreen extends StatefulWidget {
  final Map<String, dynamic> runData;
  const RunDetailScreen({super.key, required this.runData});

  @override
  State<RunDetailScreen> createState() => _RunDetailScreenState();
}

class _RunDetailScreenState extends State<RunDetailScreen> {
  String _mapVisualization = 'pace';
  String _splitDistance = '1km';
  BitmapDescriptor? _startMarker;
  BitmapDescriptor? _endMarker;

  @override
  void initState() {
    super.initState();
    _loadMarkers();
  }

  Future<void> _loadMarkers() async {
    final runUserId = widget.runData['userId'] as String?;
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final uid = (runUserId != null && runUserId.isNotEmpty) ? runUserId : currentUid;
    final start = await MapMarkerBuilder.buildForUser(uid,
      borderColor: const Color(0xFFFC4C02),
    );
    final end = await MapMarkerBuilder.buildForUser(uid,
      borderColor: const Color(0xFF7ED957),
    );
    if (mounted) {
      setState(() {
        _startMarker = start;
        _endMarker = end;
      });
    }
  }

  /// Safely parse routePoints from Firestore (stored as List<Map> with 'lat'/'lng').
  List<LatLng> _parseRoutePoints(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List<LatLng>) return raw;
    if (raw is! List) return const [];
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

  // HR Zone helpers (220 - age 30 = 190 maxHR as conservative default)
  static const _maxHr = 190;
  static const _hrZoneNames = ['', 'Z1', 'Z2', 'Z3', 'Z4', 'Z5'];
  int _hrZoneFromBpm(int bpm) {
    if (bpm <= 0) return 0;
    final pct = bpm / _maxHr;
    if (pct < 0.60) return 1;
    if (pct < 0.70) return 2;
    if (pct < 0.80) return 3;
    if (pct < 0.90) return 4;
    return 5;
  }

  String _formatSeconds(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return "$m:${s.toString().padLeft(2, '0')}";
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

  bool _isSession(Map<String, dynamic> data) {
    final type = data['type']?.toString().toLowerCase();
    if (type == 'training') return true;
    if (data['week'] != null && data['day'] != null) return true;
    final weekDay = data['weekDay']?.toString().toLowerCase();
    if (weekDay != null && weekDay.contains('week') && weekDay.contains('day')) return true;
    return false;
  }

  String _wkDayLabel(Map<String, dynamic> data) {
    final week = data['week'];
    final day = data['day'];
    if (week != null && day != null) return "Wk $week • Day $day";

    final weekDay = data['weekDay']?.toString();
    if (weekDay != null && weekDay.isNotEmpty) {
      return weekDay.replaceAll("Week", "Wk").replaceAll(",", " •");
    }
    return "";
  }

  bool? _completedFlag(Map<String, dynamic> data) {
    final v = data['completed'];
    if (v is bool) return v;
    if (v is String) {
      if (v.toLowerCase() == 'true') return true;
      if (v.toLowerCase() == 'false') return false;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final date = _parseDate(widget.runData['date']);

    final distVal = widget.runData['distance'] ?? 0.0;
    final distanceDouble = (distVal is num) ? distVal.toDouble() : 0.0;
    final distance = distanceDouble.toStringAsFixed(2);

    final durationSeconds = (widget.runData['durationSeconds'] as num?)?.toInt() ?? 0;
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;
    final timeString = hours > 0
        ? "$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}"
        : "$minutes:${seconds.toString().padLeft(2, '0')}";

    // Moving time (excludes paused time) — saved from +108 onwards
    final movingTimeSecs = (widget.runData['movingTimeSeconds'] as num?)?.toInt() ?? 0;
    final hasMovingTime = movingTimeSecs > 0 && movingTimeSecs < durationSeconds;
    final movingHours = movingTimeSecs ~/ 3600;
    final movingMins = (movingTimeSecs % 3600) ~/ 60;
    final movingSecs = movingTimeSecs % 60;
    final movingTimeString = movingHours > 0
        ? "$movingHours:${movingMins.toString().padLeft(2, '0')}:${movingSecs.toString().padLeft(2, '0')}"
        : "$movingMins:${movingSecs.toString().padLeft(2, '0')}";

    final pace = widget.runData['pace'] ?? "0:00";
    final calories = widget.runData['calories'] ?? 0;
    final avgBpmRaw = widget.runData['avgBpm'] ?? widget.runData['bpm'] ?? 0;
    final avgBpm = avgBpmRaw is num ? avgBpmRaw.toInt() : 0;
    final hrZone = _hrZoneFromBpm(avgBpm);

    final isSession = _isSession(widget.runData);
    final wkDay = _wkDayLabel(widget.runData);
    final completed = _completedFlag(widget.runData);
    final statusLabel = completed == null ? null : (completed ? "Completed" : "In Progress");

    final double elevGain = (widget.runData['elevationGain'] as num?)?.toDouble() ?? 0.0;
    final double elevLoss = (widget.runData['elevationLoss'] as num?)?.toDouble() ?? 0.0;
    final bool hasElevation = elevGain > 0 || elevLoss > 0;

    // Weather — stored in extra map, spread to top-level in stats_controller
    final double? weatherTemp = (widget.runData['temp'] as num?)?.toDouble();
    final String? weatherCondition = widget.runData['condition']?.toString();
    final double? weatherWind = (widget.runData['windSpeed'] as num?)?.toDouble();
    final int? weatherHumidity = (widget.runData['humidity'] as num?)?.toInt();
    final String? weatherLocation = widget.runData['location']?.toString();
    final bool hasWeather = weatherTemp != null && weatherCondition != null;

    final String? mapImageUrlRaw = widget.runData['mapImageUrl']?.toString();
    final bool hasMapImage = mapImageUrlRaw != null && mapImageUrlRaw.isNotEmpty;

    // Route points — Firestore stores as List<Map> with 'lat'/'lng' keys.
    // The previous cast (as List<LatLng>?) always returned null silently.
    final List<LatLng> routePoints = _parseRoutePoints(
      widget.runData['routePoints'] ?? widget.runData['route'] ?? widget.runData['path'],
    );
    final bool hasRoute = routePoints.length >= 2;
    final String mapImageUrl = mapImageUrlRaw ?? '';

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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                DateFormat('EEEE, MMM d, yyyy').format(date),
                style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(DateFormat('h:mm a').format(date), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const Spacer(),
                  if (isSession) _badge(label: "SESSION", icon: Icons.fitness_center),
                  if (wkDay.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _chip(text: wkDay, icon: Icons.calendar_today),
                  ],
                  if (statusLabel != null) ...[
                    const SizedBox(width: 8),
                    _chip(
                      text: statusLabel,
                      icon: statusLabel == "Completed" ? Icons.check_circle : Icons.timelapse,
                      color: statusLabel == "Completed" ? Colors.green : Colors.orange,
                    ),
                  ],
                ],
              ),
            ]),
          ),

          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0A0A0A), Color(0xFF1A1A1A), Color(0xFF00FF87)],
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
                    UnifiedMetricTile(
                      icon: Icons.directions_run_rounded,
                      label: "Distance",
                      value: distance,
                      unit: "KM",
                      accentColor: const Color(0xFF00FF87),
                    ),
                    UnifiedMetricTile(
                      icon: Icons.timer_outlined,
                      label: "Duration",
                      value: timeString,
                      accentColor: Colors.blue,
                    ),
                    UnifiedMetricTile(
                      icon: Icons.speed,
                      label: "Pace",
                      value: pace,
                      unit: "/km",
                      accentColor: Colors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    UnifiedMetricTile(
                      icon: Icons.favorite,
                      label: "AVG HR",
                      value: avgBpm > 0 ? "$avgBpm ${_hrZoneNames[hrZone]}" : "--",
                      accentColor: hrZone > 0 ? [Colors.blue, Colors.green, Colors.orange, const Color(0xFFFC4C02), Colors.red][hrZone - 1] : Colors.grey,
                    ),
                    UnifiedMetricTile(
                      icon: Icons.local_fire_department,
                      label: "CALORIES",
                      value: "$calories",
                      accentColor: Colors.redAccent,
                    ),
                    if (hasElevation)
                      UnifiedMetricTile(
                        icon: Icons.trending_up,
                        label: "ELEV +",
                        value: "${elevGain.toStringAsFixed(0)}m",
                        accentColor: Colors.purple,
                      ),
                  ],
                ),
                if (hasMovingTime) ...[
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      UnifiedMetricTile(
                        icon: Icons.timer_outlined,
                        label: "TOTAL TIME",
                        value: timeString,
                        accentColor: Colors.blue,
                      ),
                      UnifiedMetricTile(
                        icon: Icons.directions_run,
                        label: "MOVING TIME",
                        value: movingTimeString,
                        accentColor: const Color(0xFF00FF87),
                      ),
                      UnifiedMetricTile(
                        icon: Icons.pause_circle_outline,
                        label: "PAUSED",
                        value: _formatSeconds(durationSeconds - movingTimeSecs),
                        accentColor: Colors.redAccent,
                      ),
                      ],
                      ),
                      ],
                      ],
                      ),
                      ),

                      const SizedBox(height: 30),

          // ── Weather at time of run ───────────────────────────────────────
          if (hasWeather)
            _buildWeatherCard(
              temp: weatherTemp ?? 0,
              condition: weatherCondition ?? '',
              windKmh: weatherWind,
              humidity: weatherHumidity,
              location: weatherLocation,
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("MAP PREVIEW", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  if (!hasMapImage && hasRoute)
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

              if (hasRoute)
                _buildRouteMap(routePoints) // live map always preferred — shows current styling
              else if (hasMapImage)
                _buildNetworkPreview(mapImageUrl) // fallback to cached screenshot if no GPS data
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
                        Text('No map preview available', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                      ],
                    ),
                  ),
                ),

              if (!hasMapImage && hasRoute) ...[
                const SizedBox(height: 10),
                _buildMapLegend(),
              ],
            ]),
          ),

          const SizedBox(height: 30),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("SPLITS", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  _buildSplitSelector(),
                ],
              ),
              const SizedBox(height: 15),
              _buildSplitsList(),
            ]),
          ),

          const SizedBox(height: 30),
        ]),
      ),
    );
  }

  // Share text includes session info
  void _shareRun() {
    final date = _parseDate(widget.runData['date']);

    final distVal = widget.runData['distance'] ?? 0.0;
    final dist = (distVal is num) ? distVal.toDouble() : 0.0;

    final durationSeconds = widget.runData['durationSeconds'] ?? 0;
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;
    final timeString = hours > 0
        ? "$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}"
        : "$minutes:${seconds.toString().padLeft(2, '0')}";

    final pace = widget.runData['pace'] ?? "0:00";
    final calories = widget.runData['calories'] ?? 0;

    final isSession = _isSession(widget.runData);
    final wkDay = _wkDayLabel(widget.runData);
    final completed = _completedFlag(widget.runData);
    final statusLabel = completed == null ? null : (completed ? "Completed" : "In Progress");

    final sessionHeader = isSession
        ? " • SESSION${wkDay.isNotEmpty ? " • $wkDay" : ""}${statusLabel != null ? " • $statusLabel" : ""}"
        : "";

    final shareText = '''
🏃 MajuRun$sessionHeader
📅 ${DateFormat('MMM d, yyyy').format(date)} • ${DateFormat('h:mm a').format(date)}
📍 Distance: ${dist.toStringAsFixed(2)} km
⏱️ Time: $timeString
⚡ Pace: $pace /km
🔥 Calories: $calories
Keep moving 💪
''';

    SharePlus.instance.share(ShareParams(text: shareText));
  }

  Widget _badge({required String label, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.green.shade400, Colors.green.shade700]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _chip({required String text, required IconData icon, Color color = Colors.black}) {
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

  // ── Weather helpers ────────────────────────────────────────────────────────

  String _weatherEmoji(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear':   return '☀️';
      case 'clouds':  return '☁️';
      case 'rain':    return '🌧️';
      case 'drizzle': return '🌦️';
      case 'thunderstorm': return '⛈️';
      case 'snow':    return '❄️';
      case 'fog':     return '🌫️';
      default:        return '🌡️';
    }
  }

  Widget _buildWeatherCard({
    required double temp,
    required String condition,
    double? windKmh,
    int? humidity,
    String? location,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F8FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBDEFB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wb_sunny_outlined,
                  size: 14, color: Color(0xFF1976D2)),
              const SizedBox(width: 6),
              const Text(
                'WEATHER AT START',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Color(0xFF1976D2),
                ),
              ),
              if (location != null && location.isNotEmpty) ...[
                const Spacer(),
                Text(
                  location,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.black45),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                _weatherEmoji(condition),
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${temp.round()}°C',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    condition[0].toUpperCase() + condition.substring(1),
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
              const Spacer(),
              if (windKmh != null)
                _weatherStat(
                    Icons.air, '${windKmh.round()} km/h', 'Wind'),
              if (humidity != null) ...[
                const SizedBox(width: 16),
                _weatherStat(
                    Icons.water_drop_outlined, '$humidity%', 'Humidity'),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _weatherStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF1976D2)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.black45)),
      ],
    );
  }

  Widget _buildNetworkPreview(String url) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, color: Colors.grey.shade400, size: 48),
                const SizedBox(height: 12),
                Text('Preview unavailable', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMapToggle(String label, String value) {
    final isSelected = _mapVisualization == value;
    return GestureDetector(
      onTap: () => setState(() => _mapVisualization = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }


  /// Build colored polylines for pace visualization.
  /// Splits route points into per-km segments and colors each by pace.
  Set<Polyline> _buildPacePolylines(List<LatLng> routePoints) {
    final rawSplits = widget.runData['kmSplits'];
    if (rawSplits == null || rawSplits is! List || rawSplits.isEmpty) {
      return {Polyline(polylineId: const PolylineId('route'), points: routePoints, color: const Color(0xFFFC4C02), width: 6)};
    }

    // Parse pace strings to seconds/km for comparison
    double paceToSecs(String p) {
      final parts = p.split(':');
      if (parts.length != 2) return 300;
      return (int.tryParse(parts[0]) ?? 5) * 60.0 + (int.tryParse(parts[1]) ?? 0);
    }

    final splits = rawSplits.cast<Map>();
    final paces = splits.map((s) => paceToSecs(s['pace']?.toString() ?? '5:00')).toList();
    final minPace = paces.reduce((a, b) => a < b ? a : b); // fastest (smallest secs)
    final maxPace = paces.reduce((a, b) => a > b ? a : b); // slowest (largest secs)
    final range = maxPace - minPace;

    // Calculate cumulative distance for each route point
    final cumDist = <double>[0.0];
    for (int i = 1; i < routePoints.length; i++) {
      cumDist.add(cumDist.last + Geolocator.distanceBetween(
        routePoints[i-1].latitude, routePoints[i-1].longitude,
        routePoints[i].latitude, routePoints[i].longitude,
      ));
    }

    final polylines = <Polyline>{};
    for (int si = 0; si < splits.length; si++) {
      final startM = si * 1000.0;
      final endM = (si + 1) * 1000.0;
      final segPoints = <LatLng>[];
      for (int i = 0; i < routePoints.length; i++) {
        if (cumDist[i] >= startM && cumDist[i] <= endM) segPoints.add(routePoints[i]);
      }
      if (segPoints.length < 2) continue;

      final t = range > 0 ? ((paces[si] - minPace) / range).clamp(0.0, 1.0) : 0.5;
      // Green (fast) → Orange → Red (slow)
      final color = Color.lerp(Colors.green.shade600, Colors.red.shade700, t)!;
      polylines.add(Polyline(
        polylineId: PolylineId('seg_$si'),
        points: segPoints,
        color: color,
        width: 6,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ));
    }
    // Fallback if splits don't cover full distance
    if (polylines.isEmpty) {
      polylines.add(Polyline(polylineId: const PolylineId('route'), points: routePoints, color: const Color(0xFFFC4C02), width: 6));
    }
    return polylines;
  }

  Widget _buildRouteMap(List<LatLng> routePoints) {
    final bounds = _calculateBounds(routePoints);
    final initialPosition = CameraPosition(
      target: LatLng(
        (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
        (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
      ),
      zoom: 13,
    );

    final polylines = _mapVisualization == 'pace'
        ? _buildPacePolylines(routePoints)
        : {
            Polyline(
              polylineId: const PolylineId('route'),
              points: routePoints,
              color: const Color(0xFFFC4C02),
              width: 6,
              jointType: JointType.round,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
            ),
          };

    return Container(
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: GoogleMap(
        initialCameraPosition: initialPosition,
        mapType: MapType.normal,
        polylines: polylines,
        markers: {
          Marker(
            markerId: const MarkerId('start'),
            position: routePoints.first,
            icon: _startMarker ??
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            anchor: const Offset(0.5, 0.5),
          ),
          Marker(
            markerId: const MarkerId('end'),
            position: routePoints.last,
            icon: _endMarker ??
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            anchor: const Offset(0.5, 0.5),
          ),
        },
        zoomControlsEnabled: true,
        zoomGesturesEnabled: true,
        scrollGesturesEnabled: true,
        rotateGesturesEnabled: true,
        tiltGesturesEnabled: true,
        mapToolbarEnabled: false,
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        onMapCreated: (GoogleMapController controller) {
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) {
              controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
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

    for (final p in points) {
      if (p.latitude < south) {
        south = p.latitude;
      }
      if (p.latitude > north) {
        north = p.latitude;
      }
      if (p.longitude < west) {
        west = p.longitude;
      }
      if (p.longitude > east) {
        east = p.longitude;
      }
    }

    return LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
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
        Container(width: 20, height: 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildSplitSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(20)),
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
      onTap: () => setState(() => _splitDistance = distance),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          distance.toUpperCase(),
          style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSplitsList() {
    final rawSplits = widget.runData['kmSplits'];
    final hasSplits = rawSplits is List && rawSplits.isNotEmpty;

    if (!hasSplits) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
        child: const Center(child: Text('Split data available for runs after v1.0.0+108', style: TextStyle(color: Colors.grey, fontSize: 13))),
      );
    }

    final splitKm = _splitDistance == '1km' ? 1 : _splitDistance == '2km' ? 2 : 5;
    // Group 1km splits into the requested bucket (e.g. 5km = combine 5×1km splits)
    final splits = List<Map>.from(rawSplits);
    final grouped = <List<Map>>[];
    for (int i = 0; i < splits.length; i += splitKm) {
      grouped.add(splits.sublist(i, (i + splitKm).clamp(0, splits.length)));
    }

    // Find fastest and slowest pace for color scaling
    double paceToSecs(String p) {
      final parts = p.split(':');
      if (parts.length != 2) return 300;
      return (int.tryParse(parts[0]) ?? 5) * 60.0 + (int.tryParse(parts[1]) ?? 0);
    }
    final allPaces = splits.map((s) => paceToSecs(s['pace']?.toString() ?? '5:00')).toList();
    final bestPace = allPaces.isEmpty ? 300.0 : allPaces.reduce((a, b) => a < b ? a : b);
    final worstPace = allPaces.isEmpty ? 300.0 : allPaces.reduce((a, b) => a > b ? a : b);
    final range = worstPace - bestPace;

    return Column(
      children: grouped.asMap().entries.map((entry) {
        final groupIndex = entry.key;
        final group = entry.value;
        final totalSecs = group.fold<int>(0, (s, e) => s + ((e['durationSeconds'] as num?)?.toInt() ?? 0));
        final distKm = splitKm.toDouble().clamp(0, (widget.runData['distance'] as num?)?.toDouble() ?? 0);

        // Compute average pace for this group
        final avgPaceSecs = totalSecs / group.length;
        final paceMin = (avgPaceSecs ~/ 60);
        final paceSec = (avgPaceSecs % 60).round();
        final paceStr = "$paceMin:${paceSec.toString().padLeft(2, '0')}";

        // Color: green (fast) → red (slow)
        final t = range > 0 ? ((avgPaceSecs - bestPace) / range).clamp(0.0, 1.0) : 0.5;
        final paceColor = Color.lerp(Colors.green.shade600, Colors.red.shade700, t)!;

        // Elevation from first split in group
        final elevChange = (group.first['elevationChange'] as num?)?.toDouble() ?? 0.0;
        final elevColor = elevChange > 0 ? Colors.orange.shade700 : elevChange < 0 ? Colors.blue.shade700 : Colors.grey;

        // Time formatting
        final tMin = totalSecs ~/ 60;
        final tSec = totalSecs % 60;
        final timeStr = "$tMin:${tSec.toString().padLeft(2, '0')}";

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
                decoration: BoxDecoration(color: paceColor, borderRadius: BorderRadius.circular(8)),
                child: Center(
                  child: Text(
                    "${groupIndex + 1}",
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("${distKm.toStringAsFixed(splitKm > 1 ? 0 : 2)} km · $timeStr",
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.speed, size: 12, color: paceColor),
                    const SizedBox(width: 4),
                    Text("$paceStr /km", style: TextStyle(fontSize: 12, color: paceColor, fontWeight: FontWeight.w600)),
                    if (elevChange != 0) ...[
                      const SizedBox(width: 16),
                      Icon(Icons.terrain, size: 12, color: elevColor),
                      const SizedBox(width: 4),
                      Text("${elevChange > 0 ? '+' : ''}${elevChange.toStringAsFixed(0)}m",
                          style: TextStyle(fontSize: 12, color: elevColor, fontWeight: FontWeight.w600)),
                    ],
                  ]),
                ]),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class ColoredRoutePainter extends CustomPainter {
  final List<LatLng> points;
  final String visualizationType;

  ColoredRoutePainter({required this.points, required this.visualizationType});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

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

    double latRange = maxLat - minLat;
    double lngRange = maxLng - minLng;

    double range = latRange > lngRange ? latRange : lngRange;
    if (range == 0) range = 1;

    final paint = Paint()
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (int i = 0; i < points.length - 1; i++) {
      final progress = i / points.length;

      if (visualizationType == 'pace') {
        final paceValue = math.sin(progress * math.pi * 3) * 0.5 + 0.5;
        paint.color = Color.lerp(Colors.green, Colors.red, paceValue)!;
      } else {
        final elevationValue = math.sin(progress * math.pi * 2) * 0.5 + 0.5;
        paint.color = Color.lerp(Colors.blue.shade200, Colors.blue.shade800, elevationValue)!;
      }

      double x1 = (points[i].longitude - minLng) / range * size.width * 0.9 + size.width * 0.05;
      double y1 = (maxLat - points[i].latitude) / range * size.height * 0.9 + size.height * 0.05;

      double x2 = (points[i + 1].longitude - minLng) / range * size.width * 0.9 + size.width * 0.05;
      double y2 = (maxLat - points[i + 1].latitude) / range * size.height * 0.9 + size.height * 0.05;

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }

    final markerPaint = Paint()..style = PaintingStyle.fill;

    double startX = (points.first.longitude - minLng) / range * size.width * 0.9 + size.width * 0.05;
    double startY = (maxLat - points.first.latitude) / range * size.height * 0.9 + size.height * 0.05;
    markerPaint.color = Colors.green;
    canvas.drawCircle(Offset(startX, startY), 10, markerPaint);
    markerPaint.color = Colors.white;
    canvas.drawCircle(Offset(startX, startY), 5, markerPaint);

    double endX = (points.last.longitude - minLng) / range * size.width * 0.9 + size.width * 0.05;
    double endY = (maxLat - points.last.latitude) / range * size.height * 0.9 + size.height * 0.05;
    markerPaint.color = Colors.red;
    canvas.drawCircle(Offset(endX, endY), 10, markerPaint);
    markerPaint.color = Colors.white;
    canvas.drawCircle(Offset(endX, endY), 5, markerPaint);
  }

  @override
  bool shouldRepaint(ColoredRoutePainter oldDelegate) {
    return oldDelegate.visualizationType != visualizationType || oldDelegate.points != points;
  }
}