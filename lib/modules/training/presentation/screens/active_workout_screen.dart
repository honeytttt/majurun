// lib\modules\training\presentation\screens\active_workout_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/training_service.dart';
import '../../../run/controllers/run_controller.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  final String planTitle;

  const ActiveWorkoutScreen({super.key, required this.planTitle});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  @override
  void initState() {
    super.initState();
    // Start GPS tracking automatically when the coaching session starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RunController>().startRun();
    });
  }

  @override
  Widget build(BuildContext context) {
    final training = context.watch<TrainingService>();
    final run = context.watch<RunController>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Full Background Map (Dimmed)
          Opacity(
            opacity: 0.4,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: run.currentLocation ?? const LatLng(0, 0),
                zoom: 16,
              ),
              polylines: run.polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapType: MapType.normal,
            ),
          ),

          // 2. Coaching UI Overlay
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context, training, run),
                const Spacer(),

                // Active Action (RUN/WALK)
                Text(
                  training.currentAction.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 50,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),

                // Big Timer
                Text(
                  "${training.secondsRemaining}",
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 140,
                    fontWeight: FontWeight.w100,
                  ),
                ),

                const Spacer(),

                // 3. Live Run Stats (Distance/Pace)
                _buildLiveStats(run),

                const SizedBox(height: 40),

                // Stop Button
                _buildStopButton(context, training, run),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, TrainingService training, RunController run) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => _confirmExit(context, training, run),
          ),
          Text(
            widget.planTitle,
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
          ),
          const Icon(Icons.gps_fixed, color: Colors.greenAccent, size: 18),
        ],
      ),
    );
  }

  Widget _buildLiveStats(RunController run) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        border: const Border(top: BorderSide(color: Colors.white10, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _metricColumn("DISTANCE", "${run.distanceString} KM"),
          _metricColumn("CURRENT PACE", run.paceString),
        ],
      ),
    );
  }

  Widget _metricColumn(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildStopButton(BuildContext context, TrainingService training, RunController run) {
    return GestureDetector(
      onLongPress: () async {
  // 1. Stop the coaching voice/timer
  training.stop();

  // 2. Stop GPS and save to database
  await run.stopRun(context, planTitle: widget.planTitle);

  // 3. Return to Run screen
  if (context.mounted) Navigator.pop(context);
},
      child: Container(
        height: 80,
        width: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.redAccent.withValues(alpha: 0.2),
          border: Border.all(color: Colors.redAccent, width: 2),
        ),
        child: const Icon(Icons.stop, color: Colors.redAccent, size: 40),
      ),
    );
  }

  void _confirmExit(BuildContext context, TrainingService training, RunController run) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Quit Workout?"),
        content: const Text("Your progress for this session will not be saved."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("KEEP GOING")),
          TextButton(
            onPressed: () {
              training.stop();
              run.pauseRun(); // Stop GPS
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close screen
            },
            child: const Text("QUIT", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}