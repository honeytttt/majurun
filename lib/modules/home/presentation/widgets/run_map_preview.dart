import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RunMapPreview extends StatelessWidget {
  final List<dynamic> points;
  static const String _apiKey = 'AIzaSyDwPvTw5MMolE6iEPnFNNQe0FtJ7465QG8';

  const RunMapPreview({
    super.key,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return _buildEmptyPlaceholder('No route data');
    }

    final latLngPoints = _parseRoutePoints(points);

    if (latLngPoints.isEmpty) {
      return _buildEmptyPlaceholder('No valid GPS points');
    }

    if (latLngPoints.length < 2) {
      return _buildEmptyPlaceholder('Not enough points for route');
    }

    // Use Google Maps Static API for actual map tiles
    final staticMapUrl = _buildStaticMapUrl(latLngPoints);

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        staticMapUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 200,
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
          debugPrint('Static map error: $error');
          return _buildEmptyPlaceholder('Map unavailable');
        },
      ),
    );
  }

  String _buildStaticMapUrl(List<LatLng> routePoints) {
    // Calculate center and bounds
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

    // Build encoded polyline path
    final encodedPath = _encodePolyline(routePoints);

    // Build the Static Maps API URL
    final url = StringBuffer('https://maps.googleapis.com/maps/api/staticmap?');
    url.write('center=$centerLat,$centerLng');
    url.write('&size=600x300');
    url.write('&scale=2');
    url.write('&maptype=roadmap');

    // Add path with encoded polyline
    url.write('&path=color:0x4285F4FF|weight:4|enc:$encodedPath');

    // Add start marker (green)
    url.write('&markers=color:green|size:small|${routePoints.first.latitude},${routePoints.first.longitude}');

    // Add end marker (red)
    url.write('&markers=color:red|size:small|${routePoints.last.latitude},${routePoints.last.longitude}');

    url.write('&key=$_apiKey');

    return url.toString();
  }

  /// Encode a list of LatLng points into Google's polyline encoding format
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

  List<LatLng> _parseRoutePoints(List<dynamic> rawPoints) {
    final validPoints = <LatLng>[];

    for (final point in rawPoints) {
      try {
        double? lat;
        double? lng;

        if (point is Map) {
          lat = _toDouble(point['lat'] ?? point['latitude']);
          lng = _toDouble(point['lng'] ?? point['longitude']);
        } else if (point is List && point.length >= 2) {
          lat = _toDouble(point[0]);
          lng = _toDouble(point[1]);
        } else if (point is LatLng) {
          validPoints.add(point);
          continue;
        }

        if (lat != null && lng != null) {
          if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
            validPoints.add(LatLng(lat, lng));
          }
        }
      } catch (e) {
        // Skip invalid points silently
      }
    }

    return validPoints;
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Widget _buildEmptyPlaceholder(String message) {
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
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
