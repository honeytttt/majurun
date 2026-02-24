import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:majurun/core/services/map_style_service.dart';

class LiveRunMap extends StatefulWidget {
  final Set<Polyline> polylines;
  final CameraPosition initialPosition;
  final Function(GoogleMapController) onMapCreated;
  final bool useDarkMode;
  final bool useMinimalStyle;

  const LiveRunMap({
    super.key,
    required this.polylines,
    required this.initialPosition,
    required this.onMapCreated,
    this.useDarkMode = false,
    this.useMinimalStyle = false,
  });

  @override
  State<LiveRunMap> createState() => _LiveRunMapState();
}

class _LiveRunMapState extends State<LiveRunMap> {
  GoogleMapController? _controller;

  String get _mapStyle {
    if (widget.useMinimalStyle) return MapStyleService.minimalStyle;
    if (widget.useDarkMode) return MapStyleService.darkStyle;
    return MapStyleService.lightStyle;
  }

  void _onMapCreated(GoogleMapController controller) {
    _controller = controller;
    _controller?.setMapStyle(_mapStyle);
    widget.onMapCreated(controller);
  }

  @override
  void didUpdateWidget(LiveRunMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update style if mode changes
    if (oldWidget.useDarkMode != widget.useDarkMode ||
        oldWidget.useMinimalStyle != widget.useMinimalStyle) {
      _controller?.setMapStyle(_mapStyle);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Enhanced polylines with better visibility
    final enhancedPolylines = widget.polylines.map((polyline) {
      return Polyline(
        polylineId: polyline.polylineId,
        points: polyline.points,
        color: polyline.color,
        width: polyline.width > 0 ? polyline.width : 5,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        patterns: polyline.patterns,
      );
    }).toSet();

    return GoogleMap(
      initialCameraPosition: widget.initialPosition,
      polylines: enhancedPolylines,
      onMapCreated: _onMapCreated,
      mapType: MapType.normal,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      rotateGesturesEnabled: true,
      scrollGesturesEnabled: true,
      tiltGesturesEnabled: false,
      zoomGesturesEnabled: true,
      buildingsEnabled: false,
      trafficEnabled: false,
    );
  }
}

/// A styled map card for displaying run routes in summaries/history
class RunRouteMapCard extends StatelessWidget {
  final List<LatLng> routePoints;
  final double height;
  final BorderRadius? borderRadius;

  const RunRouteMapCard({
    super.key,
    required this.routePoints,
    this.height = 200,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (routePoints.isEmpty) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: borderRadius ?? BorderRadius.circular(16),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text('No route data', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    // Calculate bounds
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

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        child: LiveRunMap(
          initialPosition: CameraPosition(
            target: LatLng(centerLat, centerLng),
            zoom: 14,
          ),
          polylines: {
            Polyline(
              polylineId: const PolylineId('route'),
              points: routePoints,
              color: const Color(0xFF00E676),
              width: 5,
            ),
          },
          onMapCreated: (_) {},
          useMinimalStyle: true,
        ),
      ),
    );
  }
}
