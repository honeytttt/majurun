import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Builds Google Maps Static API URLs for web-safe map previews.
///
/// Fixes invalid URL issues (no line breaks in query params) and ensures proper URL encoding.
/// Static Maps supports maptype=hybrid and encoded polylines via path=enc:...
class StaticMapUrl {
  static const String _base = 'https://maps.googleapis.com/maps/api/staticmap';

  /// Returns a static map URL that draws the route using an encoded polyline.
  /// Returns '' if points < 2 or apiKey missing.
  ///
  /// mapType: 'hybrid' (satellite + labels), 'satellite', 'roadmap', 'terrain'
  static String build({
    required List<LatLng> points,
    required String apiKey,
    int width = 640,
    int height = 320,
    int scale = 2,
    String mapType = 'hybrid',
    String color = '0x4285F4ff',
    int weight = 5,
  }) {
    if (points.length < 2 || apiKey.isEmpty) return '';

    final encoded = _encodePolyline(points);

    // Build values then URL-encode each param value.
    final pathValue = 'weight:$weight|color:$color|enc:$encoded';

    final start = points.first;
    final end = points.last;

    final markerStart = 'color:green|label:S|${start.latitude},${start.longitude}';
    final markerEnd = 'color:red|label:E|${end.latitude},${end.longitude}';

    return '$_base'
        '?size=${width}x$height'
        '&scale=$scale'
        '&maptype=$mapType'
        '&path=${Uri.encodeComponent(pathValue)}'
        '&markers=${Uri.encodeComponent(markerStart)}'
        '&markers=${Uri.encodeComponent(markerEnd)}'
        '&key=$apiKey';
  }

  /// Encoded polyline algorithm (Google).
  static String _encodePolyline(List<LatLng> points) {
    int lastLat = 0;
    int lastLng = 0;
    final result = StringBuffer();

    for (final p in points) {
      final lat = (p.latitude * 1e5).round();
      final lng = (p.longitude * 1e5).round();

      final dLat = lat - lastLat;
      final dLng = lng - lastLng;

      _encodeValue(dLat, result);
      _encodeValue(dLng, result);

      lastLat = lat;
      lastLng = lng;
    }
    return result.toString();
  }

  static void _encodeValue(int value, StringBuffer out) {
    var v = value < 0 ? ~(value << 1) : (value << 1);
    while (v >= 0x20) {
      out.writeCharCode((0x20 | (v & 0x1f)) + 63);
      v >>= 5;
    }
    out.writeCharCode(v + 63);
  }
}