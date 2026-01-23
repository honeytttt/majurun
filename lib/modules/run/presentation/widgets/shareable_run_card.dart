import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'route_painter.dart';

class ShareableRunCard extends StatelessWidget {
  final GlobalKey boundaryKey;
  final String distance;
  final String pace;
  final String bpm;
  final List<LatLng> route;

  const ShareableRunCard({
    super.key,
    required this.boundaryKey,
    required this.distance,
    required this.pace,
    required this.bpm,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: boundaryKey,
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF121212), // Deep black
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("MAJURUN PRO", 
                  style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 10)),
                Text(DateTime.now().toString().substring(0, 10), 
                  style: const TextStyle(color: Colors.grey, fontSize: 10)),
              ],
            ),
            const SizedBox(height: 20),
            Text(distance, style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w900, height: 1)),
            const Text("KILOMETERS", style: TextStyle(color: Colors.grey, fontSize: 12, letterSpacing: 1.5)),
            const SizedBox(height: 24),
            Row(
              children: [
                _buildStat("PACE", pace),
                const SizedBox(width: 30),
                _buildStat("HEART RATE", "$bpm BPM"),
              ],
            ),
            const SizedBox(height: 30),
            Center(
              child: Container(
                height: 120,
                width: 200,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: CustomPaint(
                  painter: RoutePainter(points: route, color: Colors.cyanAccent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
      ],
    );
  }
}