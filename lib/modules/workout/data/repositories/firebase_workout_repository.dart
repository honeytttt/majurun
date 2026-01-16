import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/workout_entity.dart';
import '../../domain/entities/comment_entity.dart';
import '../../domain/repositories/workout_repository.dart';

class FirebaseWorkoutRepository implements WorkoutRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- WORKOUT METHODS ---

  @override
  Stream<List<WorkoutEntity>> streamAllWorkouts({String typeFilter = 'all'}) {
    Query query = _db.collection('workouts').orderBy('date', descending: true);
    
    if (typeFilter != 'all') {
      query = query.where('type', isEqualTo: typeFilter);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return WorkoutEntity.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  @override
  Stream<List<WorkoutEntity>> streamUserWorkouts(String userId) {
    return _db.collection('workouts')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WorkoutEntity.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  @override
  Future<void> saveWorkout(WorkoutEntity workout) async {
    await _db.collection('workouts').add(workout.toMap());
  }

  @override
Future<void> toggleCheer(String workoutId, String userId) async {
  final docRef = _db.collection('workouts').doc(workoutId);
  
  // Fetch current state
  final doc = await docRef.get();
  if (!doc.exists) return;

  List currentLikes = List.from(doc.data()?['likes'] ?? []);

  if (currentLikes.contains(userId)) {
    // Remove like (Unlike)
    await docRef.update({
      'likes': FieldValue.arrayRemove([userId])
    });
  } else {
    // Add like
    await docRef.update({
      'likes': FieldValue.arrayUnion([userId])
    });
  }
}

  // --- COMMENT METHODS (Nested & Likable) ---

  @override
  Stream<List<CommentEntity>> streamComments(String workoutId) {
    // We stream all comments for this workout. 
    // The UI handles the nesting logic by filtering the parentId.
    return _db.collection('workouts')
        .doc(workoutId)
        .collection('comments')
        .orderBy('timestamp', descending: false) // Ascending for conversation flow
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => CommentEntity.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  @override
  Future<void> addComment({
    required String workoutId, 
    required String userId, 
    required String text, 
    String? parentId,
  }) async {
    // 1. Resolve User Name/Photo to fix "random letters" (Denormalization)
    final userDoc = await _db.collection('users').doc(userId).get();
    final userData = userDoc.data() ?? {};
    
    final String name = userData['name'] ?? userData['displayName'] ?? 'Runner';
    final String photo = userData['photoUrl'] ?? '';

    // 2. Add comment/reply to the sub-collection
    final commentRef = _db
        .collection('workouts')
        .doc(workoutId)
        .collection('comments')
        .doc();
    
    await commentRef.set({
      'id': commentRef.id,
      'userId': userId,
      'userName': name,      
      'userPhoto': photo,
      'text': text,
      'parentId': parentId, // If null, it's a top-level comment. If not, it's a reply.
      'timestamp': FieldValue.serverTimestamp(),
      'likes': [],
    });

    // 3. Update the total comment count on the main workout document
    await _db.collection('workouts').doc(workoutId).update({
      'commentCount': FieldValue.increment(1)
    });
  }

  @override
  Future<void> toggleCommentLike(String workoutId, String commentId, String userId) async {
    // Targets the specific comment document inside the workout's sub-collection
    final commentRef = _db
        .collection('workouts')
        .doc(workoutId)
        .collection('comments')
        .doc(commentId);
        
    final doc = await commentRef.get();
    
    if (doc.exists) {
      List likes = List.from(doc.data()?['likes'] ?? []);
      if (likes.contains(userId)) {
        await commentRef.update({'likes': FieldValue.arrayRemove([userId])});
      } else {
        await commentRef.update({'likes': FieldValue.arrayUnion([userId])});
      }
    }
  }

  // --- ADDITIONAL METHODS ---

  @override
  Stream<List<Map<String, dynamic>>> streamLeaderboard() {
    return _db.collection('users')
        .orderBy('totalDistance', descending: true)
        .limit(10)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {
          ...d.data(),
          'uid': d.id,
        }).toList());
  }

  @override
  Future<void> savePost({required String userId, required String text, String? imageUrl}) async {
    final userDoc = await _db.collection('users').doc(userId).get();
    final userData = userDoc.data() ?? {};

    await _db.collection('workouts').add({
      'userId': userId,
      'userName': userData['name'] ?? 'Runner',
      'userPhoto': userData['photoUrl'] ?? '',
      'text': text,
      'imageUrl': imageUrl,
      'type': 'post',
      'date': FieldValue.serverTimestamp(),
      'likes': [],
      'commentCount': 0,
      'distance': 0.0,
      'duration': 0,
    });
  }
}