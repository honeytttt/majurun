import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../../workout/domain/repositories/workout_repository.dart';
import '../../../profile/domain/repositories/profile_repository.dart';
import '../../../workout/domain/entities/workout_entity.dart';
import '../../../profile/domain/entities/user_entity.dart';
import '../../../workout/presentation/widgets/comments_sheet.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final workoutRepo = context.read<WorkoutRepository>();
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Majurun Feed", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: StreamBuilder<List<WorkoutEntity>>(
        stream: workoutRepo.streamAllWorkouts(typeFilter: 'all'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          
          final workouts = snapshot.data ?? [];
          return ListView.builder(
            itemCount: workouts.length,
            itemBuilder: (context, index) => WorkoutPostCard(
              workout: workouts[index],
              currentUserId: uid,
            ),
          );
        },
      ),
    );
  }
}

class WorkoutPostCard extends StatelessWidget {
  final WorkoutEntity workout;
  final String currentUserId;
  const WorkoutPostCard({super.key, required this.workout, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final workoutRepo = context.read<WorkoutRepository>();
    final bool isLiked = workout.likes.contains(currentUserId);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      elevation: 0,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          
          if (workout.text != null && workout.text!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(workout.text!, style: const TextStyle(fontSize: 15)),
            ),
          
          // IMAGE SECTION: Fixed to show full photo without stretching
          if (workout.imageUrl != null && workout.imageUrl!.isNotEmpty)
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 400), // Limits height so it's not huge
              color: Colors.black, // Adds a background color for portrait photos
              child: Image.network(
                workout.imageUrl!,
                fit: BoxFit.contain, // FIX: Shows the FULL image without cropping or stretching
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 200,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 200,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
            
          _buildActions(context, workoutRepo, isLiked),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return StreamBuilder<UserEntity?>(
      stream: context.read<ProfileRepository>().streamUser(workout.userId),
      builder: (context, snap) {
        final user = snap.data;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.green[50],
            backgroundImage: (user?.photoUrl != null && user!.photoUrl.isNotEmpty) 
                ? NetworkImage(user.photoUrl) : null,
            child: (user?.photoUrl == null || user!.photoUrl.isEmpty) 
                ? const Icon(Icons.person, color: Colors.green) : null,
          ),
          title: Text(
            user?.displayName ?? workout.userName ?? "Runner", 
            style: const TextStyle(fontWeight: FontWeight.bold)
          ),
          subtitle: Text("${workout.type} • ${DateFormat('MMM dd').format(workout.date)}"),
        );
      },
    );
  }

  Widget _buildActions(BuildContext context, WorkoutRepository repo, bool isLiked) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              isLiked ? Icons.favorite : Icons.favorite_border, 
              color: isLiked ? Colors.red : Colors.grey[700]
            ),
            onPressed: () => repo.toggleCheer(workout.id, currentUserId),
          ),
          Text("${workout.likes.length}", style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => CommentsSheet(workoutId: workout.id),
            ),
          ),
          Text("${workout.commentCount}", style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}