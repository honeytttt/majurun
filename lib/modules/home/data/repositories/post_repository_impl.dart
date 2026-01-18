import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:majurun/modules/home/domain/entities/post.dart';

class PostRepositoryImpl {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<AppPost>> getPostStream() {
    return _db
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final List<dynamic> mediaData = data['media'] as List? ?? [];

        return AppPost(
          id: doc.id,
          userId: data['userId'] ?? 'unknown',
          username: data['username'] ?? 'Runner',
          content: data['content'] ?? '',
          media: mediaData.map((m) {
            return PostMedia(
              url: m['url'] ?? '',
              type: m['type'] == 'video' ? MediaType.video : MediaType.image,
            );
          }).toList(),
          // FIXED: Fallback to current time if Firestore timestamp is still null (pending)
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          likes: List<String>.from(data['likes'] ?? []),
          comments: const [],
          quotedPostId: data['quotedPostId'],
        );
      }).toList();
    });
  }

  Future<void> createPost(AppPost post) async {
    try {
      await _db.collection('posts').doc(post.id).set({
        'id': post.id,
        'userId': post.userId,
        'username': post.username,
        'content': post.content,
        'media': post.media.map((m) => {
          'url': m.url,
          'type': m.type.name,
        }).toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'likes': [],
        'quotedPostId': post.quotedPostId,
        'comments': [],
      });
    } catch (e) {
      throw Exception("Firestore Error: $e");
    }
  }

  Future<void> toggleLike(String postId, String userId) async {
    final docRef = _db.collection('posts').doc(postId);
    final doc = await docRef.get();

    if (doc.exists) {
      List<String> likes = List<String>.from(doc.data()?['likes'] ?? []);
      if (likes.contains(userId)) {
        likes.remove(userId);
      } else {
        likes.add(userId);
      }
      await docRef.update({'likes': likes});
    }
  }
}