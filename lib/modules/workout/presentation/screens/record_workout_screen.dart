import 'dart:async';
import 'package:flutter/material.dart';
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
  final String _selectedType = "Run";

  void _toggleTracking() {
    setState(() {
      if (_isTracking) {
        _timer?.cancel();
      } else {
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _seconds++;
            // Simulating distance for now - replace with Geolocator logic later
            _distance += 0.002; 
          });
        });
      }
      _isTracking = !_isTracking;
    });
  }

  void _finishWorkout() {
    _timer?.cancel();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WorkoutSummaryScreen(
          distance: _distance,
          duration: Duration(seconds: _seconds),
          type: _selectedType,
        ),
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    final hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
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
      appBar: AppBar(title: const Text("Record Activity")),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_selectedType, style: const TextStyle(fontSize: 24, color: Colors.grey)),
          const SizedBox(height: 20),
          Text(_formatTime(_seconds), 
            style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, fontFamily: 'Courier')),
          Text("${_distance.toStringAsFixed(2)} km", style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 50),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // START / PAUSE BUTTON
              FloatingActionButton.large(
                onPressed: _toggleTracking,
                backgroundColor: _isTracking ? Colors.orange : Colors.green,
                child: Icon(_isTracking ? Icons.pause : Icons.play_arrow),
              ),
              // FINISH BUTTON (Only show if we have some data)
              if (_seconds > 0)
                FloatingActionButton.large(
                  onPressed: _finishWorkout,
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.stop),
                ),
            ],
          ),
        ],
      ),
    );
  }
}