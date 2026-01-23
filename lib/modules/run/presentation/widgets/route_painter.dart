import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RoutePainter extends CustomPainter {
  final List<LatLng> points;
  final Color color;

  RoutePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // 1. Find the bounds of the coordinates
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

    // 2. Map coordinates to the widget size
    double latRange = maxLat - minLat;
    double lngRange = maxLng - minLng;
    
    // Maintain aspect ratio
    double range = latRange > lngRange ? latRange : lngRange;
    if (range == 0) range = 1;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();

    for (int i = 0; i < points.length; i++) {
      // Scale points and center them
      double x = (points[i].longitude - minLng) / range * size.width;
      double y = (maxLat - points[i].latitude) / range * size.height;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}