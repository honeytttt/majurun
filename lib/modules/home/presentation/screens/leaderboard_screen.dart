import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../modules/workout/domain/repositories/workout_repository.dart';
import '../../../../modules/profile/presentation/widgets/user_name_widget.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final workoutRepo = context.read<WorkoutRepository>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Weekly Leaderboard", 
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      // FIXED: Changed type from WorkoutEntity to Map<String, dynamic>
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: workoutRepo.streamLeaderboard(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final leaders = snapshot.data ?? [];

          if (leaders.isEmpty) {
            return const Center(child: Text("No runs this week yet!"));
          }

          return ListView.builder(
            itemCount: leaders.length,
            itemBuilder: (context, index) {
              final entry = leaders[index];
              final rank = index + 1;
              // Extract data from the Map based on your Repository structure
              final userId = entry['userId'] ?? '';
              final totalDistance = entry['totalDistance'] ?? 0.0;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getRankColor(rank),
                  child: Text("$rank", 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                title: UserNameWidget(
                  userId: userId,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text("Total Distance"),
                trailing: Text(
                  "${totalDistance.toStringAsFixed(2)} km",
                  style: const TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.w900, 
                    color: Colors.green
                  ),
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