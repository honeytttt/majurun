import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// FIX: Using full package path to ensure the correct RunController is used
import 'package:majurun/modules/run/controllers/run_controller.dart';
import 'package:majurun/modules/run/presentation/screens/run_history_screen.dart';
import 'package:majurun/modules/run/presentation/screens/run_summary_screen.dart';
import 'package:majurun/modules/training/presentation/widgets/training_drawer.dart';

class RunTrackerScreen extends StatefulWidget {
  const RunTrackerScreen({super.key});

  @override
  State<RunTrackerScreen> createState() => _RunTrackerScreenState();
}

class _RunTrackerScreenState extends State<RunTrackerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _heartController;
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
        _heartController.duration = Duration(milliseconds: (800 / speedFactor).round());

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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.psychology, color: Colors.black, size: 28),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text("MAJURUN PRO", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text("Ready to run?", style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          IconButton(
            icon: Icon(
              controller.isVoiceEnabled ? Icons.record_voice_over : Icons.voice_over_off,
              color: controller.isVoiceEnabled ? Colors.blueAccent : Colors.grey,
            ),
            onPressed: () => controller.toggleVoice(),
          ),
        ],
      ),
    );
  }

  Widget _buildControlCenter(BuildContext context, RunController controller) {
    if (controller.state == RunState.idle) {
      return Column(
        children: [
          const Text("TAP TO START", style: TextStyle(letterSpacing: 2, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => controller.startRun(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(30),
            ),
            child: const Icon(Icons.play_arrow, size: 40, color: Colors.white),
          )
        ],
      );
    }

    return Column(
      children: [
        Text("${controller.distanceString} KM", style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900)),
        Text(controller.durationString, style: const TextStyle(fontSize: 24, color: Colors.black54, fontWeight: FontWeight.w300)),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _actionBtn(
              icon: controller.state == RunState.running ? Icons.pause : Icons.play_arrow,
              label: controller.state == RunState.running ? "PAUSE" : "RESUME",
              color: Colors.black,
              onTap: () {
                if (controller.state == RunState.running) {
                  controller.pauseRun();
                } else {
                  controller.resumeRun();
                }
              },
            ),
            const SizedBox(width: 40),
            _actionBtn(
              icon: Icons.stop,
              label: "STOP",
              color: Colors.redAccent,
              onTap: () => _confirmStop(context, controller),
            ),
          ],
        ),
      ],
    );
  }

  void _confirmStop(BuildContext context, RunController controller) {
    showDialog(
      context: context,
      builder: (innerContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Finish Session?"),
        content: const Text("Ready to see your performance stats and AI story?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(innerContext),
            child: const Text("NOT YET", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: const StadiumBorder(),
            ),
            onPressed: () {
              Navigator.pop(innerContext);
              controller.stopRun(context);
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RunSummaryScreen(
                      controller: controller,
                      planTitle: null,
                    ),
                  ),
                );
              }
            },
            child: const Text("FINISH", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveMetrics(RunController controller) {
    if (controller.state == RunState.idle) return const SizedBox(height: 80);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: Tween(begin: 0.9, end: 1.2).animate(_heartController),
              child: const Icon(Icons.favorite, color: Colors.red, size: 28),
            ),
            const SizedBox(width: 12),
            Text(
              "${controller.currentBpm}",
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const Text(" BPM", style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          "CURRENT PACE: ${controller.paceString}",
          style: const TextStyle(letterSpacing: 1, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(RunController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _statBox("AVG PACE", controller.paceString),
          _statBox("CALORIES", "${controller.totalCalories}"),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color == Colors.black ? Colors.black : Colors.transparent,
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(
              icon,
              color: color == Colors.black ? Colors.white : color,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const RunHistoryScreen()));
        },
        child: const Text(
          "VIEW HISTORY",
          style: TextStyle(
            color: Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}