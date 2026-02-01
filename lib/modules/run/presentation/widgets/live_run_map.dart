import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:js/js.dart';

// This allows us to check for the 'google' object globally without hasProperty
@JS('google')
external dynamic get googleObject;

class LiveRunMap extends StatelessWidget {
  final Set<Polyline> polylines;
  final CameraPosition initialPosition;
  final Function(GoogleMapController) onMapCreated;

  const LiveRunMap({
    super.key,
    required this.polylines,
    required this.initialPosition,
    required this.onMapCreated,
  });

  bool _isGoogleMapsLoaded() {
    try {
      // If the google object is not null/undefined in JS, this will return true
      return googleObject != null;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Prevent the 'ROADMAP' TypeError by waiting for the SDK
    if (!_isGoogleMapsLoaded()) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blue),
            SizedBox(height: 16),
            Text(
              "Initializing Maps SDK...",
              style: TextStyle(
                color: Colors.grey, 
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return GoogleMap(
      initialCameraPosition: initialPosition,
      polylines: polylines,
      onMapCreated: onMapCreated,
      mapType: MapType.normal,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
    );
  }
}