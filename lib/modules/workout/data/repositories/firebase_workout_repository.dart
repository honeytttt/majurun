import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/workout_entity.dart';
import '../../domain/entities/comment_entity.dart';
import '../../domain/repositories/workout_repository.dart';

class FirebaseWorkoutRepository implements WorkoutRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<List<CommentEntity>> streamComments(String workoutId) {
    return _firestore
        .collection('workouts')
        .doc(workoutId)
        .collection('comments')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        
        // 1. SAFE REPLY MAPPING
        final List<dynamic> repliesData = data['replies'] ?? [];
        final List<CommentEntity> parsedReplies = repliesData.map((r) {
          final replyMap = Map<String, dynamic>.from(r);
          return CommentEntity(
            // Ensure every reply has a stable ID to prevent UI disappearance
            id: replyMap['replyId']?.toString() ?? DateTime.now().toIso8601String(),
            userId: replyMap['userId'] ?? '',
            userName: replyMap['userName'] ?? 'User',
            text: replyMap['text'] ?? '',
            // Fallback for null timestamps during server sync
            date: (replyMap['date'] is Timestamp) 
                ? (replyMap['date'] as Timestamp).toDate() 
                : DateTime.now(),
            likes: List<String>.from(replyMap['likes'] ?? []),
          );
        }).toList();

        // 2. SAFE MAIN COMMENT MAPPING
        return CommentEntity(
          id: doc.id,
          userId: data['userId'] ?? '',
          userName: data['userName'] ?? 'User',
          text: data['text'] ?? '',
          date: (data['date'] is Timestamp) 
              ? (data['date'] as Timestamp).toDate() 
              : DateTime.now(), // Critical for preventing "blink"
          likes: List<String>.from(data['likes'] ?? []),
          replies: parsedReplies,
        );
      }).toList();
    });
  }

  @override
  Future<void> addReply(String workoutId, String commentId, String text) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // We generate the ID locally so it's stable the moment it hits the stream
    final String replyId = 'reply_${DateTime.now().millisecondsSinceEpoch}_${user.uid}';

    final newReply = {
      'replyId': replyId,
      'userId': user.uid,
      'userName': user.displayName ?? "User",
      'text': text,
      'date': Timestamp.now(), 
      'likes': [],
    };

    await _firestore
        .collection('workouts')
        .doc(workoutId)
        .collection('comments')
        .doc(commentId)
        .update({
      'replies': FieldValue.arrayUnion([newReply])
    });
  }

  @override
  Future<void> addComment(String workoutId, String text) async {
    final user = FirebaseAuth.instance.currentUser;
    await _firestore.collection('workouts').doc(workoutId).collection('comments').add({
      'userId': user?.uid,
      'userName': user?.displayName ?? "User",
      'text': text,
      'date': FieldValue.serverTimestamp(),
      'likes': [],
      'replies': [],
    });
    
    await _firestore.collection('workouts').doc(workoutId).update({
      'commentCount': FieldValue.increment(1)
    });
  }

  // Missing toggle logic from earlier
  Future<void> toggleCommentLike(String workoutId, String commentId, String userId) async {
    final docRef = _firestore
        .collection('workouts')
        .doc(workoutId)
        .collection('comments')
        .doc(commentId);

    final doc = await docRef.get();
    if (!doc.exists) return;

    final List currentLikes = List<String>.from(doc.data()?['likes'] ?? []);

    if (currentLikes.contains(userId)) {
      await docRef.update({'likes': FieldValue.arrayRemove([userId])});
    } else {
      await docRef.update({'likes': FieldValue.arrayUnion([userId])});
    }
  }

  // The rest of your repository methods...
  @override
  Future<void> savePost({required String userId, required String userName, required String text, String? imageUrl}) async {
    await _firestore.collection('workouts').add({'userId': userId, 'userName': userName, 'text': text, 'imageUrl': imageUrl, 'type': 'Post', 'distance': 0.0, 'duration': 0, 'date': FieldValue.serverTimestamp(), 'likes': [], 'commentCount': 0});
  }
  @override
  Stream<List<WorkoutEntity>> streamAllWorkouts({String? typeFilter}) {
    Query q = _firestore.collection('workouts').orderBy('date', descending: true);
    if (typeFilter != null && typeFilter != 'all') q = q.where('type', isEqualTo: typeFilter);
    return q.snapshots().map((s) => s.docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      return WorkoutEntity(id: d.id, userId: data['userId'] ?? '', userName: data['userName'] ?? 'Runner', type: data['type'] ?? 'Run', distance: (data['distance'] ?? 0.0).toDouble(), duration: Duration(seconds: (data['duration'] ?? 0).toInt()), date: (data['date'] is Timestamp) ? (data['date'] as Timestamp).toDate() : DateTime.now(), likes: List<String>.from(data['likes'] ?? []), commentCount: (data['commentCount'] ?? 0).toInt(), text: data['text'], imageUrl: data['imageUrl']);
    }).toList());
  }
  @override
  Future<void> toggleCheer(String workoutId, String userId) async {
    final docRef = _firestore.collection('workouts').doc(workoutId);
    final snapshot = await docRef.get();
    final List likes = List<String>.from(snapshot.data()?['likes'] ?? []);
    if (likes.contains(userId)) {
      await docRef.update({'likes': FieldValue.arrayRemove([userId])});
    } else {
      await docRef.update({'likes': FieldValue.arrayUnion([userId])});
    }
  }
  @override
  Future<void> createWorkout(WorkoutEntity workout) async {
    await _firestore.collection('workouts').add({'userId': workout.userId, 'userName': workout.userName, 'type': workout.type, 'distance': workout.distance, 'duration': workout.duration.inSeconds, 'date': Timestamp.fromDate(workout.date), 'likes': [], 'commentCount': 0, 'text': workout.text, 'imageUrl': workout.imageUrl});
  }
  @override
  Stream<List<Map<String, dynamic>>> streamLeaderboard() {
    return _firestore.collection('workouts').snapshots().map((snapshot) {
      Map<String, Map<String, dynamic>> userStats = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final uid = data['userId'];
        if (uid == null) continue;
        double dist = (data['distance'] ?? 0.0).toDouble();
        if (userStats.containsKey(uid)) {
          userStats[uid]!['totalDistance'] = (userStats[uid]!['totalDistance'] as double) + dist;
        } else {
          userStats[uid] = {'userId': uid, 'userName': data['userName'] ?? 'Runner', 'totalDistance': dist};
        }
      }
      var list = userStats.values.toList();
      list.sort((a, b) => (b['totalDistance'] as double).compareTo(a['totalDistance'] as double));
      return list;
    });
  }
}