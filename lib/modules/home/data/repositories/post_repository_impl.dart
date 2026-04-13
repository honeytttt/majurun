import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:majurun/core/constants/firestore_paths.dart';
import 'package:majurun/core/services/logging_service.dart';
import 'package:majurun/core/services/user_stats_service.dart';
import 'package:majurun/core/services/notification_service.dart';
import 'package:majurun/modules/notifications/domain/entities/app_notification.dart';
import '../../domain/entities/post.dart';

class PostRepositoryImpl {
  final FirebaseFirestore _db;
  final _log = LoggingService.instance.withTag('PostRepo');

  // Pagination state
  static const int _pageSize = 20;
  DocumentSnapshot? _lastDocument;
  bool _hasMorePosts = true;
  final List<AppPost> _cachedPosts = [];

  PostRepositoryImpl({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// Check if more posts are available
  bool get hasMorePosts => _hasMorePosts;

  /// Get cached posts count
  int get cachedPostsCount => _cachedPosts.length;

  /// Reset pagination state (call on refresh)
  void resetPagination() {
    _lastDocument = null;
    _hasMorePosts = true;
    _cachedPosts.clear();
  }

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

    // For run auto-posts, mapImageUrl and selfieUrl are stored as top-level fields
    // (not inside the 'media' array). Build the feed media list with the right priority:
    //   - selfie first  → post_card shows selfie in the feed when user took one
    //   - map only      → shown when user skipped the selfie prompt
    // Profile/history grids use their own _parseMedia() which always reads mapImageUrl,
    // so history always shows the map regardless of what we do here.
    if (mediaList.isEmpty) {
      final selfieUrl = data['selfieUrl']?.toString();
      final mapImageUrl = data['mapImageUrl']?.toString();
      if (selfieUrl != null && selfieUrl.isNotEmpty) {
        mediaList.add(PostMedia(url: selfieUrl, type: MediaType.image));
      } else if (mapImageUrl != null && mapImageUrl.isNotEmpty) {
        mediaList.add(PostMedia(url: mapImageUrl, type: MediaType.image));
      }
    }

    List<LatLng>? routePoints;
    if (data['routePoints'] != null && data['routePoints'] is List) {
      final List<dynamic> pts = data['routePoints'];
      routePoints = pts
          .map((p) {
            try {
              if (p is Map) {
                // Handle both 'lat'/'lng' (new) and 'latitude'/'longitude' (legacy) formats
                final lat = ((p['lat'] ?? p['latitude']) as num?)?.toDouble();
                final lng = ((p['lng'] ?? p['longitude']) as num?)?.toDouble();
                if (lat != null && lng != null) return LatLng(lat, lng);
              }
            } catch (_) {}
            return null;
          })
          .whereType<LatLng>()
          .toList();
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

  /// Real-time stream for initial page of posts
  Stream<List<AppPost>> getPostStream() {
    _log.d('Fetching posts stream (limit $_pageSize)');
    return _db
        .collection(FirestoreCollections.posts)
        .orderBy(PostFields.createdAt, descending: true)
        .limit(_pageSize)
        .snapshots()
        .map((snapshot) {
      _log.d('Received ${snapshot.docs.length} posts');
      final posts = <AppPost>[];
      for (final doc in snapshot.docs) {
        try {
          posts.add(_mapDocToAppPost(doc));
        } catch (e) {
          _log.w('Error mapping post ${doc.id}', error: e);
        }
      }

      // Only initialise the cursor on first load — stream events must NOT
      // overwrite the cursor that loadMorePosts() advances, otherwise the
      // user sees page 1 repeating after every Firestore update (like, comment).
      if (snapshot.docs.isNotEmpty) {
        _lastDocument ??= snapshot.docs.last;
      }
      _cachedPosts
        ..clear()
        ..addAll(posts);

      return posts;
    });
  }

  /// Load more posts for infinite scroll - cursor-based pagination
  Future<List<AppPost>> loadMorePosts() async {
    if (!_hasMorePosts || _lastDocument == null) {
      _log.d('No more posts to load');
      return [];
    }

    try {
      _log.d('Loading more posts after ${_lastDocument!.id}');
      final snapshot = await _db
          .collection(FirestoreCollections.posts)
          .orderBy(PostFields.createdAt, descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_pageSize)
          .get();

      final newPosts = <AppPost>[];
      for (final doc in snapshot.docs) {
        try {
          newPosts.add(_mapDocToAppPost(doc));
        } catch (e) {
          _log.w('Error mapping post ${doc.id}', error: e);
        }
      }

      // Update pagination state
      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
        _cachedPosts.addAll(newPosts);
      }
      _hasMorePosts = snapshot.docs.length >= _pageSize;

      _log.d('Loaded ${newPosts.length} more posts, hasMore: $_hasMorePosts');
      return newPosts;
    } catch (e) {
      _log.e('Error loading more posts', error: e);
      return [];
    }
  }

  /// Get all currently cached posts
  List<AppPost> getCachedPosts() => List.unmodifiable(_cachedPosts);

  Future<void> createPost(
    AppPost post, {
    double? numericDistance,
    int? avgBpm,
    List<int>? splits,
    String type = 'regular',
    bool updateUserStats = true, // new optional (won't break callers)
  }) async {
    try {
      await _db.collection(FirestoreCollections.posts).doc(post.id).set({
        PostFields.userId: post.userId,
        PostFields.username: post.username,
        PostFields.content: post.content,
        PostFields.distance: numericDistance,
        PostFields.avgBpm: avgBpm,
        PostFields.splits: splits,
        PostFields.type: type,
        PostFields.media: post.media
            .map((m) => {
                  'url': m.url,
                  'type': m.type == MediaType.video ? 'video' : 'image'
                })
            .toList(),
        PostFields.createdAt: FieldValue.serverTimestamp(),
        PostFields.likes: [],
        if (post.quotedPostId != null) PostFields.quotedPostId: post.quotedPostId,
        if (post.routePoints != null)
          PostFields.routePoints: post.routePoints!
              .map((p) => {'lat': p.latitude, 'lng': p.longitude})
              .toList(),
      });

      // ✅ centralized postsCount increment
      if (updateUserStats) {
        await UserStatsService().incrementPosts(post.userId);
      }
      
      // ✅ Notify subscribers of new post
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          await NotificationService().notifySubscribersOfPost(
            posterUserId: post.userId,
            posterUsername: post.username,
            posterPhotoUrl: currentUser.photoURL,
            postId: post.id,
          );
          _log.i('Notified subscribers of new post');
        }
      } catch (e) {
        _log.w('Error notifying subscribers', error: e);
      }
    } catch (e) {
      _log.e('Error creating post', error: e);
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      await _db.collection(FirestoreCollections.posts).doc(postId).delete();
    } catch (e) {
      _log.e('Error deleting post', error: e);
    }
  }

