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
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            child: const Center(
              child: SizedBox(width: 20, height: 2, child: LinearProgressIndicator())
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return Container(
             width: double.infinity,
             padding: const EdgeInsets.all(12),
             margin: const EdgeInsets.symmetric(vertical: 8),
             decoration: BoxDecoration(
               color: Colors.grey.withValues(alpha: 0.05),
               borderRadius: BorderRadius.circular(12),
               border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
             ),
             child: const Text(
               "This post is no longer available.",
               style: TextStyle(fontSize: 13, color: Colors.grey, fontStyle: FontStyle.italic)
             ),
          );
        }

        final original = snapshot.data!;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 4, bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(12),
            color: Colors.blue.withValues(alpha: 0.02),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 14, color: Colors.blue),
                  const SizedBox(width: 6),
                  Text(
                    original.username,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.blueAccent
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                original.content.isEmpty ? "[Media or Repost]" : original.content,
                style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.3),
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