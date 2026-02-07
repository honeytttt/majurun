import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../domain/entities/post.dart';

class PostRepositoryImpl {
  final FirebaseFirestore _db;
  PostRepositoryImpl({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  AppPost _mapDocToAppPost(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    List<PostMedia> mediaList = [];
    if (data['media'] is List) {
      final List<dynamic> mediaData = data['media'];
      mediaList = mediaData.map((m) {
        final url = (m is Map) ? (m['url'] ?? '') : '';
        final typeStr = (m is Map) ? (m['type'] ?? 'image') : 'image';
        return PostMedia(
          url: url,
          type: typeStr == 'video' ? MediaType.video : MediaType.image,
        );
      }).toList();
    }

    // ✅ NEW: fallback to mapImageUrl when media is empty
    final mapImageUrl = data['mapImageUrl']?.toString();
    if (mediaList.isEmpty && mapImageUrl != null && mapImageUrl.isNotEmpty) {
      mediaList.add(PostMedia(url: mapImageUrl, type: MediaType.image));
    }

    List<LatLng>? routePoints;
    if (data['routePoints'] != null && data['routePoints'] is List) {
      final List<dynamic> pts = data['routePoints'];
      routePoints = pts.map((p) {
        if (p is Map) {
          final lat = (p['lat'] as num).toDouble();
          final lng = (p['lng'] as num).toDouble();
          return LatLng(lat, lng);
        }
        return null;
      }).whereType<LatLng>().toList();
    }

    return AppPost(
      id: doc.id,
      userId: data['userId'] ?? 'unknown',
      username: data['username'] ?? 'Runner',
      content: data['content'] ?? '',
      media: mediaList,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: List<String>.from(data['likes'] ?? []),
      comments: const [],
      quotedPostId: data['quotedPostId'],
      routePoints: routePoints,
    );
  }

  Stream<List<AppPost>> getPostsStream() => getPostStream();

  Stream<List<AppPost>> getPostStream() {
    debugPrint("📰 Fetching posts stream...");
    return _db
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      debugPrint("📰 Received ${snapshot.docs.length} posts from Firestore");
      final posts = <AppPost>[];
      for (final doc in snapshot.docs) {
        try {
          posts.add(_mapDocToAppPost(doc));
        } catch (e) {
          debugPrint("❌ Error mapping post ${doc.id}: $e");
        }
      }
      debugPrint("📰 Successfully mapped ${posts.length} posts");
      return posts;
    });
  }

  Future<void> createPost(
    AppPost post, {
    double? numericDistance,
    int? avgBpm,
    List<int>? splits,
    String type = 'regular',
  }) async {
    try {
      await _db.collection('posts').doc(post.id).set({
        'userId': post.userId,
        'username': post.username,
        'content': post.content,
        'distance': numericDistance,
        'avgBpm': avgBpm,
        'splits': splits,
        'type': type,
        'media': post.media
            .map((m) => {'url': m.url, 'type': m.type == MediaType.video ? 'video' : 'image'})
            .toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'likes': [],
        if (post.quotedPostId != null) 'quotedPostId': post.quotedPostId,
        if (post.routePoints != null)
          'routePoints': post.routePoints!
              .map((p) => {'lat': p.latitude, 'lng': p.longitude})
              .toList(),
      });
    } catch (e) {
      debugPrint("Error creating post: $e");
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      await _db.collection('posts').doc(postId).delete();
    } catch (e) {
      debugPrint("Error deleting post: $e");
    }
  }

  Future<AppPost?> getPostById(String postId) async {
    try {
      final doc = await _db.collection('posts').doc(postId).get();
      if (!doc.exists) return null;
      return _mapDocToAppPost(doc);
    } catch (e) {
      debugPrint("Error fetching post: $e");
      return null;
    }
  }

  Future<void> toggleLike(String postId, String userId) async {
    final docRef = _db.collection('posts').doc(postId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      List<String> likes = List<String>.from(snapshot.data()?['likes'] ?? []);
      if (likes.contains(userId)) {
        likes.remove(userId);
      } else {
        likes.add(userId);
      }
      transaction.update(docRef, {'likes': likes});
    });
  }

  Future<void> repost(AppPost originalPost, String userId, String username) async {
    try {
      final String targetId = originalPost.quotedPostId != null && originalPost.quotedPostId!.isNotEmpty
          ? originalPost.quotedPostId!
          : originalPost.id;

      await _db.collection('posts').add({
        'userId': userId,
        'username': username,
        'content': '',
        'media': [],
        'createdAt': FieldValue.serverTimestamp(),
        'likes': [],
        'quotedPostId': targetId,
      });
    } catch (e) {
      debugPrint("Error during reposting: $e");
    }
  }

  Stream<List<Map<String, dynamic>>> getCommentsStream(String postId) {
    return _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
  }

  Future<void> addComment({
    required String postId,
    required String userId,
    required String username,
    required String content,
    String? parentId,
    List<Map<String, dynamic>>? media,
  }) async {
    await _db.collection('posts').doc(postId).collection('comments').add({
      'userId': userId,
      'username': username,
      'content': content,
      'parentId': parentId,
      'media': media ?? [],
      'likes': [],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleCommentLike(String postId, String commentId, String userId) async {
    final docRef = _db.collection('posts').doc(postId).collection('comments').doc(commentId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      List<String> likes = List<String>.from(snapshot.data()?['likes'] ?? []);
      if (likes.contains(userId)) {
        likes.remove(userId);
      } else {
        likes.add(userId);
      }
      transaction.update(docRef, {'likes': likes});
    });
  }
}