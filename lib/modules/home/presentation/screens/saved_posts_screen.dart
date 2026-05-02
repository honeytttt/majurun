import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:majurun/modules/home/domain/entities/post.dart';
import 'package:majurun/modules/home/data/repositories/post_repository_impl.dart';
import 'package:majurun/modules/home/presentation/widgets/feed_item_wrapper.dart';

class SavedPostsScreen extends StatefulWidget {
  const SavedPostsScreen({super.key});

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  final _repo = PostRepositoryImpl();
  List<AppPost> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedPosts();
  }

  Future<void> _loadSavedPosts() async {
    setState(() => _loading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() => _loading = false);
        return;
      }

      final savedSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('savedPosts')
          .orderBy('savedAt', descending: true)
          .get();

      final futures = savedSnap.docs
          .map((d) => _repo.getPostById(d.id))
          .toList();

      final results = await Future.wait(futures);
      setState(() {
        _posts = results.whereType<AppPost>().toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Saved Posts',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE0E0E0)),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
          : _posts.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: const Color(0xFF00E676),
                  onRefresh: _loadSavedPosts,
                  child: ListView.builder(
                    itemCount: _posts.length,
                    itemBuilder: (context, i) => Container(
                      color: Colors.white,
                      child: FeedItemWrapper(
                        key: ValueKey(_posts[i].id),
                        post: _posts[i],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bookmark_border_rounded,
                size: 40,
                color: Color(0xFF00E676),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No saved posts yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the bookmark icon on any post to save it here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black45, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
