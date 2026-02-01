import 'package:cloud_firestore/cloud_firestore.dart';

/// A simplified post model for displaying run-related posts.
/// Used in the run history stream.
class RunPost {
  final String id;
  final String content;
  final String? videoUrl;
  final DateTime timestamp;

  const RunPost({
    required this.id,
    required this.content,
    this.videoUrl,
    required this.timestamp,
  });

  factory RunPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    // Support both 'createdAt' (new) and 'timestamp' (legacy) fields
    final ts = data['createdAt'] ?? data['timestamp'];
    return RunPost(
      id: doc.id,
      content: data['content'] ?? '',
      videoUrl: data['videoUrl'],
      timestamp: ts is Timestamp ? ts.toDate() : DateTime.now(),
    );
  }
}
