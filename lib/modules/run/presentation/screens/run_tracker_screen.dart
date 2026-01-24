import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:majurun/modules/run/controllers/run_controller.dart';
import 'package:majurun/modules/run/presentation/screens/run_summary_screen.dart';
import 'package:majurun/modules/run/presentation/screens/run_history_screen.dart';
import 'package:majurun/modules/training/presentation/widgets/training_drawer.dart';

class RunTrackerScreen extends StatefulWidget {
  const RunTrackerScreen({super.key});

  @override
  State<RunTrackerScreen> createState() => _RunTrackerScreenState();
}

class _RunTrackerScreenState extends State<RunTrackerScreen> {
  @override
  Widget build(BuildContext context) {
    // Access the current controller state
    final controller = context.watch<RunController>();

    return Scaffold(
      drawer: const TrainingDrawer(),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          children: [
            // PRO/BASIC Toggle Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Basic", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                Switch(
                  value: true, 
                  onChanged: (v) {}, 
                  activeThumbColor: Colors.black,
                  
                ),
                const Text("PRO", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 40),

            // MAIN START BUTTON (The Blueprint Circle)
            Center(
              child: GestureDetector(
                onTap: () {
                  if (controller.state == RunState.idle) {
                    controller.startRun();
                  } else {
                    controller.stopRun(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => RunSummaryScreen(controller: controller)),
                    );
                  }
                },
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: controller.state == RunState.running ? Colors.red : Colors.black, 
                      width: 8
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(controller.state == RunState.running ? "stop" : "start", 
                          style: const TextStyle(fontSize: 18)),
                      const Text("RUN", style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 60),

            // LIFETIME STATS GRID (Fixed variable names)
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                children: [
                  _buildStat("Total Distance", "${controller.historyDistance.toStringAsFixed(1)} KM"),
                  _buildStat("Total Time", controller.durationString), // Simplified for now
                  _buildStat("Total Runs", "${controller.runStreak}"),
                  _buildStat("Calories", "${controller.totalCalories}"),
                ],
              ),
            ),

            // FOOTER LINK
            TextButton(
              onPressed: () => Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => const RunHistoryScreen())
              ),
              child: const Text(
                "All running activities",
                style: TextStyle(
                  color: Colors.black,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      ],
    );
  }
}