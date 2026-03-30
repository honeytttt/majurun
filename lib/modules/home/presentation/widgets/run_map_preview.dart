import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Lite-mode static map preview for posts in the feed.
/// liteModeEnabled = true renders a bitmap snapshot — no native GL context,
/// no animateCamera, no OOM crash when many posts are visible.
class RunMapPreview extends StatelessWidget {
  final List<dynamic> points;

  const RunMapPreview({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    final latLngPoints = _parseRoutePoints(points);

    if (latLngPoints.length < 2) {
      return _placeholder('No route data');
    }

    final bounds = _calculateBounds(latLngPoints);
    final center = LatLng(
      (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
      (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
    );

    final latSpan = bounds.northeast.latitude - bounds.southwest.latitude;
    final lngSpan = bounds.northeast.longitude - bounds.southwest.longitude;
    final maxSpan = math.max(latSpan, lngSpan);
    // 320 constant calibrated for 200px container height
    final zoom = maxSpan > 0
        ? (math.log(320 / maxSpan) / math.ln2).clamp(10.0, 17.0)
        : 13.0;

    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(target: center, zoom: zoom),
        liteModeEnabled: true,
        polylines: {
          Polyline(
            polylineId: const PolylineId('route'),
            points: latLngPoints,
            color: const Color(0xFFFC4C02), // Strava orange
            width: 4,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        },
        markers: {
          Marker(
            markerId: const MarkerId('start'),
            position: latLngPoints.first,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            anchor: const Offset(0.5, 0.5),
          ),
          Marker(
            markerId: const MarkerId('end'),
            position: latLngPoints.last,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
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

  LatLngBounds _calculateBounds(List<LatLng> pts) {
    double s = pts.first.latitude, n = pts.first.latitude;
    double w = pts.first.longitude, e = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < s) s = p.latitude;
      if (p.latitude > n) n = p.latitude;
      if (p.longitude < w) w = p.longitude;
      if (p.longitude > e) e = p.longitude;
    }
    return LatLngBounds(southwest: LatLng(s, w), northeast: LatLng(n, e));
  }

  List<LatLng> _parseRoutePoints(List<dynamic> raw) {
    final out = <LatLng>[];
    for (final p in raw) {
      try {
        if (p is LatLng) { out.add(p); continue; }
        double? lat, lng;
        if (p is Map) {
          lat = _d(p['lat'] ?? p['latitude']);
          lng = _d(p['lng'] ?? p['longitude']);
        } else if (p is List && p.length >= 2) {
          lat = _d(p[0]); lng = _d(p[1]);
        }
        if (lat != null && lng != null &&
            lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
          out.add(LatLng(lat, lng));
        }
      } catch (_) {}
    }
    return out;
  }

  double? _d(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  Widget _placeholder(String msg) => Container(
    height: 200,
    decoration: BoxDecoration(
      color: Colors.grey[200],
      borderRadius: BorderRadius.circular(12),
    ),
    child: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.map_outlined, size: 48, color: Colors.grey),
        const SizedBox(height: 8),
        Text(msg, style: const TextStyle(color: Colors.grey, fontSize: 14)),
      ]),
    ),
  );
}
