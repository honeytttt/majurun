import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

// FIXED: Looking in the same directory based on your tree output
import 'summary_card.dart'; 
import '../../domain/entities/workout_entity.dart';
import '../../domain/repositories/workout_repository.dart';

class WorkoutSummaryScreen extends StatelessWidget {
  final double distance;
  final Duration duration;
  final String type;

  const WorkoutSummaryScreen({
    super.key,
    required this.distance,
    required this.duration,
    required this.type,
  });

  void _saveWorkout(BuildContext context) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final workout = WorkoutEntity(
      id: '', 
      userId: userId,
      type: type,
      distance: distance,
      duration: duration, 
      date: DateTime.now(),
      likes: [],
      commentCount: 0,
    );

    try {
      await context.read<WorkoutRepository>().saveWorkout(workout);
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Workout Summary', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // This now works because the import points to the file next to it
            SummaryCard(
              distance: distance,
              duration: duration,
              type: type,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => _saveWorkout(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('SAVE WORKOUT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}