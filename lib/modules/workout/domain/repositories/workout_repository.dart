import '../entities/workout_entity.dart';

abstract class WorkoutRepository {
  Stream<List<WorkoutEntity>> streamAllWorkouts({String typeFilter = 'all'});
  Future<void> savePost({required String userId, required String text, String? imageUrl});
  Future<void> saveWorkout(WorkoutEntity workout);
  Future<void> toggleCheer(String workoutId, String userId);
  
  // Comment Logic
  Future<void> addComment({required String workoutId, required String userId, required String text, String? parentId});
  Future<void> toggleCommentLike(String workoutId, String commentId, String userId);
  Stream<List<Map<String, dynamic>>> streamComments(String workoutId);
}