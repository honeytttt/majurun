import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart' show GeoPoint;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:majurun/core/utils/map_marker_builder.dart';


class LastActivityScreen extends StatefulWidget {
  final Map<String, dynamic> lastRun;
  const LastActivityScreen({super.key, required this.lastRun});

  @override
  State<LastActivityScreen> createState() => _LastActivityScreenState();
}

class _LastActivityScreenState extends State<LastActivityScreen> {
  BitmapDescriptor? _startMarker;
  BitmapDescriptor? _endMarker;

  @override
  void initState() {
    super.initState();
    _loadMarkers();
  }

  Future<void> _loadMarkers() async {
    final start = await MapMarkerBuilder.buildForCurrentUser(
      borderColor: const Color(0xFFFC4C02), // orange = start
    );
    final end = await MapMarkerBuilder.buildForCurrentUser(
      borderColor: const Color(0xFF7ED957), // green = end
    );
    if (mounted) {
      setState(() {
        _startMarker = start;
        _endMarker = end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final distVal = widget.lastRun['distance'] ?? 0.0;
    final distanceDouble = (distVal is num) ? distVal.toDouble() : 0.0;
    final distance = distanceDouble.toStringAsFixed(2);

    final durationSecondsRaw = widget.lastRun['durationSeconds'] ?? 0;
    final durationSeconds = (durationSecondsRaw is num) ? durationSecondsRaw.toInt() : 0;

    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    final timeString = "$minutes:${seconds.toString().padLeft(2, '0')}";

    final pace = widget.lastRun['pace'] ?? "8:15";
    final calories = widget.lastRun['calories'] ?? 0;

    final date = widget.lastRun['date'] as DateTime? ?? DateTime.now();
    // 'date' is the timestamp when the run was saved (end of run),
    // so subtract duration to get the actual start time.
    final startDateTime = date.subtract(Duration(seconds: durationSeconds));
    final dateStr = DateFormat('MMM dd').format(startDateTime);
    final startTime = DateFormat('HH:mm').format(startDateTime);
    final endTime = DateFormat('HH:mm').format(date);
    final headerDateTime = "$dateStr • $startTime–$endTime";

    final elevationRaw = widget.lastRun['elevation'] ?? 118.0;
    final elevation = (elevationRaw is num) ? elevationRaw.toDouble() : 118.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "LAST ACTIVITY",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    headerDateTime,
                    style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: Colors.blue.shade700,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text("Share"),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.blue.shade50, Colors.purple.shade50]),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "My Session",
                        style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Icon(Icons.directions_run, color: Colors.blue),
                    ],
                  ),
                  const SizedBox(height: 25),
                  Row(
                    children: [
                      _detailStat("Distance (km)", distance, Icons.route),
                      _detailStat("Time (min:sec)", timeString, Icons.timer),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _detailStat("Pace (min/km)", pace, Icons.speed),
                      _detailStat("Calories", "$calories", Icons.local_fire_department),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _detailStat("Elevation Gain (m)", "${elevation.toInt()}", Icons.terrain),
                      _detailStat("Avg Heart Rate", "145 BPM", Icons.favorite),
                    ],
                  ),
                ],
              ),
            ),
            _buildRoutePreview(),
          ],
        ),
      ),
    );
  }

  static Widget _detailStat(String label, String value, IconData icon) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.blueAccent, size: 24),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoutePreview() {
    final rawPoints = _extractRoutePoints(widget.lastRun['routePoints']);
    final points = _sanitizeAndDownsample(rawPoints);

    if (points.length < 2) {
      return _noPreview();
    }

    // Lite mode = static bitmap — no separate native GL context, no scroll jank
    final bounds = _calculateBounds(points);
    final center = LatLng(
      (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
      (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
    );
    final latSpan = bounds.northeast.latitude - bounds.southwest.latitude;
    final lngSpan = bounds.northeast.longitude - bounds.southwest.longitude;
    final maxSpan = math.max(latSpan, lngSpan);
    // For a 250px container: zoom = log2(320 / maxSpan)
    final double zoom = maxSpan > 0
        ? (math.log(320 / maxSpan) / math.ln2).clamp(10.0, 17.0)
        : 13.0;

    return Container(
      margin: const EdgeInsets.all(20),
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(target: center, zoom: zoom),
        liteModeEnabled: true,
        mapType: MapType.normal,
        polylines: {
          Polyline(
            polylineId: const PolylineId('route'),
            points: points,
            color: const Color(0xFFFC4C02),
            width: 5,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        },
        markers: {
          Marker(
            markerId: const MarkerId('start'),
            position: points.first,
            icon: _startMarker ??
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            anchor: const Offset(0.5, 0.5),
          ),
          Marker(
            markerId: const MarkerId('end'),
            position: points.last,
            icon: _endMarker ??
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            anchor: const Offset(0.5, 0.5),
          ),
        },
        zoomControlsEnabled: false,
        zoomGesturesEnabled: false,
        scrollGesturesEnabled: false,
        rotateGesturesEnabled: false,
        tiltGesturesEnabled: false,
        mapToolbarEnabled: false,
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
      ),
    );
  }

  // Preview-only sanitization (safe)
  List<LatLng> _sanitizeAndDownsample(
    List<LatLng> points, {
    double maxJumpMeters = 120,
    int maxPoints = 220,
  }) {
    if (points.length < 2) return points;

    final filtered = <LatLng>[points.first];
    for (int i = 1; i < points.length; i++) {
      final d = _haversineMeters(filtered.last, points[i]);
      if (d <= maxJumpMeters) {
        filtered.add(points[i]);
      }
    }

    if (filtered.length <= maxPoints) return filtered;

    final step = (filtered.length / maxPoints).ceil();
    final out = <LatLng>[];
    for (int i = 0; i < filtered.length; i += step) {
      out.add(filtered[i]);
    }
    if (out.last != filtered.last) {
      out.add(filtered.last);
    }
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

  List<LatLng> _extractRoutePoints(dynamic raw) {
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
          if (lat is num && lng is num) {
            out.add(LatLng(lat.toDouble(), lng.toDouble()));
          }
        }
      }
      return out;
    }

    return <LatLng>[];
  }

  Widget _noPreview() {
    return Container(
      margin: const EdgeInsets.all(20),
      height: 250,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const Center(
        child: Text("No map preview", style: TextStyle(color: Colors.grey)),
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
}