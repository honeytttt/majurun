import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:majurun/modules/home/domain/entities/post.dart';
import 'package:majurun/modules/home/presentation/widgets/feed_item_wrapper.dart';
import 'package:majurun/core/widgets/shimmer_loader.dart';
import 'package:majurun/core/widgets/empty_state_widget.dart';

/// Shows all posts tagged with a specific hashtag.
/// Navigated to when user taps a #tag in any post content.
class HashtagPostsScreen extends StatelessWidget {
  /// The tag word — without the '#' prefix (e.g. "running", "5k").
  final String tag;

  const HashtagPostsScreen({super.key, required this.tag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: Text(
          '#$tag',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .where('tags', arrayContains: tag)
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView.builder(
              itemCount: 4,
              itemBuilder: (_, __) => ShimmerLoader.postSkeleton(),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('Something went wrong. Try again.', style: TextStyle(color: Colors.black45)),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.tag_rounded,
              title: '#$tag',
              subtitle: 'No posts with this hashtag yet.\nBe the first to use it!',
            );
          }

          final posts = docs.map((doc) {
            try {
              final data = doc.data() as Map<String, dynamic>;
              return AppPost.fromMap(data, id: doc.id);
            } catch (_) {
              return null;
            }
          }).whereType<AppPost>().toList();

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, i) => Container(
              color: Colors.white,
              child: FeedItemWrapper(post: posts[i]),
            ),
          );
        },
      ),
    );
  }
}
