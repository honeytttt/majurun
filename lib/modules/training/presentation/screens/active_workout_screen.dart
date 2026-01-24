import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:majurun/modules/training/services/training_service.dart';
import 'package:majurun/modules/run/controllers/run_controller.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  final String planTitle;
  final VoidCallback onCancel;

  const ActiveWorkoutScreen({
    super.key,
    required this.planTitle,
    required this.onCancel,
  });

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

  void _showExitConfirmation(BuildContext context, TrainingService training, RunController run) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Quit Workout?"),
        content: const Text("Your current progress will be lost."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("RESUME"),
          ),
          TextButton(
            onPressed: () {
              training.stop();
              run.resetRun(); 
              Navigator.pop(dialogContext); // Close Dialog
              widget.onCancel(); // Quit the sub-page
            },
            child: const Text("QUIT", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final training = context.watch<TrainingService>();
    final run = context.watch<RunController>();

    return Stack(
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
            mapType: MapType.normal,
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              _buildTopBar(context, training, run),
              const Spacer(),
              Text(training.currentAction.toUpperCase(),
                  style: const TextStyle(color: Colors.black, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 4)),
              Text("${training.secondsRemaining}",
                  style: const TextStyle(color: Colors.blueAccent, fontSize: 100, fontWeight: FontWeight.w100)),
              const Spacer(),
              _buildLiveStats(run),
              const SizedBox(height: 20),
              _buildStopButton(context, training, run),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context, TrainingService training, RunController run) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => _showExitConfirmation(context, training, run),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.black, size: 22),
            ),
          ),
          Text(widget.planTitle, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildLiveStats(RunController run) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _metric("DISTANCE", "${run.distanceString} KM"),
        _metric("PACE", run.paceString),
      ],
    );
  }

  Widget _metric(String l, String v) => Column(children: [
        Text(l, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        Text(v, style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
      ]);

  Widget _buildStopButton(BuildContext context, TrainingService training, RunController run) {
    return Column(
      children: [
        const Text("LONG PRESS TO FINISH", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        GestureDetector(
          onLongPress: () async {
            training.stop();
            await run.stopRun(context, planTitle: widget.planTitle);
            widget.onCancel(); 
          },
          child: Container(
            height: 70, width: 70,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.redAccent, width: 2)),
            child: const Icon(Icons.stop, color: Colors.redAccent, size: 30),
          ),
        ),
      ],
    );
  }
}