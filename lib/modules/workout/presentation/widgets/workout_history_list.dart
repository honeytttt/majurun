import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/workout_entity.dart';

class WorkoutHistoryList extends StatelessWidget {
  final List<WorkoutEntity> workouts;

  const WorkoutHistoryList({super.key, required this.workouts});

  @override
  Widget build(BuildContext context) {
    if (workouts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text("No runs recorded yet. Start moving!"),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: workouts.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final run = workouts[index];
        return ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.directions_run, color: Colors.green),
          ),
          title: Text(
            "${run.distance.toStringAsFixed(2)} km Run",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(DateFormat('MMM dd, yyyy • hh:mm a').format(run.date)),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                run.duration.toString().split('.').first,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text("Time", style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        );
      },
    );
  }
}