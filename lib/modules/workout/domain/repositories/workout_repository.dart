import '../entities/workout_entity.dart';
import '../entities/comment_entity.dart';

abstract class WorkoutRepository {
  Stream<List<WorkoutEntity>> streamAllWorkouts({String? typeFilter});
  Stream<List<Map<String, dynamic>>> streamLeaderboard();
  
  // For recorded activities
  Future<void> createWorkout(WorkoutEntity workout);
  
  // For manual posts from CreatePostScreen
  Future<void> savePost({
    required String userId,
    required String userName,
    required String text,
    String? imageUrl,
  });
  
  // Social interactions
  Future<void> toggleCheer(String workoutId, String userId);
  
  // Comments and Replies
  Stream<List<CommentEntity>> streamComments(String workoutId);
  Future<void> addComment(String workoutId, String text);
  Future<void> addReply(String workoutId, String commentId, String text);
}