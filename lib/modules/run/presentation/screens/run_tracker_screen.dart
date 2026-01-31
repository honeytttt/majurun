import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:majurun/modules/run/controllers/run_controller.dart';
import 'package:majurun/modules/run/presentation/screens/run_history_screen.dart';
import 'package:majurun/modules/run/presentation/screens/last_activity_screen.dart';
import 'package:majurun/modules/run/presentation/screens/run_summary_screen.dart'; // Added
import 'package:majurun/modules/training/presentation/widgets/training_drawer.dart';

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
        // Dynamic pulse speed based on BPM
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
                _buildFooter(context),
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
    bool isIdle = controller.state == RunState.idle;
    bool isStopped = controller.state == RunState.stopped;

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
            // PRIMARY BUTTON: Start / Pause / Resume
            if (!isStopped) 
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: controller.state == RunState.running
                      ? Colors.orange
                      : controller.state == RunState.paused
                          ? Colors.blue
                          : Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  if (isIdle) {
                    controller.startRun();
                  } else if (controller.state == RunState.running) {
                    controller.pauseRun();
                  } else if (controller.state == RunState.paused) {
                    controller.resumeRun();
                  }
                },
                child: Text(
                  controller.state == RunState.running ? "PAUSE" : (isIdle ? "START" : "RESUME"),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                ),
              ),
            
            // SECONDARY BUTTON: Stop or View Summary
            if (!isIdle) ...[
              const SizedBox(width: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isStopped ? Colors.black : Colors.red.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  if (isStopped) {
                    // Navigate to Summary manually if auto-nav fails
                    Navigator.push(context, MaterialPageRoute(builder: (_) => RunSummaryScreen(controller: controller)));
                  } else {
                    await controller.stopRun(context);
                    // Automatic transition to summary
                    if (context.mounted) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => RunSummaryScreen(controller: controller)));
                    }
                  }
                },
                child: Text(
                  isStopped ? "SUMMARY" : "STOP",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                ),
              ),
            ],
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

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton(
          onPressed: () => _handleLastActivity(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bolt, color: Colors.amber),
              SizedBox(width: 8),
              Text("VIEW LAST ACTIVITY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleLastActivity(BuildContext context) async {
    showDialog(context: context, builder: (_) => const Center(child: CircularProgressIndicator()), barrierDismissible: false);
    try {
      final runController = Provider.of<RunController>(context, listen: false);
      final lastRun = await runController.getLastActivity();
      if (context.mounted) {
        Navigator.pop(context);
        if (lastRun != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => LastActivityScreen(lastRun: lastRun)));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No activities found yet!")));
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
    }
  }
}