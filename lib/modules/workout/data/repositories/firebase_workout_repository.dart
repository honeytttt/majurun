import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/workout_entity.dart';
import '../../domain/entities/comment_entity.dart'; // Ensure this exists!
import '../../domain/repositories/workout_repository.dart';

class FirebaseWorkoutRepository implements WorkoutRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Stream<List<WorkoutEntity>> streamAllWorkouts({String typeFilter = 'all'}) {
    Query query = _db.collection('workouts').orderBy('date', descending: true);
    if (typeFilter != 'all') {
      query = query.where('type', isEqualTo: typeFilter);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => 
        WorkoutEntity.fromMap(doc.data() as Map<String, dynamic>, doc.id)
      ).toList();
    });
  }

  // ADDED THIS: Fixes the non_abstract_class_inherits_abstract_member error
  @override
  Stream<List<WorkoutEntity>> streamUserWorkouts(String userId) {
    return _db.collection('workouts')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WorkoutEntity.fromMap(doc.data(), doc.id))
            .toList());
  }

  @override
  Stream<List<Map<String, dynamic>>> streamLeaderboard() {
    return _db.collection('users')
        .orderBy('totalDistance', descending: true)
        .limit(10)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {...d.data(), 'uid': d.id}).toList());
  }

  @override
  Stream<List<CommentEntity>> streamComments(String workoutId) {
    return _db.collection('workouts')
        .doc(workoutId)
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => CommentEntity.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  // ... rest of your methods (saveWorkout, toggleCheer, etc.)
  @override
  Future<void> saveWorkout(WorkoutEntity workout) async => await _db.collection('workouts').add(workout.toMap());
  
  @override
  Future<void> savePost({required String userId, required String text, String? imageUrl}) async { /* logic */ }
  
  @override
  Future<void> toggleCheer(String workoutId, String userId) async { /* logic */ }
  
  @override
  Future<void> addComment({required String workoutId, required String userId, required String text, String? parentId}) async { /* logic */ }
  
  @override
  Future<void> toggleCommentLike(String workoutId, String commentId, String userId) async { /* logic */ }
}