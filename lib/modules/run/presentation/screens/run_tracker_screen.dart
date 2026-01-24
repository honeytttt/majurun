import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800)
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkSummary();
    });
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  void _checkSummary() {
    try {
      final controller = Provider.of<RunController>(context, listen: false);
      controller.checkMonthlySummary();
    } catch (e) {
      debugPrint("Summary check skipped: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RunController>();
    
    // FIX: Updated withValues for modern Flutter API
    final bgColor = (controller.temp != null && controller.temp! > 25)
        ? Colors.orange.withValues(alpha: 0.05)
        : Colors.white;

    double speedFactor = (controller.currentBpm / 70).clamp(1.0, 3.0);
    _heartController.duration = Duration(milliseconds: (800 / speedFactor).round());

    return Scaffold(
      backgroundColor: bgColor,
      drawer: const TrainingDrawer(),
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
  }

  Widget _buildHeader(RunController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Builder(builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          )),
          Column(
            children: [
              const Text("MAJURUN PRO", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (controller.temp != null)
                Text("${controller.temp}°C | Sunny", style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
          _buildPreRunToggles(controller),
          const SizedBox(height: 30),
          GestureDetector(
            onTap: () => controller.startRun(),
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 3)),
              child: ClipOval(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (controller.currentLocation != null)
                      Opacity(opacity: 0.5, child: GoogleMap(
                        initialCameraPosition: CameraPosition(target: controller.currentLocation!, zoom: 16),
                        liteModeEnabled: true, myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                      )),
                    // FIX: Updated withValues
                    Container(color: Colors.white.withValues(alpha: 0.3),
                      child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text("start", style: TextStyle(fontSize: 18)),
                        Text("RUN", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      ])),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        if (controller.isNewPB)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(20)),
            child: const Text("🌟 NEW PB!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        Text("${controller.distanceString} KM", style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
        Text(controller.durationString, style: const TextStyle(fontSize: 20, color: Colors.black54)),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _actionBtn(
              icon: controller.state == RunState.running ? Icons.pause : Icons.play_arrow,
              label: controller.state == RunState.running ? "PAUSE" : "RESUME",
              color: Colors.black,
              onTap: () => controller.state == RunState.running ? controller.pauseRun() : controller.resumeRun(),
            ),
            const SizedBox(width: 40),
            _actionBtn(
              icon: Icons.stop, label: "STOP", color: Colors.redAccent,
              onTap: () => _confirmStop(context, controller),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPreRunToggles(RunController controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _proToggle("AI COACH", controller.compareHeartRateVoice, () => controller.toggleHeartRateVoice(!controller.compareHeartRateVoice)),
        const SizedBox(width: 15),
        _proToggle("HR DATA", controller.enableHeartRateTracking, () => controller.toggleHeartRateTracking(!controller.enableHeartRateTracking)),
      ],
    );
  }

  Widget _proToggle(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.black),
        ),
        child: Text(label, style: TextStyle(color: active ? Colors.white : Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _confirmStop(BuildContext context, RunController controller) {
    showDialog(
      context: context,
      builder: (innerContext) => AlertDialog(
        title: const Text("Finish Run?"),
        content: const Text("We'll generate your AI summary and performance graphs."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(innerContext), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(innerContext);
              controller.stopRun(context);
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => RunSummaryScreen(controller: controller),
              ));
            },
            child: const Text("FINISH"),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveMetrics(RunController controller) {
    if (controller.state != RunState.running) return const SizedBox(height: 60);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: Tween(begin: 0.9, end: 1.1).animate(_heartController),
              child: const Icon(Icons.favorite, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 8),
            Text("${controller.currentBpm}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const Text(" BPM", style: TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            // FIX: Updated withValues
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text("Ahead of Ghost", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(RunController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _statBox("Total Time", controller.totalHistoryTimeStr),
            _statBox("Total KM", controller.historyDistance.toStringAsFixed(0)),
          ]),
          const SizedBox(height: 30),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _statBox("Streak", "${controller.runStreak} DAYS 🔥"),
            _statBox("Total Calories", controller.totalCalories.toString()),
          ]),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value) {
    return SizedBox(width: 130, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 14, color: Colors.black54)),
      Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
    ]));
  }

  Widget _actionBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Column(children: [
      GestureDetector(onTap: onTap, child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: 2)),
        child: Icon(icon, color: color, size: 30),
      )),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _buildFooter(BuildContext context, RunController controller) {
    return Column(
      children: [
        TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RunHistoryScreen())),
          child: const Text("All running activities",
            style: TextStyle(color: Colors.black, fontSize: 16, decoration: TextDecoration.underline)),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}