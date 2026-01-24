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
              mapType: MapType.normal,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(context, training, run),
                const Spacer(),
                Text(training.currentAction.toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4)),
                Text("${training.secondsRemaining}",
                    style: const TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 120,
                        fontWeight: FontWeight.w100)),
                const Spacer(),
                _buildLiveStats(run),
                const SizedBox(height: 20),
                _buildStopButton(context, training, run),
                const SizedBox(height: 40),
              ],
            ),
          ),
          Positioned(
            // Home Close Button
            top: 50,
            right: 20,
            child: CircleAvatar(
              backgroundColor: Colors.white24,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  run.stopRun(context);
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ),
          )
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
        Text(v,
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ]);

  Widget _buildStopButton(
      BuildContext context, TrainingService training, RunController run) {
    return GestureDetector(
      onLongPress: () async {
        // Capture navigator before async gap to avoid 'use_build_context_synchronously'
        final navigator = Navigator.of(context);
        
        training.stop();
        
        // await the run to stop
        await run.stopRun(context, planTitle: widget.planTitle);
        
        // Only navigate if the widget is still in the tree
        if (!mounted) return;
        navigator.pop();
      },
      child: Container(
        height: 70,
        width: 70,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.redAccent, width: 2)),
        child: const Icon(Icons.stop, color: Colors.redAccent, size: 30),
      ),
    );
  }

  Widget _buildTopBar(
      BuildContext context, TrainingService training, RunController run) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(widget.planTitle,
              style: const TextStyle(
                  color: Colors.white70, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}