import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RunMapPreview extends StatefulWidget {
  final List<dynamic> points;

  const RunMapPreview({
    super.key,
    required this.points,
  });

  @override
  State<RunMapPreview> createState() => _RunMapPreviewState();
}

class _RunMapPreviewState extends State<RunMapPreview> {
  GoogleMapController? _mapController;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) {
      return _buildEmptyPlaceholder('No route data');
    }

    final latLngPoints = _parseRoutePoints(widget.points);

    if (latLngPoints.isEmpty) {
      return _buildEmptyPlaceholder('No valid GPS points');
    }

    if (latLngPoints.length < 2) {
      return _buildEmptyPlaceholder('Not enough points for route');
    }

    // Calculate bounds to fit the route nicely
    final bounds = _calculateBounds(latLngPoints);

    final initialPosition = CameraPosition(
      target: LatLng(
        (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
        (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
      ),
      zoom: 13, // reasonable default zoom
    );

    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      child: GoogleMap(
        initialCameraPosition: initialPosition,
        polylines: {
          Polyline(
            polylineId: const PolylineId('route'),
            points: latLngPoints,
            color: const Color(0xFF4285F4),
            width: 5,
            patterns: [PatternItem.dash(20), PatternItem.gap(5)],
          ),
        },
        markers: {
          Marker(
            markerId: const MarkerId('start'),
            position: latLngPoints.first,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: const InfoWindow(title: 'Start'),
          ),
          Marker(
            markerId: const MarkerId('end'),
            position: latLngPoints.last,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: const InfoWindow(title: 'End'),
          ),
        },
        zoomControlsEnabled: true,          // + / - buttons
        zoomGesturesEnabled: true,          // pinch to zoom
        scrollGesturesEnabled: false,       // disable panning (clean preview)
        mapToolbarEnabled: false,
        rotateGesturesEnabled: false,
        tiltGesturesEnabled: false,
        mapType: MapType.normal,
        onMapCreated: (GoogleMapController controller) {
          _mapController = controller;
          // Auto-fit route with padding after map is created
          Future.delayed(const Duration(milliseconds: 400), () {
            _mapController?.animateCamera(
              CameraUpdate.newLatLngBounds(bounds, 60), // 60px padding
            );
          });
        },
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
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
        // Skip invalid points
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