import 'package:flutter/material.dart';
import 'package:majurun/modules/home/data/repositories/post_repository_impl.dart';
import 'package:majurun/modules/home/domain/entities/post.dart';

class QuotedPostPreview extends StatefulWidget {
  final String postId;
  const QuotedPostPreview({super.key, required this.postId});

  @override
  State<QuotedPostPreview> createState() => _QuotedPostPreviewState();
}

class _QuotedPostPreviewState extends State<QuotedPostPreview> {
  // Cache the Future so widget rebuilds don't restart the Firestore fetch.
  late Future<AppPost?> _postFuture;

  @override
  void initState() {
    super.initState();
    _postFuture = PostRepositoryImpl().getPostById(widget.postId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppPost?>(
      future: _postFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 60,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF151520),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A2A3E)),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 2,
                child: LinearProgressIndicator(
                  backgroundColor: Color(0xFF2A2A3E),
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E676)),
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF151520),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2A2A3E)),
            ),
            child: const Text(
              "This post is no longer available.",
              style: TextStyle(fontSize: 13, color: Colors.white54, fontStyle: FontStyle.italic),
            ),
          );
        }

        final original = snapshot.data!;
        final hasMedia = original.media.isNotEmpty;
        final isVideo = hasMedia && original.media.first.type == MediaType.video;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 4, bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFF00E676).withValues(alpha: 0.05),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Author row
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 14, color: Color(0xFF00E676)),
                  const SizedBox(width: 6),
                  Text(
                    original.username,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF00E676),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Text content
              if (original.content.isNotEmpty)
                Text(
                  original.content,
                  style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.3),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

              // Media preview
              if (hasMedia) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: isVideo
                      ? Container(
                          height: 120,
                          color: Colors.black87,
                          child: const Center(
                            child: Icon(Icons.play_circle_outline, color: Colors.white70, size: 40),
                          ),
                        )
                      : Image.network(
                          original.media.first.url,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              height: 120,
                              color: const Color(0xFF151520),
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF00E676),
                                  ),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                ),
              ],

              // Route map indicator
              if (original.routePoints != null && original.routePoints!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map_outlined, size: 14, color: Color(0xFF00E676)),
                      SizedBox(width: 6),
                      Text(
                        'Run route included',
                        style: TextStyle(fontSize: 12, color: Color(0xFF00E676)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
