import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class BackgroundMapWidget extends StatelessWidget {
  final LatLng? center;
  final List<LatLng>? routePoints;
  final double opacity;
  final Widget child;

  const BackgroundMapWidget({
    super.key,
    this.center,
    this.routePoints,
    this.opacity = 0.3,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Default center (use user's location or a default)
    final mapCenter = center ?? const LatLng(37.7749, -122.4194); // San Francisco default

    return Stack(
      children: [
        // Background map layer
        Positioned.fill(
          child: Opacity(
            opacity: opacity,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: mapCenter,
                zoom: 13,
              ),
              polylines: routePoints != null && routePoints!.isNotEmpty
                  ? {
                      Polyline(
                        polylineId: const PolylineId('route'),
                        points: routePoints!,
                        color: const Color(0xFF2D7A3E).withValues(alpha: 0.6), // Green
                        width: 4,
                      ),
                    }
                  : {},
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: false,
              rotateGesturesEnabled: false,
              scrollGesturesEnabled: false,
              tiltGesturesEnabled: false,
              zoomGesturesEnabled: false,
              mapType: MapType.normal,
              liteModeEnabled: true, // Performance optimization
            ),
          ),
        ),
        
        // Gradient overlay for better text readability
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.9),
                  Colors.white.withValues(alpha: 0.7),
                  Colors.white.withValues(alpha: 0.9),
                ],
              ),
            ),
          ),
        ),
        
        // Content on top
        child,
      ],
    );
  }
}

// Usage Example:
/*
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundMapWidget(
        center: LatLng(37.7749, -122.4194),
        routePoints: lastRunRoute, // Optional: show last run
        opacity: 0.2, // Very subtle
        child: YourHomeScreenContent(),
      ),
    );
  }
}

class RunScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundMapWidget(
        center: currentLocation,
        routePoints: activeRoutePoints,
        opacity: 0.4, // More visible during run
        child: YourRunScreenContent(),
      ),
    );
  }
}
*/