import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:js/js.dart';

// Check if Google Maps API is loaded
@JS('google')
external dynamic get googleObject;

class RunMapPreview extends StatelessWidget {
  final List<dynamic> points;

  const RunMapPreview({
    super.key,
    required this.points,
  });

  bool _isGoogleMapsLoaded() {
    try {
      return googleObject != null;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'No route data',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // Wait for Google Maps API to load
    if (!_isGoogleMapsLoaded()) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.blue,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Loading map...',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    try {
      // Convert route points to LatLng - handle multiple formats
      final latLngPoints = points.map((point) {
        try {
          if (point is Map) {
            // Try different key variations
            final lat = (point['lat'] ?? point['latitude'] ?? 0.0);
            final lng = (point['lng'] ?? point['longitude'] ?? 0.0);
            
            // Convert to double if needed
            final latDouble = lat is double ? lat : (lat as num).toDouble();
            final lngDouble = lng is double ? lng : (lng as num).toDouble();
            
            // Validate coordinates
            if (latDouble >= -90 && latDouble <= 90 && 
                lngDouble >= -180 && lngDouble <= 180 &&
                latDouble != 0.0 && lngDouble != 0.0) {
              return LatLng(latDouble, lngDouble);
            }
          } else if (point is LatLng) {
            return point;
          }
        } catch (e) {
          debugPrint('Error parsing point: $e');
        }
        return null;
      }).whereType<LatLng>().toList();

      debugPrint('Parsed ${latLngPoints.length} route points from ${points.length} total points');

      if (latLngPoints.isEmpty) {
        return Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.map_outlined,
                  size: 48,
                  color: Colors.grey,
                ),
                const SizedBox(height: 8),
                Text(
                  'No valid GPS points (${points.length} total)',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      }

      // Create polyline from points
      final polyline = Polyline(
        polylineId: const PolylineId('route'),
        points: latLngPoints,
        color: Colors.blue,
        width: 4,
      );

      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 200,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: latLngPoints.first,
              zoom: 14,
            ),
            polylines: {polyline},
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            scrollGesturesEnabled: false,
            zoomGesturesEnabled: false,
            tiltGesturesEnabled: false,
            rotateGesturesEnabled: false,
          ),
        ),
      );
    } catch (e, stack) {
      debugPrint('❌ Error rendering map preview: $e');
      debugPrint('Stack: $stack');
      debugPrint('Points data: ${points.length} items');
      if (points.isNotEmpty) {
        debugPrint('First point: ${points.first}');
      }
      
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Icon(
            Icons.map_outlined,
            size: 48,
            color: Colors.grey,
          ),
        ),
      );
    }
  }
}