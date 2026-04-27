import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:majurun/modules/home/domain/entities/post.dart';
import 'package:majurun/modules/home/presentation/widgets/feed_item_wrapper.dart';

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
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E676)),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('Something went wrong. Try again.', style: TextStyle(color: Colors.black45)),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tag_rounded, size: 72, color: Colors.black12),
                  const SizedBox(height: 16),
                  Text(
                    '#$tag',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No posts with this hashtag yet.\nBe the first to use it!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black38, fontSize: 14, height: 1.5),
                  ),
                ],
              ),
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
