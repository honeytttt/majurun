import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:majurun/modules/home/domain/entities/post.dart';

class PostRepositoryImpl {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  AppPost _mapDocToAppPost(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    List<PostMedia> mediaList = [];
    if (data['media'] is List) {
      final List<dynamic> mediaData = data['media'];
      mediaList = mediaData.map((m) => PostMedia(
            url: m['url'] ?? '',
            type: m['type'] == 'video' ? MediaType.video : MediaType.image,
          )).toList();
    }

    List<LatLng>? routePoints;
    if (data['routePoints'] != null && data['routePoints'] is List) {
      final List<dynamic> pts = data['routePoints'];
      routePoints = pts.map((p) => LatLng(
        (p['lat'] as num).toDouble(), 
        (p['lng'] as num).toDouble()
      )).toList();
    }

    String content = data['content'] ?? '';
    String? quotedPostId = data['quotedPostId'];

    final trimmed = content.trim();
    final bool isLikelyBrokenRepostReference =
        trimmed.startsWith('Referencing Post ID:') ||
            (trimmed.length > 25 &&
                trimmed.contains('-') &&
                !trimmed.contains(' ') &&
                RegExp(r'^[0-9a-f-]{30,}$').hasMatch(trimmed));

    if (isLikelyBrokenRepostReference) {
      content = '';
      if (quotedPostId == null || quotedPostId.isEmpty) {
        quotedPostId = trimmed
            .replaceAll('Referencing Post ID:', '')
            .replaceAll('Referencing PostId:', '')
            .trim();
      }
    }

    return AppPost(
      id: doc.id,
      userId: data['userId'] ?? 'unknown',
      username: data['username'] ?? 'Runner',
      content: content,
      media: mediaList,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: List<String>.from(data['likes'] ?? []),
      comments: const [],
      quotedPostId: quotedPostId,
      routePoints: routePoints,
    );
  }

  // Updated to accept numeric distance
  Future<void> createPost(AppPost post, {double? numericDistance}) async {
    try {
      await _db.collection('posts').doc(post.id).set({
        'userId': post.userId,
        'username': post.username,
        'content': post.content,
        'distance': numericDistance, // Numeric storage for history
        'media': post.media.map((m) => {
              'url': m.url,
              'type': m.type == MediaType.video ? 'video' : 'image',
            }).toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'likes': [],
        if (post.quotedPostId != null) 'quotedPostId': post.quotedPostId,
        if (post.routePoints != null) 
          'routePoints': post.routePoints!.map((p) => {
            'lat': p.latitude,
            'lng': p.longitude,
          }).toList(),
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

  Stream<List<AppPost>> getPostStream() {
    return _db
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => _mapDocToAppPost(doc)).toList();
    });
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
      final String targetId = originalPost.quotedPostId != null &&
              originalPost.quotedPostId!.isNotEmpty
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

  Future<void> toggleCommentLike(
      String postId, String commentId, String userId) async {
    final docRef =
        _db.collection('posts').doc(postId).collection('comments').doc(commentId);
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