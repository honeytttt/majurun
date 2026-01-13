import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../../workout/domain/entities/workout_entity.dart';
import '../../../workout/domain/repositories/workout_repository.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final profileRepo = context.read<ProfileRepository>();
    final workoutRepo = context.read<WorkoutRepository>();
    
    // Target for the progress bar
    const double monthlyGoalKm = 50.0;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: StreamBuilder<UserEntity?>(
        stream: profileRepo.streamUser(currentUserId),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = userSnapshot.data;
          if (user == null) return const Center(child: Text("User not found"));

          return StreamBuilder<List<WorkoutEntity>>(
            stream: workoutRepo.streamUserWorkouts(currentUserId),
            builder: (context, workoutSnapshot) {
              final workouts = workoutSnapshot.data ?? [];
              
              // 1. Calculate Lifetime Stats
              double totalKm = workouts.fold(0, (sum, w) => sum + w.distance);
              int totalSeconds = workouts.fold(0, (sum, w) => sum + w.duration.inSeconds);
              String totalTimeStr = "${totalSeconds ~/ 3600}h ${(totalSeconds % 3600) ~/ 60}m";

              // 2. Calculate Personal Records
              double longestRun = 0.0;
              double fastestPace = double.infinity;

              for (var w in workouts) {
                if (w.distance > longestRun) longestRun = w.distance;
                if (w.distance > 0.5) {
                  double pace = w.duration.inMinutes / w.distance;
                  if (pace < fastestPace) fastestPace = pace;
                }
              }

              double goalProgress = (totalKm / monthlyGoalKm).clamp(0.0, 1.0);

              return CustomScrollView(
                slivers: [
                  // Profile Header
                  SliverToBoxAdapter(
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 45,
                            backgroundColor: Colors.green.shade100,
                            backgroundImage: user.photoUrl.isNotEmpty 
                                ? NetworkImage(user.photoUrl) 
                                : null,
                            child: user.photoUrl.isEmpty 
                                ? const Icon(Icons.person, size: 45, color: Colors.green) 
                                : null,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            user.displayName,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          if (user.bio.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(user.bio, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                            ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => EditProfileScreen(user: user)),
                            ),
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text("Edit Profile"),
                          ),
                          const Divider(height: 40),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStat("Runs", workouts.length.toString()),
                              _buildStat("Total KM", totalKm.toStringAsFixed(1)),
                              _buildStat("Time", totalTimeStr),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Monthly Goal Progress
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Monthly Goal", style: TextStyle(fontWeight: FontWeight.bold)),
                                Text("${totalKm.toStringAsFixed(1)} / $monthlyGoalKm km", 
                                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: goalProgress,
                              backgroundColor: Colors.grey[200],
                              color: Colors.green,
                              minHeight: 10,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            const SizedBox(height: 8),
                            Text("${(goalProgress * 100).toInt()}% of your monthly target reached!",
                              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Personal Records
                  if (workouts.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Text("PERSONAL RECORDS", 
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 11, letterSpacing: 1.2)),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 100,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            _recordCard(Icons.emoji_events, "Longest Run", "${longestRun.toStringAsFixed(2)} km", Colors.orange),
                            _recordCard(Icons.speed, "Best Pace", 
                              fastestPace == double.infinity ? "--" : "${fastestPace.toStringAsFixed(2)} min/km", 
                              Colors.blue),
                            _recordCard(Icons.history, "Lifetime", totalTimeStr, Colors.purple),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Activity History
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Text("RECENT ACTIVITY", 
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 11, letterSpacing: 1.2)),
                    ),
                  ),

                  workouts.isEmpty
                      ? const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: Text("No runs recorded yet.")),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildActivityCard(workouts[index]),
                            childCount: workouts.length,
                          ),
                        ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _recordCard(IconData icon, String label, String value, Color color) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildActivityCard(WorkoutEntity run) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade50,
          child: const Icon(Icons.directions_run, color: Colors.green, size: 20),
        ),
        title: Text(
          DateFormat('MMM d, yyyy').format(run.date),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text("${run.distance.toStringAsFixed(2)} km • ${run.duration.inMinutes} min"),
        trailing: Icon(run.isPublic ? Icons.public : Icons.lock_outline, size: 14, color: Colors.grey),
      ),
    );
  }
}