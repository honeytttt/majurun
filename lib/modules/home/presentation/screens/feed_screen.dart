import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:majurun/modules/workout/domain/repositories/workout_repository.dart';
import 'package:majurun/modules/profile/domain/repositories/profile_repository.dart';
import 'package:majurun/modules/workout/domain/entities/workout_entity.dart';
import 'package:majurun/modules/profile/domain/entities/user_entity.dart';
// Import your comments screen
import 'package:majurun/modules/home/presentation/screens/comments_screen.dart'; 

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final workoutRepo = context.read<WorkoutRepository>();
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<List<WorkoutEntity>>(
      stream: workoutRepo.streamAllWorkouts(typeFilter: 'all'), // Banner removed
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.green));
        }
        final workouts = snapshot.data ?? [];
        if (workouts.isEmpty) return const Center(child: Text("No runs or posts found."));

        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: workouts.length,
          itemBuilder: (context, index) => WorkoutPostCard(
            workout: workouts[index], 
            currentUserId: uid
          ),
        );
      },
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
    final isLiked = workout.likes.contains(currentUserId);
    final isVideo = workout.imageUrl?.toLowerCase().endsWith('.mp4') ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[100]!, width: 5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          if (workout.text != null && workout.text!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(workout.text!, style: const TextStyle(fontSize: 15)),
            ),
          
          if (workout.imageUrl != null && workout.imageUrl!.isNotEmpty)
            Container(
              width: double.infinity,
              height: 350,
              color: Colors.black,
              child: isVideo 
                ? VideoPlayerWidget(url: workout.imageUrl!)
                : Image.network(workout.imageUrl!, fit: BoxFit.contain),
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
        if (!snap.hasData || snap.data == null) {
          return const ListTile(title: Text("Loading runner..."));
        }
        final user = snap.data!;
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
            child: user.photoUrl.isEmpty ? const Icon(Icons.person) : null,
          ),
          title: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(DateFormat('MMM dd').format(workout.date)),
        );
      },
    );
  }

  Widget _buildActions(BuildContext context, WorkoutRepository repo, bool isLiked) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // FIX: Likes now working
          IconButton(
            icon: Icon(
              isLiked ? Icons.favorite : Icons.favorite_border, 
              color: isLiked ? Colors.red : Colors.black87
            ),
            onPressed: () => repo.toggleCheer(workout.id, currentUserId),
          ),
          Text("${workout.likes.length}", style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 20),
          // FIX: Comments navigation working
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.black87),
            onPressed: () => Navigator.push(
              context, 
              MaterialPageRoute(builder: (_) => CommentsScreen(workoutId: workout.id))
            ),
          ),
          Text("${workout.commentCount}", style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// Video player remains the same as previous file...
class VideoPlayerWidget extends StatefulWidget {
  final String url;
  const VideoPlayerWidget({super.key, required this.url});
  @override State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}
class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _vc; ChewieController? _cc;
  @override void initState() {
    super.initState();
    _vc = VideoPlayerController.networkUrl(Uri.parse(widget.url))..initialize().then((_) {
      setState(() => _cc = ChewieController(videoPlayerController: _vc, autoPlay: false, looping: true, aspectRatio: _vc.value.aspectRatio));
    });
  }
  @override void dispose() { _vc.dispose(); _cc?.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => _cc != null ? Chewie(controller: _cc!) : const Center(child: CircularProgressIndicator());
}