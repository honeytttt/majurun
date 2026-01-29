import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:majurun/modules/run/controllers/run_controller.dart';
import 'package:majurun/modules/run/presentation/screens/run_history_screen.dart';
import 'package:majurun/modules/run/presentation/screens/run_summary_screen.dart';
import 'package:majurun/modules/training/presentation/widgets/training_drawer.dart';
//import 'package:majurun/modules/run/services/voice_announcer.dart'; // ← FIXED: Added this import

class RunTrackerScreen extends StatefulWidget {
  const RunTrackerScreen({super.key});

  @override
  State<RunTrackerScreen> createState() => _RunTrackerScreenState();
}

class _RunTrackerScreenState extends State<RunTrackerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RunController>(
      builder: (context, controller, child) {
        // Optional: faster pulse when running + higher BPM
        if (controller.state == RunState.running) {
          double speedFactor = (controller.currentBpm / 80).clamp(0.8, 2.5);
          _pulseController.duration = Duration(milliseconds: (1200 / speedFactor).round());
        } else {
          _pulseController.duration = const Duration(milliseconds: 1200);
        }

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
          icon: Icon(
            controller.isVoiceEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            color: controller.isVoiceEnabled ? Colors.blue.shade700 : Colors.grey.shade600,
          ),
          tooltip: controller.isVoiceEnabled ? 'Voice ON' : 'Voice OFF',
          onPressed: controller.toggleVoice,
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.history, color: Colors.black),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RunHistoryScreen(onBack: () => Navigator.pop(context)),
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildControlCenter(BuildContext context, RunController controller) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (_, child) {
            return Transform.scale(
              scale: 1.0 + (_pulseController.value * 0.25),
              child: child,
            );
          },
          child: Icon(
            Icons.directions_run_rounded,
            color: controller.state == RunState.running ? Colors.green.shade700 : Colors.grey.shade800,
            size: 64,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: controller.state == RunState.running ? Colors.orange : Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(width: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: controller.state == RunState.idle ? null : () => controller.stopRun(context),
              child: const Text("STOP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ],
    );
  }

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
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

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
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

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
                      builder: (_) => RunSummaryScreen(controller: controller),
                    ),
                  );
                },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
          child: const Text("VIEW SUMMARY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}