  Future<AppPost?> getPostById(String postId) async {
    try {
      final doc = await _db.collection(FirestoreCollections.posts).doc(postId).get();
      if (!doc.exists) return null;
      return _mapDocToAppPost(doc);
    } catch (e) {
      _log.e('Error fetching post', error: e);
      return null;
    }
  }

  Future<void> toggleLike(String postId, String userId) async {
    final docRef = _db.collection(FirestoreCollections.posts).doc(postId);

    bool wasLiked = false;
    String? postOwnerId;

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      // Get post owner
      postOwnerId = snapshot.data()?[PostFields.userId];

      List<String> likes = List<String>.from(snapshot.data()?[PostFields.likes] ?? []);
      wasLiked = likes.contains(userId);

      if (wasLiked) {
        likes.remove(userId);
      } else {
        likes.add(userId);
      }
      transaction.update(docRef, {PostFields.likes: likes});
    });
    
    // ✅ Create like notification (only when liking, not unliking, and not own post)
    if (!wasLiked && postOwnerId != null && postOwnerId != userId) {
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          await NotificationService().createNotification(
            targetUserId: postOwnerId!,
            type: NotificationType.like,
            fromUserId: userId,
            fromUsername: currentUser.displayName ?? 'Runner',
            fromUserPhotoUrl: currentUser.photoURL,
            message: 'liked your post',
            metadata: {'postId': postId},
          );
          _log.i('Like notification sent to $postOwnerId');
        }
      } catch (e) {
        _log.w('Error creating like notification', error: e);
      }
    }
  }

  Future<void> repost(AppPost originalPost, String userId, String username) async {
    try {
      final String targetId = originalPost.quotedPostId != null &&
              originalPost.quotedPostId!.isNotEmpty
          ? originalPost.quotedPostId!
          : originalPost.id;

      await _db.collection(FirestoreCollections.posts).add({
        PostFields.userId: userId,
        PostFields.username: username,
        PostFields.content: '',
        PostFields.media: [],
        PostFields.createdAt: FieldValue.serverTimestamp(),
        PostFields.likes: [],
        PostFields.quotedPostId: targetId,
      });

      // NOTE: If you want reposts to count as posts, add incrementPosts(userId) here.
    } catch (e) {
      _log.e('Error during reposting', error: e);
    }
  }

  Stream<List<Map<String, dynamic>>> getCommentsStream(String postId) {
    return _db
        .collection(FirestoreCollections.posts)
        .doc(postId)
        .collection(FirestoreCollections.comments)
        .orderBy(CommentFields.createdAt, descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList());
  }

  Future<void> addComment({
    required String postId,
    required String userId,
    required String username,
    required String content,
    String? parentId,
    List<Map<String, dynamic>>? media,
  }) async {
    // Add comment
    await _db.collection(FirestoreCollections.posts).doc(postId).collection(FirestoreCollections.comments).add({
      CommentFields.userId: userId,
      CommentFields.username: username,
      CommentFields.content: content,
      CommentFields.parentId: parentId,
      CommentFields.media: media ?? [],
      CommentFields.likes: [],
      CommentFields.createdAt: FieldValue.serverTimestamp(),
    });

    // Create comment notification
    try {
      // Get post owner
      final postDoc = await _db.collection(FirestoreCollections.posts).doc(postId).get();
      final postOwnerId = postDoc.data()?[PostFields.userId];
      
      // Only notify if commenting on someone else's post
      if (postOwnerId != null && postOwnerId != userId) {
        final currentUser = FirebaseAuth.instance.currentUser;
        await NotificationService().createNotification(
          targetUserId: postOwnerId,
          type: NotificationType.comment,
          fromUserId: userId,
          fromUsername: username,
          fromUserPhotoUrl: currentUser?.photoURL,
          message: 'commented on your post',
          metadata: {'postId': postId},
        );
        _log.i('Comment notification sent to $postOwnerId');
      }
    } catch (e) {
      _log.w('Error creating comment notification', error: e);
    }
  }

  Future<void> toggleCommentLike(String postId, String commentId, String userId) async {
    final docRef = _db
        .collection(FirestoreCollections.posts)
        .doc(postId)
        .collection(FirestoreCollections.comments)
        .doc(commentId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      List<String> likes = List<String>.from(snapshot.data()?[CommentFields.likes] ?? []);
      if (likes.contains(userId)) {
        likes.remove(userId);
      } else {
        likes.add(userId);
      }
      transaction.update(docRef, {CommentFields.likes: likes});
    });
  }
}
