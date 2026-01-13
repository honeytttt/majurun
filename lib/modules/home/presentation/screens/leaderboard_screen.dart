import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:majurun/modules/workout/domain/entities/workout_entity.dart';
import 'package:majurun/modules/workout/domain/repositories/workout_repository.dart';
import 'package:majurun/modules/profile/presentation/widgets/user_name_widget.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final workoutRepo = context.read<WorkoutRepository>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Weekly Leaderboard", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<List<WorkoutEntity>>(
        stream: workoutRepo.streamLeaderboard(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final workouts = snapshot.data ?? [];
          
          Map<String, double> userDistances = {};
          for (var workout in workouts) {
            userDistances[workout.userId] = (userDistances[workout.userId] ?? 0) + workout.distance;
          }

          var sortedEntries = userDistances.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          if (sortedEntries.isEmpty) {
            return const Center(child: Text("No runs this week yet!"));
          }

          return ListView.builder(
            itemCount: sortedEntries.length,
            itemBuilder: (context, index) {
              final entry = sortedEntries[index];
              final rank = index + 1;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getRankColor(rank),
                  child: Text("$rank", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                title: UserNameWidget(
                  userId: entry.key,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text("Total Distance"),
                trailing: Text(
                  "${entry.value.toStringAsFixed(2)} km",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.green),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getRankColor(int rank) {
    if (rank == 1) return Colors.amber;
    if (rank == 2) return Colors.grey.shade400;
    if (rank == 3) return Colors.brown.shade300;
    return Colors.green.shade100;
  }
}