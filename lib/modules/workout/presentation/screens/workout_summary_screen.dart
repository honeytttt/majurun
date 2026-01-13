import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/workout_entity.dart';
import '../../domain/repositories/workout_repository.dart';

class WorkoutSummaryScreen extends StatefulWidget {
  final double distance; // Changed to match record screen
  final Duration duration;

  const WorkoutSummaryScreen({
    super.key,
    required this.distance,
    required this.duration,
  });

  @override
  State<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends State<WorkoutSummaryScreen> {
  final _textController = TextEditingController();
  bool _isSaving = false;

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final user = FirebaseAuth.instance.currentUser;
    
    final workout = WorkoutEntity(
      id: '',
      userId: user?.uid ?? '',
      text: _textController.text,
      type: 'run',
      date: DateTime.now(),
      likes: [],
      commentCount: 0,
      distance: widget.distance,
      duration: widget.duration,
    );

    await context.read<WorkoutRepository>().saveWorkout(workout);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Run Summary")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text("${widget.distance.toStringAsFixed(2)} km", style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
            TextField(controller: _textController, decoration: const InputDecoration(hintText: "How was your run?")),
            const Spacer(),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.green),
              child: _isSaving ? const CircularProgressIndicator() : const Text("SAVE RUN", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }
}