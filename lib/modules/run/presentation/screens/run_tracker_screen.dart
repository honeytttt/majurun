import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:majurun/modules/run/controllers/run_controller.dart';

class RunTrackerScreen extends StatelessWidget {
  final VoidCallback onShowHistory;
  final VoidCallback onOpenDrawer;

  const RunTrackerScreen({
    super.key, 
    required this.onShowHistory,
    required this.onOpenDrawer,
  });

  @override
Widget build(BuildContext context) {
  final controller = context.watch<RunController>();

  return SafeArea(
    child: SingleChildScrollView( // <--- Add this to allow scrolling if height is tight
      child: ConstrainedBox(
        // Ensure the content takes at least the full height of the available screen
        constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - 200), 
        child: IntrinsicHeight(
          child: Column(
            children: [
              _buildHeader(onOpenDrawer, controller),
              const Spacer(),
              _buildStartCircle(context, controller),
              const Spacer(),
              _buildStatsGrid(controller),
              const SizedBox(height: 20),
              _buildBottomLink(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildHeader(VoidCallback openDrawer, RunController controller) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("BASIC", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text("RUNNER", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.menu, size: 30),
            onPressed: openDrawer,
          ),
        ],
      ),
    );
  }

  Widget _buildStartCircle(BuildContext context, RunController controller) {
    return GestureDetector(
      onTap: () => controller.startRun(),
      child: Container(
        height: 200,
        width: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, spreadRadius: 5)
          ],
          border: Border.all(color: Colors.black12, width: 1),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_arrow, size: 50),
              Text("START", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
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

  Widget _buildBottomLink() {
    return TextButton(
      onPressed: onShowHistory,
      child: const Text("All running activities", 
        style: TextStyle(decoration: TextDecoration.underline, color: Colors.black, fontSize: 14)),
    );
  }
}