import '../entities/workout_entity.dart';

abstract class WorkoutRepository {
  Future<void> saveWorkout(WorkoutEntity workout);
  Stream<List<WorkoutEntity>> streamWorkouts(String userId);
}