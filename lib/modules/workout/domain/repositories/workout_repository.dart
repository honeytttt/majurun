import '../entities/workout_entity.dart';
import '../entities/comment_entity.dart';

abstract class WorkoutRepository {
  Stream<List<WorkoutEntity>> streamAllWorkouts({String typeFilter = 'all'});
  Stream<List<WorkoutEntity>> streamUserWorkouts(String userId);
  Stream<List<Map<String, dynamic>>> streamLeaderboard();
  Stream<List<CommentEntity>> streamComments(String workoutId);
  
  Future<void> saveWorkout(WorkoutEntity workout);
  Future<void> savePost({required String userId, required String text, String? imageUrl});
  Future<void> toggleCheer(String workoutId, String userId);
  Future<void> addComment({required String workoutId, required String userId, required String text, String? parentId});
  Future<void> toggleCommentLike(String workoutId, String commentId, String userId);
}