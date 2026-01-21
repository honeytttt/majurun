import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RunMapPreview extends StatelessWidget {
  final List<LatLng> points;

  const RunMapPreview({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    // Calculate the center of the path for the initial camera position
    final centerLat = points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final centerLng = points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;

    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(centerLat, centerLng),
            zoom: 14,
          ),
          polylines: {
            Polyline(
              polylineId: const PolylineId("route"),
              points: points,
              color: Colors.blueAccent,
              width: 4,
            ),
          },
          liteModeEnabled: true, // Optimizes performance for lists
          myLocationEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),
      ),
    );
  }
}