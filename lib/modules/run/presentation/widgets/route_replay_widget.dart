import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;

/// Animated route replay widget. Takes a list of LatLng route points and
/// shows a GoogleMap with a play/pause/reset control. A marker moves along
/// the route every 50ms, advancing ~10 points per frame for performance.
class RouteReplayWidget extends StatefulWidget {
  final List<LatLng> routePoints;

  const RouteReplayWidget({super.key, required this.routePoints});

  @override
  State<RouteReplayWidget> createState() => _RouteReplayWidgetState();
}

class _RouteReplayWidgetState extends State<RouteReplayWidget> {
  GoogleMapController? _mapController;
  Timer? _timer;
  int _currentIndex = 0;
  bool _isPlaying = false;

  static const int _step = 10;
  static const Duration _frameInterval = Duration(milliseconds: 50);

  LatLng get _currentPosition =>
      widget.routePoints[_currentIndex.clamp(0, widget.routePoints.length - 1)];

  bool get _atEnd => _currentIndex >= widget.routePoints.length - 1;

  double get _progress {
    if (widget.routePoints.length <= 1) return 0;
    return _currentIndex / (widget.routePoints.length - 1);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _play() {
    if (_atEnd) _reset();
    setState(() => _isPlaying = true);
    _timer = Timer.periodic(_frameInterval, (_) {
      if (!mounted) {
        _timer?.cancel();
        return;
      }
      final next = (_currentIndex + _step)
          .clamp(0, widget.routePoints.length - 1);
      setState(() => _currentIndex = next);
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(_currentPosition),
      );
      if (_atEnd) _pause();
    });
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() => _isPlaying = false);
  }

  void _reset() {
    _pause();
    setState(() => _currentIndex = 0);
    if (widget.routePoints.isNotEmpty) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(widget.routePoints.first),
      );
    }
  }

  LatLngBounds _calculateBounds() {
    double south = widget.routePoints.first.latitude;
    double north = widget.routePoints.first.latitude;
    double west = widget.routePoints.first.longitude;
    double east = widget.routePoints.first.longitude;
    for (final p in widget.routePoints) {
      if (p.latitude < south) south = p.latitude;
      if (p.latitude > north) north = p.latitude;
      if (p.longitude < west) west = p.longitude;
      if (p.longitude > east) east = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
  }

  CameraPosition get _initialCamera {
    if (widget.routePoints.isEmpty) {
      return const CameraPosition(target: LatLng(0, 0), zoom: 14);
    }
    final bounds = _calculateBounds();
    final center = LatLng(
      (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
      (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
    );
    final latSpan = bounds.northeast.latitude - bounds.southwest.latitude;
    final lngSpan = bounds.northeast.longitude - bounds.southwest.longitude;
    final maxSpan = math.max(latSpan, lngSpan);
    final zoom = maxSpan > 0
        ? (math.log(0.05 / maxSpan) / math.ln2 + 15).clamp(10.0, 17.0)
        : 14.0;
    return CameraPosition(target: center, zoom: zoom);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.routePoints.length < 2) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        SizedBox(
          height: 300,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GoogleMap(
              initialCameraPosition: _initialCamera,
              onMapCreated: (controller) {
                _mapController = controller;
                // Fit to bounds once map is ready
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted && _mapController != null) {
                    _mapController!.animateCamera(
                      CameraUpdate.newLatLngBounds(_calculateBounds(), 40),
                    );
                  }
                });
              },
              polylines: {
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: widget.routePoints,
                  color: const Color(0xFF00E676).withValues(alpha: 0.6),
                  width: 4,
                  startCap: Cap.roundCap,
                  endCap: Cap.roundCap,
                  jointType: JointType.round,
                ),
                if (_currentIndex > 0)
                  Polyline(
                    polylineId: const PolylineId('replayed'),
                    points: widget.routePoints.sublist(0, _currentIndex + 1),
                    color: const Color(0xFF00E676),
                    width: 5,
                    startCap: Cap.roundCap,
                    endCap: Cap.roundCap,
                    jointType: JointType.round,
                  ),
              },
              markers: {
                Marker(
                  markerId: const MarkerId('start'),
                  position: widget.routePoints.first,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen),
                ),
                Marker(
                  markerId: const MarkerId('end'),
                  position: widget.routePoints.last,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRed),
                ),
                Marker(
                  markerId: const MarkerId('runner'),
                  position: _currentPosition,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueAzure),
                ),
              },
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              myLocationButtonEnabled: false,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Progress slider (read-only during playback, seekable when paused)
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: const Color(0xFF00E676),
            inactiveTrackColor: Colors.white12,
            thumbColor: const Color(0xFF00E676),
            overlayColor: const Color(0xFF00E676).withValues(alpha: 0.15),
            trackHeight: 3,
          ),
          child: Slider(
            value: _progress,
            onChanged: _isPlaying
                ? null
                : (v) {
                    final idx =
                        (v * (widget.routePoints.length - 1)).round();
                    setState(() => _currentIndex = idx);
                    _mapController?.animateCamera(
                      CameraUpdate.newLatLng(_currentPosition),
                    );
                  },
          ),
        ),
        // Controls
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.replay_rounded, color: Colors.white54),
              tooltip: 'Reset',
              onPressed: _reset,
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _isPlaying ? _pause : _play,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E676).withValues(alpha: 0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.black,
                  size: 28,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
