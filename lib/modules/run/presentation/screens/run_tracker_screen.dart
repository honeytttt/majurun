import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:majurun/modules/run/controllers/run_controller.dart';
import 'package:majurun/modules/run/presentation/screens/run_history_screen.dart';
import 'package:majurun/modules/run/presentation/screens/run_summary_screen.dart';
import 'package:majurun/modules/training/presentation/widgets/training_drawer.dart';

class RunTrackerScreen extends StatefulWidget {
  const RunTrackerScreen({super.key});

  @override
  State<RunTrackerScreen> createState() => _RunTrackerScreenState();
}

class _RunTrackerScreenState extends State<RunTrackerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _heartController;  // rename later if you want, but keep for now
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RunController>(
      builder: (context, controller, child) {
        double speedFactor = (controller.currentBpm / 70).clamp(1.0, 3.0);
        _heartController.duration =
            Duration(milliseconds: (800 / speedFactor).round());

        return Scaffold(
          key: _scaffoldKey,
          drawer: const TrainingDrawer(),
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(controller),
                const Spacer(flex: 1),
                _buildControlCenter(context, controller),
                const Spacer(flex: 1),
                _buildLiveMetrics(controller),
                const Spacer(flex: 1),
                _buildStatsGrid(controller),
                const Spacer(flex: 2),
                _buildFooter(context, controller),
              ],
            ),
          ),
        );
      },
    );
  }

  /// ================= HEADER =================
  Widget _buildHeader(RunController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.history, color: Colors.black),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => RunHistoryScreen(onBack: () => Navigator.pop(context)))),  // Added onBack
          ),
        ],
      ),
    );
  }

  /// ================= CONTROL CENTER =================
  Widget _buildControlCenter(BuildContext context, RunController controller) {
  return Column(
    children: [
      AnimatedBuilder(
        animation: _heartController,
        builder: (_, child) {
          return Transform.scale(
            scale: 1 + (_heartController.value * 0.3),  // same pulsing: 1.0 → 1.3
            child: child,
          );
        },
        child: const Icon(
          Icons.directions_run,             // ← human running symbol
          color: Colors.black,               // neutral color (change to green/red if you prefer)
          size: 60,                          // slightly larger than old heart for better visibility
        ),
      ),
      const SizedBox(height: 20),

      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: controller.state == RunState.running
                  ? Colors.orange
                  : Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
            onPressed: () {
              if (controller.state == RunState.idle) {
                controller.startRun();
              } else if (controller.state == RunState.running) {
                controller.pauseRun();
              } else {
                controller.resumeRun();
              }
            },
            child: Text(
              controller.state == RunState.running
                  ? "PAUSE"
                  : controller.state == RunState.paused
                      ? "RESUME"
                      : "START",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
            onPressed: controller.state == RunState.idle
                ? null
                : () => controller.stopRun(context),
            child: const Text("STOP", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ],
  );
}

  /// ================= LIVE METRICS =================
  Widget _buildLiveMetrics(RunController controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _metricItem("DISTANCE", "${controller.distanceString} KM"),
        _metricItem("PACE", controller.paceString),
        _metricItem("TIME", controller.durationString),
        _metricItem("BPM", "${controller.currentBpm}"),
      ],
    );
  }

  Widget _metricItem(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  /// ================= STATS GRID =================
  Widget _buildStatsGrid(RunController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _smallStat("TOTAL KM", controller.historyDistance.toStringAsFixed(1)),
          _smallStat("STREAK", "${controller.runStreak}D"),
          _smallStat("CALORIES", "${controller.totalCalories}"),
        ],
      ),
    );
  }

  Widget _smallStat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  /// ================= FOOTER =================
  Widget _buildFooter(BuildContext context, RunController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: controller.state == RunState.idle
              ? null
              : () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => RunSummaryScreen(
                                controller: controller,
                              )));
                },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
          child: const Text("VIEW SUMMARY",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}