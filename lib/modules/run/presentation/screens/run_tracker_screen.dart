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

class _RunTrackerScreenState extends State<RunTrackerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Provider.of<RunController>(context, listen: false).checkMonthlySummary();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RunController>();

    return Scaffold(
      drawer: const TrainingDrawer(),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            colors: [Colors.white, Colors.blue.withValues(alpha: 0.05)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              const Spacer(flex: 1),
              _buildControlCenter(context, controller),
              const Spacer(flex: 1),
              _buildMetrics(controller),
              const Spacer(flex: 2),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Builder(builder: (context) => IconButton(
            icon: const Icon(Icons.menu, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          )),
          const Text("MAJURUN PRO", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.redAccent, size: 28),
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
    );
  }

  Widget _buildControlCenter(BuildContext context, RunController controller) {
    bool isRunning = controller.state == RunState.running;
    bool isPaused = controller.state == RunState.paused;

    return Column(
      children: [
        if (controller.state == RunState.idle) _buildMotivationalReminder(controller),
        const SizedBox(height: 20),
        ScaleTransition(
          scale: Tween(begin: 1.0, end: 1.05).animate(_pulseController),
          child: GestureDetector(
            onTap: () {
              if (controller.state == RunState.idle) {
                controller.startRun();
              } else if (isRunning) {
                controller.pauseRun();
              } else {
                controller.resumeRun();
              }
            },
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (isRunning ? Colors.blue : Colors.black).withValues(alpha: 0.2),
                    blurRadius: 20, spreadRadius: 5
                  )
                ],
                gradient: LinearGradient(
                  colors: isRunning 
                    ? [Colors.blue.shade300, Colors.blue.shade700] 
                    : [Colors.black87, Colors.black],
                ),
                border: Border.all(color: Colors.white, width: 8),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(isRunning ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 40),
                    Text(
                      isRunning ? controller.durationString : (isPaused ? "RESUME" : "START"),
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    if (isRunning) Text("${controller.distanceString} KM", style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (isRunning || isPaused)
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () => _confirmStop(context, controller),
              icon: const Icon(Icons.stop),
              label: const Text("FINISH RUN"),
            ),
          )
      ],
    );
  }

  Widget _buildMotivationalReminder(RunController controller) {
    return Container(
      padding: const EdgeInsets.all(15),
      margin: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          const Icon(Icons.wb_sunny, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(child: Text(
            "Weather is ${controller.temp}°C. Keep your ${controller.runStreak} day streak alive!",
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ))
        ],
      ),
    );
  }

  Widget _buildMetrics(RunController controller) {
    if (controller.state == RunState.idle) return const SizedBox(height: 100);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.favorite, color: Colors.red),
        const SizedBox(width: 8),
        Text("${controller.currentBpm}", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
        const Text(" BPM", style: TextStyle(color: Colors.grey)),
      ],
    );
  }

  void _confirmStop(BuildContext context, RunController controller) {
    showDialog(
      context: context,
      builder: (innerContext) => AlertDialog(
        title: const Text("Finish Run?"),
        content: const Text("Ready for your split analysis?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(innerContext), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(innerContext);
              controller.stopRun(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => RunSummaryScreen(controller: controller)));
            },
            child: const Text("FINISH"),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Column(
      children: [
        TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RunHistoryScreen())),
          child: const Text("View Activity History", style: TextStyle(color: Colors.black, decoration: TextDecoration.underline)),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}