import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/services/watch_sync_service.dart';
import 'workout_summary_screen.dart';

class RecordWorkoutScreen extends StatefulWidget {
  const RecordWorkoutScreen({super.key});

  @override
  State<RecordWorkoutScreen> createState() => _RecordWorkoutScreenState();
}

class _RecordWorkoutScreenState extends State<RecordWorkoutScreen> {
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
    
    _syncToWatch();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
        // Simulate running progress
        _distance += 0.002; 
      });
      _syncToWatch();
    });
  }

  void _syncToWatch() {
    try {
      context.read<WatchSyncService>().updateStats(
        _distance, 
        _formattedTime, 
        _isTracking
      );
    } catch (e) {
      // Handle cases where WatchSyncService might not be provided
      debugPrint("Watch sync failed: $e");
    }
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
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "CURRENT DISTANCE", 
              style: TextStyle(color: Colors.grey, letterSpacing: 1.5, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 10),
            Text(
              "${_distance.toStringAsFixed(2)} km",
              style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w900, color: Colors.green),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatColumn("TIME", _formattedTime),
                Container(width: 1, height: 40, color: Colors.grey[300], margin: const EdgeInsets.symmetric(horizontal: 40)),
                _buildStatColumn("CALORIES", "${(_distance * 60).toInt()} kcal"),
              ],
            ),
            const SizedBox(height: 80),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
      ],
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Stop/Finish Button
        if (_seconds > 0)
          FloatingActionButton.extended(
            heroTag: "stop",
            backgroundColor: Colors.redAccent,
            onPressed: () {
              _timer?.cancel();
              // FIX: Ensure parameter names match workout_summary_screen.dart
              Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => WorkoutSummaryScreen(
      distance: _distance, // Changed from totalDistance to distance
      duration: Duration(seconds: _seconds),
    ),
  ),
);
            },
            label: const Text("FINISH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            icon: const Icon(Icons.stop, color: Colors.white),
          ),
          
        // Play/Pause Button
        FloatingActionButton.large(
          heroTag: "play",
          backgroundColor: Colors.black,
          onPressed: _toggleTracking,
          child: Icon(
            _isTracking ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
            size: 48,
          ),
        ),
      ],
    );
  }
}