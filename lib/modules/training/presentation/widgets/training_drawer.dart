import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:majurun/modules/training/data/plans/c25k_plan.dart';
import '../../services/training_service.dart';
import '../../data/models/training_plan.dart';
import '../screens/active_workout_screen.dart';
import '../screens/history_screen.dart';

class TrainingDrawer extends StatelessWidget {
  const TrainingDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.black),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.psychology, color: Colors.blueAccent, size: 40),
                  SizedBox(height: 10),
                  Text(
                    "COACHING PLANS",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          _planTile(context, "0 to 5KM", "Beginner", _getSampleWorkout()),
          _planTile(context, "5KM to 10KM", "Intermediate", _getSampleWorkout()),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text("Workout History"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
            },
          ),
        ],
      ),
    );
  }

  Widget _planTile(BuildContext context, String title, String level, TrainingWorkout workout) {
    return ListTile(
      leading: const Icon(Icons.directions_run, color: Colors.blue),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(level),
      onTap: () {
        Navigator.pop(context);
        _showWorkoutSheet(context, title, workout);
      },
    );
  }

  void _showWorkoutSheet(BuildContext context, String title, TrainingWorkout workout) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            const Text("This will start a guided session with voice coaching instructions."),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                onPressed: () {
                  Navigator.pop(context);
                  context.read<TrainingService>().startWorkout(workout, title);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ActiveWorkoutScreen(planTitle: title),
                    ),
                  );
                },
                child: const Text("START COACHING", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TrainingWorkout _getSampleWorkout() {
    return TrainingWorkout(week: 1, day: 1, steps: [
      WorkoutStep(action: "Warm Up", durationSeconds: 30, voiceInstruction: "Begin your warm up"),
      WorkoutStep(action: "Run", durationSeconds: 60, voiceInstruction: "Start running"),
    ]);
  }
}