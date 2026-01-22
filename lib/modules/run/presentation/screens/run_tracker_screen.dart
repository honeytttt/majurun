import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../controllers/run_controller.dart';
import '../../domain/entities/run_activity.dart';
import 'run_history_screen.dart';

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
    
    // Using addPostFrameCallback ensures the widget tree (and Provider) 
    // is built before we try to access the controller.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkSummary();
    });
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  void _checkSummary() async {
    // We access the provider through the primary context now that it's initialized
    try {
      final controller = Provider.of<RunController>(context, listen: false);
      final summary = await controller.checkMonthlySummary();
      if (summary != null && mounted) {
        _showSummaryDialog(summary, controller);
      }
    } catch (e) {
      debugPrint("Summary check skipped: Provider not yet available.");
    }
  }

  void _showSummaryDialog(Map<String, dynamic> summary, RunController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("🏆", style: TextStyle(fontSize: 40)),
            const SizedBox(height: 10),
            Text("${summary['monthName']} Recap", 
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Divider(height: 30),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _summaryStat("KM", summary['distance']),
              _summaryStat("Runs", summary['runs'].toString()),
            ]),
            const SizedBox(height: 30),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              icon: const Icon(Icons.share, color: Colors.white, size: 18),
              label: const Text("SHARE TO FEED", style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              onPressed: () { 
                controller.shareSummaryToFeed(summary); 
                Navigator.pop(context); 
              },
            )),
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text("CLOSE", style: TextStyle(color: Colors.grey))
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryStat(String label, String value) {
    return Column(children: [
      Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RunController(),
      child: Builder(
        builder: (innerContext) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Consumer<RunController>(
              builder: (context, controller, child) {
                double speedFactor = (controller.currentBpm / 70).clamp(1.0, 3.0);
                _heartController.duration = Duration(milliseconds: (800 / speedFactor).round());

                return SafeArea(
                  child: Column(
                    children: [
                      _buildHeader(controller),
                      const Spacer(flex: 1),
                      _buildControlCenter(context, controller),
                      const Spacer(flex: 1),
                      _buildLiveMetics(controller),
                      const Spacer(flex: 1),
                      _buildStatsGrid(controller),
                      const Spacer(flex: 2),
                      _buildFooter(context, controller),
                    ],
                  ),
                );
              },
            ),
          );
        }
      ),
    );
  }

  Widget _buildLiveMetics(RunController controller) {
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
            Text("${controller.currentBpm}", 
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const Text(" BPM", style: TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 15),
        if (controller.averageSpeedMs > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: (controller.totalDistance >= controller.ghostDistance) 
                  ? Colors.green.withAlpha(25) 
                  : Colors.red.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              (controller.totalDistance >= controller.ghostDistance) ? "Ahead of Ghost" : "Behind Ghost",
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                color: (controller.totalDistance >= controller.ghostDistance) ? Colors.green : Colors.red
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader(RunController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("PRO", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
          IconButton(
            icon: Icon(
              controller.isVoiceEnabled ? Icons.volume_up : Icons.volume_off,
              color: controller.isVoiceEnabled ? Colors.black : Colors.grey,
            ),
            onPressed: () => controller.toggleVoice(),
          ),
        ],
      ),
    );
  }

  Widget _buildControlCenter(BuildContext context, RunController controller) {
    if (controller.state == RunState.idle) {
      return GestureDetector(
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
                  )),
                Container(color: Colors.white.withAlpha(75),
                  child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text("start", style: TextStyle(fontSize: 18)),
                    Text("RUN", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ])),
              ],
            ),
          ),
        ),
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

  void _confirmStop(BuildContext context, RunController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Finish Run?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () { 
              Navigator.pop(context); 
              controller.stopRun(context); 
            },
            child: const Text("FINISH"),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(RunController controller) {
    String streakValue = "${controller.runStreak} DAYS";
    if (controller.runStreak >= 3) streakValue += " 🔥";
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _statBox("Total Time", controller.totalHistoryTimeStr),
            _statBox("Total KM", controller.historyDistance.toStringAsFixed(0)),
          ]),
          const SizedBox(height: 40),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _statBox("Streak", streakValue),
            _statBox("Total Calories", controller.totalCalories.toString()),
          ]),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value) {
    return SizedBox(width: 120, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChangeNotifierProvider.value(
                  value: controller,
                  child: const RunHistoryScreen(),
                ),
              ),
            );
          },
          child: const Text("All running activities", 
            style: TextStyle(color: Colors.black, fontSize: 16, decoration: TextDecoration.underline)),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}