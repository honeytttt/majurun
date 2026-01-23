import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:majurun/modules/training/services/training_service.dart';
import 'package:majurun/modules/run/controllers/run_controller.dart';

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
              // FIX: MapType.dark is not an enum constant. Use .normal
              mapType: MapType.normal, 
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context, training, run),
                const Spacer(),
                Text(
                  training.currentAction.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 50,
                    // FIX: FontWeight.black doesn't exist. Use w900
                    fontWeight: FontWeight.w900, 
                    letterSpacing: 4,
                  ),
                ),
                Text(
                  "${training.secondsRemaining}",
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 140,
                    fontWeight: FontWeight.w100,
                  ),
                ),
                const Spacer(),
                _buildLiveStats(run),
                const SizedBox(height: 40),
                _buildStopButton(context, training, run),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStats(RunController run) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      width: double.infinity,
      decoration: BoxDecoration(
        // FIX: Use withValues instead of deprecated withOpacity
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
        training.stop();
        await run.stopRun(context, planTitle: widget.planTitle);
        if (context.mounted) Navigator.pop(context);
      },
      child: Container(
        height: 80,
        width: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // FIX: Use withValues
          color: Colors.redAccent.withValues(alpha: 0.2), 
          border: Border.all(color: Colors.redAccent, width: 2),
        ),
        child: const Icon(Icons.stop, color: Colors.redAccent, size: 40),
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
              run.pauseRun();
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("QUIT", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}