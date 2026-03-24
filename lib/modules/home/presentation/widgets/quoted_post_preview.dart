import 'package:flutter/material.dart';
import 'package:majurun/modules/home/data/repositories/post_repository_impl.dart';
import 'package:majurun/modules/home/domain/entities/post.dart';

class QuotedPostPreview extends StatelessWidget {
  final String postId;
  const QuotedPostPreview({super.key, required this.postId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppPost?>(
      future: PostRepositoryImpl().getPostById(postId),
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
               style: TextStyle(fontSize: 13, color: Colors.white54, fontStyle: FontStyle.italic)
             ),
          );
        }

        final original = snapshot.data!;

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
              Text(
                original.content.isEmpty ? "[Media or Repost]" : original.content,
                style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.3),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}