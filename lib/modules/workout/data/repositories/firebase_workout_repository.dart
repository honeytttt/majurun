import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/workout_entity.dart';
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
      return snapshot.docs.map((doc) {
        // CORRECTED: (Map, String)
        return WorkoutEntity.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  @override
  Future<void> saveWorkout(WorkoutEntity workout) async {
    await _db.collection('workouts').add(workout.toMap());
  }

  @override
  Future<void> savePost({required String userId, required String text, String? imageUrl}) async {
    await _db.collection('workouts').add({
      'userId': userId,
      'text': text,
      'imageUrl': imageUrl,
      'type': 'post',
      'date': FieldValue.serverTimestamp(),
      'likes': [],
      'commentCount': 0,
    });
  }

  @override
  Future<void> toggleCheer(String workoutId, String userId) async {
    final docRef = _db.collection('workouts').doc(workoutId);
    final doc = await docRef.get();
    if (doc.exists) {
      List likes = doc.data()?['likes'] ?? [];
      if (likes.contains(userId)) {
        await docRef.update({'likes': FieldValue.arrayRemove([userId])});
      } else {
        await docRef.update({'likes': FieldValue.arrayUnion([userId])});
      }
    }
  }

  @override
  Future<void> addComment({
    required String workoutId, 
    required String userId, 
    required String text, 
    String? parentId
  }) async {
    final commentRef = _db.collection('workouts').doc(workoutId).collection('comments').doc();
    
    await commentRef.set({
      'id': commentRef.id,
      'userId': userId,
      'text': text,
      'parentId': parentId,
      'timestamp': FieldValue.serverTimestamp(),
      'likes': [], // MUST BE INITIALIZED AS AN ARRAY
    });

    await _db.collection('workouts').doc(workoutId).update({
      'commentCount': FieldValue.increment(1),
    });
  }

  @override
  Future<void> toggleCommentLike(String workoutId, String commentId, String userId) async {
    final commentRef = _db
        .collection('workouts')
        .doc(workoutId)
        .collection('comments')
        .doc(commentId);

    try {
      await _db.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(commentRef);

        if (!snapshot.exists) return;

        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        List<dynamic> likes = data['likes'] is List ? data['likes'] : [];

        if (likes.contains(userId)) {
          transaction.update(commentRef, {
            'likes': FieldValue.arrayRemove([userId])
          });
        } else {
          transaction.update(commentRef, {
            'likes': FieldValue.arrayUnion([userId])
          });
        }
      });
    } catch (e) {
      print("Error toggling comment like: $e");
      rethrow; // This will help you see if permissions are still failing
    }
  }

  @override
  Stream<List<Map<String, dynamic>>> streamComments(String workoutId) {
    return _db.collection('workouts').doc(workoutId).collection('comments').orderBy('timestamp', descending: true).snapshots().map((snap) => snap.docs.map((d) => d.data()).toList());
  }
}