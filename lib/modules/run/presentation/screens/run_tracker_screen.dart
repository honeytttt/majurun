import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:majurun/modules/run/controllers/run_state_controller.dart';
import 'package:majurun/modules/run/controllers/voice_controller.dart';
import 'package:majurun/modules/run/controllers/stats_controller.dart';
import 'package:majurun/modules/run/presentation/screens/run_history_screen.dart';
import 'package:majurun/modules/run/presentation/screens/last_activity_screen.dart';
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
    return Consumer<RunStateController>(
      builder: (context, stateController, child) {
        // Faster pulse when running + higher BPM
        if (stateController.state == RunState.running) {
          double speedFactor = (stateController.currentBpm / 80).clamp(0.8, 2.5);
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
                _buildHeader(context),
                const Spacer(flex: 1),
                _buildControlCenter(context, stateController),
                const Spacer(flex: 1),
                _buildLiveMetrics(stateController),
                const Spacer(flex: 1),
                _buildStatsGrid(stateController),
                const Spacer(flex: 2),
                _buildFooter(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final voiceController = Provider.of<VoiceController>(context);

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
              voiceController.isVoiceEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: voiceController.isVoiceEnabled ? Colors.blue.shade700 : Colors.grey.shade600,
            ),
            tooltip: voiceController.isVoiceEnabled ? 'Voice ON' : 'Voice OFF',
            onPressed: voiceController.toggleVoice,
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

  Widget _buildControlCenter(BuildContext context, RunStateController stateController) {
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
            color: stateController.state == RunState.running ? Colors.green.shade700 : Colors.grey.shade800,
            size: 64,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Primary button (START / PAUSE / RESUME)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: stateController.state == RunState.running
                    ? Colors.orange
                    : stateController.state == RunState.paused
                        ? Colors.blue
                        : Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                if (stateController.state == RunState.idle) {
                  stateController.startRun();
                } else if (stateController.state == RunState.running) {
                  stateController.pauseRun();
                } else if (stateController.state == RunState.paused) {
                  stateController.resumeRun();
                }
              },
              child: Text(
                stateController.state == RunState.running
                    ? "PAUSE"
                    : stateController.state == RunState.paused
                        ? "RESUME"
                        : "START",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 20),
            // STOP button – only visible when running or paused
            if (stateController.state != RunState.idle)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => stateController.stopRun(context),
                child: const Text(
                  "STOP",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildLiveMetrics(RunStateController stateController) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _metricItem("DISTANCE", "${stateController.distanceString} KM"),
        _metricItem("PACE", stateController.paceString),
        _metricItem("TIME", stateController.durationString),
        _metricItem("BPM", "${stateController.currentBpm}"),
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

  Widget _buildStatsGrid(RunStateController stateController) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _smallStat("TOTAL KM", stateController.historyDistance.toStringAsFixed(1)),
          _smallStat("STREAK", "${stateController.runStreak}D"),
          _smallStat("CALORIES", "${stateController.totalCalories}"),
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
          onPressed: () async {
            showDialog(
              context: context,
              builder: (_) => const Center(child: CircularProgressIndicator()),
              barrierDismissible: false,
            );

            try {
              final statsController = Provider.of<StatsController>(context, listen: false);
              final lastRun = await statsController.getLastActivity();

              if (context.mounted) {
                Navigator.pop(context);

                if (lastRun != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LastActivityScreen(lastRun: lastRun),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("No activities found yet!"),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            } catch (e) {
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Error: ${e.toString()}"),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bolt, color: Colors.amber),
              SizedBox(width: 8),
              Text(
                "VIEW LAST ACTIVITY",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}