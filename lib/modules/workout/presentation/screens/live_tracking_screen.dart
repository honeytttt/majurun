import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/services/watch_sync_service.dart';
import 'workout_summary_screen.dart';

class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  Timer? _timer;
  int _seconds = 0;
  double _distance = 0.0;
  bool _isTracking = false;

  void _toggleTracking() {
    setState(() {
      _isTracking = !_isTracking;
    });

    if (_isTracking) {
      _startTimer();
    } else {
      _timer?.cancel();
    }
    
    // Initial sync update
    _syncToWatch();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
        // Simulate running 2 meters every second (approx 7.2 km/h)
        _distance += 0.002; 
      });
      _syncToWatch();
    });
  }

  void _syncToWatch() {
    // Pushes the current phone state to the watch service
    context.read<WatchSyncService>().updateStats(
      _distance, 
      _formattedTime, 
      _isTracking
    );
  }

  String get _formattedTime {
    final hours = (_seconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((_seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (_seconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$seconds";
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("CURRENT DISTANCE", style: TextStyle(color: Colors.grey, letterSpacing: 1.5)),
            Text(
              "${_distance.toStringAsFixed(2)} km",
              style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: Colors.green),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatColumn("TIME", _formattedTime),
                const SizedBox(width: 40),
                _buildStatColumn("CALORIES", "${(_distance * 60).toInt()} kcal"),
              ],
            ),
            const SizedBox(height: 60),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Stop Button
        if (_seconds > 0)
          FloatingActionButton(
            heroTag: "stop",
            backgroundColor: Colors.redAccent,
            onPressed: () {
              _timer?.cancel();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WorkoutSummaryScreen(
                    distance: _distance,
                    duration: Duration(seconds: _seconds),
                  ),
                ),
              );
            },
            child: const Icon(Icons.stop, color: Colors.white),
          ),
        // Play/Pause Button
        FloatingActionButton.large(
          heroTag: "play",
          backgroundColor: Colors.green,
          onPressed: _toggleTracking,
          child: Icon(
            _isTracking ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
            size: 40,
          ),
        ),
      ],
    );
  }
}