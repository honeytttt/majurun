import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: initialPosition,
      polylines: polylines,
      onMapCreated: onMapCreated,
      mapType: MapType.normal,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      // Remove onMapLoaded — it does not exist
    );
  }
}