import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:majurun/modules/home/domain/entities/post.dart';

class PostRepositoryImpl {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createPost(AppPost post) async {
    await _db.collection('posts').doc(post.id).set({
      'userId': post.userId,
      'username': post.username,
      'content': post.content,
      'media': post.media.map((m) => {'url': m.url, 'type': m.type.name}).toList(),
      'createdAt': FieldValue.serverTimestamp(), // For accurate relative time
      'likes': [],
      'quotedPostId': post.quotedPostId,
    });
  }

  // Nested Comment Implementation
  Future<void> addComment(String postId, AppComment comment, {String? parentCommentId}) async {
    final commentData = {
      'id': comment.id,
      'userId': comment.userId,
      'username': comment.username,
      'text': comment.text,
      'createdAt': DateTime.now().toIso8601String(),
      'likes': [],
    };

    if (parentCommentId == null) {
      // Root comment
      await _db.collection('posts').doc(postId).update({
        'comments': FieldValue.arrayUnion([commentData])
      });
    } else {
      // Nested logic would ideally use a sub-collection for performance
      // but keeping it independent for your current small-scale structure
      await _db.collection('posts').doc(postId).collection('comments').doc(parentCommentId).update({
        'replies': FieldValue.arrayUnion([commentData])
      });
    }
  }
}