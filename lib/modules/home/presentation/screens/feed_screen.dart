import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../modules/workout/domain/repositories/workout_repository.dart';
import '../../../../modules/profile/domain/repositories/profile_repository.dart';
import '../../../../modules/workout/domain/entities/workout_entity.dart';
import '../../../../modules/profile/domain/entities/user_entity.dart';
import '../../../../modules/workout/presentation/widgets/comments_sheet.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  // Helper to convert DateTime to "Time Ago"
  String timeAgo(DateTime d) {
    Duration diff = DateTime.now().difference(d);
    if (diff.inDays > 7) return "${(diff.inDays / 7).floor()}w ago";
    if (diff.inDays > 0) return "${diff.inDays}d ago";
    if (diff.inHours > 0) return "${diff.inHours}h ago";
    if (diff.inMinutes > 0) return "${diff.inMinutes}m ago";
    return "just now";
  }

  @override
  Widget build(BuildContext context) {
    final workoutRepo = context.read<WorkoutRepository>();
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: StreamBuilder<List<WorkoutEntity>>(
        stream: workoutRepo.streamAllWorkouts(typeFilter: 'all'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final workouts = snapshot.data ?? [];
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: workouts.length,
            itemBuilder: (context, index) => WorkoutPostCard(
              workout: workouts[index],
              currentUserId: uid,
              timeLabel: timeAgo(workouts[index].date),
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
  final String timeLabel;

  const WorkoutPostCard({
    super.key, 
    required this.workout, 
    required this.currentUserId,
    required this.timeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final workoutRepo = context.read<WorkoutRepository>();
    final bool isLiked = workout.likes.contains(currentUserId);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<UserEntity?>(
            stream: context.read<ProfileRepository>().streamUser(workout.userId),
            builder: (context, snap) {
              final user = snap.data;
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: (user?.photoUrl != null && user!.photoUrl.isNotEmpty)
                      ? NetworkImage(user.photoUrl) : null,
                  child: (user?.photoUrl == null) ? const Icon(Icons.person) : null,
                ),
                title: Text(user?.displayName ?? workout.userName ?? "Runner",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("${workout.type} • $timeLabel"), // Displaying relative time
              );
            },
          ),
          if (workout.text != null && workout.text!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(workout.text!),
            ),
          if (workout.imageUrl != null && workout.imageUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 300, maxWidth: 400),
                    child: Image.network(workout.imageUrl!, fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          _buildActions(context, workoutRepo, isLiked),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, WorkoutRepository repo, bool isLiked) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border,
                color: isLiked ? Colors.red : Colors.grey),
            onPressed: () => repo.toggleCheer(workout.id, currentUserId),
          ),
          Text("${workout.likes.length}"),
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
          Text("${workout.commentCount}"),
        ],
      ),
    );
  }
}