import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LastActivityScreen extends StatefulWidget {
  final Map<String, dynamic> lastRun;

  const LastActivityScreen({super.key, required this.lastRun});

  @override
  State<LastActivityScreen> createState() => _LastActivityScreenState();
}

class _LastActivityScreenState extends State<LastActivityScreen> {
  @override
  Widget build(BuildContext context) {
    final distance = widget.lastRun['distance']?.toStringAsFixed(2) ?? "0.00";
    final durationSeconds = widget.lastRun['durationSeconds'] ?? 0;
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    final timeString = "$minutes:${seconds.toString().padLeft(2, '0')}";
    final pace = widget.lastRun['pace'] ?? "8:15";
    final calories = widget.lastRun['calories'] ?? 0;
    final date = widget.lastRun['date'] as DateTime? ?? DateTime.now();
    final formattedDate = DateFormat('MMM dd').format(date);
    final elevation = widget.lastRun['elevation'] ?? 118.0;

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
            // Header with date and share
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formattedDate,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Share functionality
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: Colors.blue.shade700,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text("Share"),
                  ),
                ],
              ),
            ),

            // Main Run Stats
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue.shade50,
                    Colors.purple.shade50,
                  ],
                ),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "My Run:",
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(Icons.directions_run, color: Colors.blue),
                    ],
                  ),
                  const SizedBox(height: 25),

                  // Stats Grid
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _detailStat("Distance (km)", distance, Icons.route),
                      _detailStat("Time (min:sec)", timeString, Icons.timer),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _detailStat("Pace (min/km)", pace, Icons.speed),
                      _detailStat("Calories", "$calories", Icons.local_fire_department),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _detailStat("Elevation Gain (m)", "${elevation.toInt()}", Icons.terrain),
                      _detailStat("Avg Heart Rate", "145 BPM", Icons.favorite),
                    ],
                  ),
                ],
              ),
            ),

            // Personal Records Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Personal Records:",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 15),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _personalRecordCard("Fastest Pace\n(1–3 km)", "7:30", Colors.green),
                        const SizedBox(width: 10),
                        _personalRecordCard("2nd Longest\nDistance", "10.2 km", Colors.blue),
                        const SizedBox(width: 10),
                        _personalRecordCard("10th Largest\nElevation Gain", "210 m", Colors.orange),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Splits Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Splits:",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _splitChip("0.25 km", "1:55"),
                      _splitChip("0.5 km", "3:45"),
                      _splitChip("1 km", "7:30"),
                      _splitChip("2 km", "15:10"),
                      _splitChip("5 km", "38:45"),
                      _splitChip("10 km", "78:20"),
                    ],
                  ),
                ],
              ),
            ),

            // Map Preview
            _buildRouteMap(),
          ],
        ),
      ),
    );
  }

  Widget _detailStat(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Container(
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
                Icon(icon, color: Colors.blue.shade700, size: 24),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
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

  Widget _personalRecordCard(String title, String value, Color color) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _splitChip(String distance, String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            distance,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            time,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteMap() {
    List<LatLng>? routePoints;
    try {
      if (widget.lastRun.containsKey('routePoints') && widget.lastRun['routePoints'] != null) {
        final points = widget.lastRun['routePoints'];
        if (points is List<LatLng>) {
          routePoints = points;
        } else if (points is List) {
          routePoints = points.whereType<LatLng>().toList();
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error parsing routePoints: $e');
    }

    if (routePoints == null || routePoints.length < 2) {
      return Container(
        margin: const EdgeInsets.all(20),
        height: 150,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map, size: 40, color: Colors.grey),
              SizedBox(height: 10),
              Text(
                "No Route Data",
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final bounds = _calculateBounds(routePoints);

    final initialPosition = CameraPosition(
      target: LatLng(
        (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
        (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
      ),
      zoom: 13,
    );

    return Container(
      margin: const EdgeInsets.all(20),
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
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
}