import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  final String planTitle;
  final VoidCallback? onCancel;

  const ActiveWorkoutScreen({
    super.key,
    required this.planTitle,
    this.onCancel,
  });

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  bool isRunning = false;
  bool canPause = false;
  bool canStop = false;

  StreamSubscription<Position>? _positionStream;
  final List<LatLng> workoutPoints = [];

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text(widget.planTitle),
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () {
          widget.onCancel?.call();
          Navigator.pop(context);
        },
      ),
    ),
    body: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // RUNNING STATUS
        if (isRunning)
          const Icon(
            Icons.directions_run,
            size: 64,
            color: Colors.green,
          )
        else
          const Icon(
            Icons.pause_circle_outline,
            size: 64,
            color: Colors.grey,
          ),

        const SizedBox(height: 24),

        // CONTROL BUTTONS
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // RUN
            IconButton(
              iconSize: 48,
              color: Colors.green,
              icon: const Icon(Icons.play_arrow),
              onPressed: isRunning ? null : startRun,
            ),

            const SizedBox(width: 24),

            // PAUSE
            IconButton(
              iconSize: 48,
              color: Colors.orange,
              icon: const Icon(Icons.pause),
              onPressed: canPause ? pauseWorkout : null,
            ),

            const SizedBox(width: 24),

            // STOP
            IconButton(
              iconSize: 48,
              color: Colors.red,
              icon: const Icon(Icons.stop),
              onPressed: canStop ? stopWorkout : null,
            ),
          ],
        ),

        const SizedBox(height: 32),

        Text(
          'GPS points: ${workoutPoints.length}',
          style: const TextStyle(fontSize: 14),
        ),
      ],
    ),
  );
}


  // =========================
  // START RUN
  // =========================
  Future<void> startRun() async {
    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) {
      if (!mounted) return;
      _showMessage('Location permission required');
      return;
    }

    setState(() {
      isRunning = true;
      canPause = true;
      canStop = true;
    });

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5,
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen(
      (position) {
        workoutPoints.add(
          LatLng(position.latitude, position.longitude),
        );
      },
      onError: (_) {
        _showMessage('GPS error occurred');
      },
    );
  }

  // =========================
  // PAUSE
  // =========================
  void pauseWorkout() {
    _positionStream?.pause();

    setState(() {
      isRunning = false;
      canPause = false;
    });

    _showMessage('Workout paused');
  }

  // =========================
  // STOP
  // =========================
  Future<void> stopWorkout() async {
    await _positionStream?.cancel();
    _positionStream = null;

    setState(() {
      isRunning = false;
      canPause = false;
      canStop = false;
    });

    _showMessage('Workout stopped');
    workoutPoints.clear();
  }

  // =========================
  // PERMISSIONS
  // =========================
  Future<bool> _handleLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  // =========================
  // UI MESSAGE
  // =========================
  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

// =========================
// LAT LNG MODEL
// =========================
class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);
}
