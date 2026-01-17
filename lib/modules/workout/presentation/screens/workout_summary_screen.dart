import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/workout_entity.dart';
import '../../domain/repositories/workout_repository.dart';

class WorkoutSummaryScreen extends StatelessWidget {
  final String type;
  final double distance;
  final Duration duration;

  const WorkoutSummaryScreen({
    super.key,
    required this.type,
    required this.distance,
    required this.duration,
  });

  Future<void> _postToFeed(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final workout = WorkoutEntity(
      id: '', // Firestore generates this
      userId: user.uid,
      userName: user.displayName ?? "Runner",
      type: type,
      distance: distance,
      duration: duration,
      date: DateTime.now(),
      likes: [],
      commentCount: 0,
      text: "Just finished a $distance km $type!",
    );

    try {
      await context.read<WorkoutRepository>().createWorkout(workout);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Workout posted to feed!")),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to post: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Workout Summary")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
            const SizedBox(height: 16),
            Text("$distance km", style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
            Text(type, style: const TextStyle(fontSize: 20, color: Colors.grey)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _postToFeed(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text("POST TO FEED", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}