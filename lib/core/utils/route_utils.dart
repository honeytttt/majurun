import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Utilities for handling route points efficiently.
class RouteUtils {
  /// Maximum number of route points to store in Firestore/posts.
  /// Keeps document size manageable and speeds up save operations.
  static const int maxRoutePoints = 200;

  /// Samples route points to reduce count while preserving route shape.
  /// Uses uniform sampling to maintain path representation.
  static List<LatLng> sampleRoutePoints(List<LatLng> points) {
    if (points.isEmpty) return [];
    if (points.length <= maxRoutePoints) return points;

    final result = <LatLng>[];
    final step = points.length / maxRoutePoints;

    // Always include first point
    result.add(points.first);

    // Sample intermediate points
    for (int i = 1; i < maxRoutePoints - 1; i++) {
      final index = (i * step).round().clamp(0, points.length - 1);
      result.add(points[index]);
    }

    // Always include last point
    result.add(points.last);

    return result;
  }

  /// Converts route points to Firestore-compatible format (list of maps).
  static List<Map<String, double>> toFirestoreFormat(List<LatLng> points) {
    return points
        .map((p) => {'lat': p.latitude, 'lng': p.longitude})
        .toList();
  }

  /// Converts route points to legacy format (latitude/longitude keys).
  static List<Map<String, double>> toLegacyFormat(List<LatLng> points) {
    return points
        .map((p) => {'latitude': p.latitude, 'longitude': p.longitude})
        .toList();
  }
}
