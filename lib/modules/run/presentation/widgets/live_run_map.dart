import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LiveRunMap extends StatefulWidget {
  final List<LatLng> path;
  const LiveRunMap({super.key, required this.path});

  @override
  State<LiveRunMap> createState() => _LiveRunMapState();
}

class _LiveRunMapState extends State<LiveRunMap> {
  GoogleMapController? _controller;

  @override
  void didUpdateWidget(LiveRunMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.path.isNotEmpty && _controller != null) {
      if (oldWidget.path.isEmpty || widget.path.last != oldWidget.path.last) {
        _controller!.animateCamera(
          CameraUpdate.newLatLng(widget.path.last),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Default location (e.g., Jakarta) if path is empty
    final LatLng initialPosition = widget.path.isNotEmpty 
        ? widget.path.last 
        : const LatLng(-6.2000, 106.8166);

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: initialPosition,
        zoom: 16,
      ),
      onMapCreated: (controller) => _controller = controller,
      polylines: {
        Polyline(
          polylineId: const PolylineId("live_path"),
          points: widget.path,
          color: Colors.blueAccent,
          width: 6,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      },
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
    );
  }
}