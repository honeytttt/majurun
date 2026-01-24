import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:majurun/modules/run/controllers/run_controller.dart';
import 'package:majurun/modules/run/presentation/screens/run_history_screen.dart';
import 'package:majurun/modules/run/presentation/screens/run_summary_screen.dart';
import 'package:majurun/modules/training/presentation/widgets/training_drawer.dart';

class RunTrackerScreen extends StatelessWidget {
  const RunTrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RunController>();

    return Scaffold(
      drawer: const TrainingDrawer(),
      body: Builder( // FIX: Builder provides child context to see the Scaffold
        builder: (scaffoldContext) {
          return SafeArea(
            child: Column(
              children: [
                _buildHeader(scaffoldContext, controller),
                const Spacer(),
                _buildStartCircle(context, controller),
                const Spacer(),
                _buildStatsGrid(controller),
                const SizedBox(height: 40),
                _buildBottomLink(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, RunController controller) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _headerItem("Training", "Menu", Icons.menu, () => Scaffold.of(context).openDrawer()),
          const Column(children: [
            Text("BASIC   PRO", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
            Text("AI Coach", style: TextStyle(color: Colors.grey, fontSize: 10)),
          ]),
          Row( // Separated Notification and Voice buttons
            children: [
              _headerItem("Notif", controller.isNotificationEnabled ? "On" : "Off", 
                Icons.notifications_active, () => controller.toggleNotifications()),
              const SizedBox(width: 15),
              _headerItem("Voice", controller.isVoiceEnabled ? "On" : "Off", 
                controller.isVoiceEnabled ? Icons.volume_up : Icons.volume_off, () => controller.toggleVoice()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerItem(String t1, String t2, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(t1, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          Text(t2, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          Icon(icon, size: 20),
        ],
      ),
    );
  }

  Widget _buildStartCircle(BuildContext context, RunController controller) {
    bool isRunning = controller.state == RunState.running;
    return GestureDetector(
      onTap: () {
        if (isRunning) {
          controller.stopRun(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => RunSummaryScreen(controller: controller)));
        } else {
          controller.startRun();
        }
      },
      child: Container(
        width: 180, height: 180,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(width: 4)),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(isRunning ? "stop" : "start"),
              Text(isRunning ? controller.durationString : "RUN", 
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(RunController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _stat("Total Time", controller.totalHistoryTimeStr),
            _stat("Total KM", controller.historyDistance.toStringAsFixed(0)),
          ]),
          const SizedBox(height: 30),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _stat("total runs", controller.totalRuns.toString()),
            _stat("Total Calories", controller.totalCalories.toString()),
          ]),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => SizedBox(width: 100, child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    ],
  ));

  Widget _buildBottomLink(BuildContext context) {
    return TextButton(
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RunHistoryScreen())),
      child: const Text("All running activities", style: TextStyle(decoration: TextDecoration.underline, color: Colors.black)),
    );
  }
}