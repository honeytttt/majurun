import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Add to pubspec: intl: ^0.19.0
import 'package:mahurun/modules/home/domain/entities/post.dart';

class FeedItemWrapper extends StatelessWidget {
  final AppPost post;

  const FeedItemWrapper({super.key, required this.post});

  String _getRelativeTime(DateTime dateTime) {
    final duration = DateTime.now().difference(dateTime);
    if (duration.inDays > 7) return DateFormat.yMMMd().format(dateTime);
    if (duration.inDays > 0) return "${duration.inDays}d";
    if (duration.inHours > 0) return "${duration.inHours}h";
    if (duration.inMinutes > 0) return "${duration.inMinutes}m";
    return "just now";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(radius: 18, child: Icon(Icons.person)),
              const SizedBox(width: 10),
              Text(post.username, style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(_getRelativeTime(post.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          Text(post.content),
          // Media Placeholder
          if (post.media.isNotEmpty)
            Container(
              height: 200,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.play_circle_outline, size: 50, color: Colors.grey),
            ),
          const Divider(),
          Row(
            children: [
              _actionBtn(Icons.favorite_border, post.likes.length.toString()),
              _actionBtn(Icons.chat_bubble_outline, post.comments.length.toString()),
              _actionBtn(Icons.repeat, "Quote"),
            ],
          ),
          // Nested Comments Display (Simplified for brevity)
          if (post.comments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16.0, top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: post.comments.map((comment) => _buildComment(comment)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildComment(AppComment comment) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("${comment.username}: ${comment.text}", style: const TextStyle(fontSize: 13)),
          Row(
            children: [
              Text(_getRelativeTime(comment.createdAt), style: const TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(width: 10),
              const Text("Like", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              const Text("Reply", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}