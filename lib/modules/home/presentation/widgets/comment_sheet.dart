import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/services/cloudinary_service.dart';
import '../../data/repositories/post_repository_impl.dart';

class CommentSheet extends StatefulWidget {
  final String postId;
  const CommentSheet({super.key, required this.postId});

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  final TextEditingController _controller = TextEditingController();
  final PostRepositoryImpl _postRepo = PostRepositoryImpl();
  final CloudinaryService _cloudinary = CloudinaryService();
  final ImagePicker _picker = ImagePicker();

  String? replyingToId;
  String? replyingToUsername;
  Uint8List? selectedMediaBytes;
  String? selectedMediaName;
  bool isVideo = false;
  bool isUploading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // FIXED: Restored missing _pickMedia method
  Future<void> _pickMedia(bool video) async {
    final XFile? file = video
        ? await _picker.pickVideo(source: ImageSource.gallery)
        : await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        selectedMediaBytes = bytes;
        selectedMediaName = file.name;
        isVideo = video;
      });
    }
  }

  // FIXED: Restored missing _submitComment method
  void _submitComment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || (_controller.text.trim().isEmpty && selectedMediaBytes == null)) return;

    setState(() => isUploading = true);

    List<Map<String, dynamic>> mediaList = [];
    if (selectedMediaBytes != null) {
      String? url = await _cloudinary.uploadMedia(selectedMediaBytes!, selectedMediaName!, isVideo);
      if (url != null) {
        mediaList.add({'url': url, 'type': isVideo ? 'video' : 'image'});
      }
    }

    await _postRepo.addComment(
      postId: widget.postId,
      userId: user.uid,
      username: user.displayName ?? "Runner",
      content: _controller.text.trim(),
      parentId: replyingToId,
      media: mediaList,
    );

    if (!mounted) return;
    _controller.clear();
    setState(() {
      replyingToId = null;
      replyingToUsername = null;
      selectedMediaBytes = null;
      isUploading = false;
    });
  }

  Future<void> _shareCommentExternally(String content, String author) async {
    final String shareText = 'Check out this comment by $author on Majurun: "$content"';
    await SharePlus.instance.share(ShareParams(text: shareText, subject: 'Majurun Comment'));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Comments",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _postRepo.getCommentsStream(widget.postId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No comments yet."));
                }

                final all = snapshot.data!;
                final topLevel = all.where((c) => c['parentId'] == null).toList();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: topLevel.length,
                  itemBuilder: (context, index) {
                    final comment = topLevel[index];
                    final replies = all.where((c) => c['parentId'] == comment['id']).toList();
                    return _buildCommentNode(comment, replies);
                  },
                );
              },
            ),
          ),
          if (isUploading) const LinearProgressIndicator(),
          if (selectedMediaBytes != null) _buildMediaPreview(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildCommentNode(Map<String, dynamic> comment, List<Map<String, dynamic>> replies) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCommentItem(comment),
        if (replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Column(
              children: replies.map((r) => _buildCommentItem(r)).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
    final List likes = comment['likes'] as List? ?? [];
    final bool isLiked = likes.contains(currentUserId);
    final List mediaList = comment['media'] as List? ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment['username'] ?? "Runner",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      if (comment['content'] != null && comment['content'].toString().isNotEmpty)
                        Text(comment['content']),
                      if (mediaList.isNotEmpty) _buildCommentMedia(mediaList.first),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Text(
                      timeago.format((comment['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now()),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => setState(() {
                        replyingToId = comment['id'];
                        replyingToUsername = comment['username'];
                      }),
                      child: const Text(
                        "Reply",
                        style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share, size: 14, color: Colors.grey),
                      onPressed: () => _shareCommentExternally(
                        comment['content'] ?? "",
                        comment['username'] ?? "Runner",
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 16,
                        color: isLiked ? Colors.red : Colors.grey,
                      ),
                      onPressed: () => _postRepo.toggleCommentLike(
                        widget.postId,
                        comment['id'],
                        currentUserId,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text("${likes.length}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentMedia(Map<String, dynamic> media) {
    bool isMediaVideo = media['type'] == 'video';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: isMediaVideo
            ? CommentVideoPlayer(url: media['url'])
            : Image.network(
                media['url'],
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
              ),
      ),
    );
  }

  Widget _buildMediaPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.centerLeft,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: isVideo
                ? Container(
                    width: 80,
                    height: 80,
                    color: Colors.black,
                    child: const Icon(Icons.videocam, color: Colors.white),
                  )
                : Image.memory(selectedMediaBytes!, width: 80, height: 80, fit: BoxFit.cover),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: GestureDetector(
              onTap: () => setState(() => selectedMediaBytes = null),
              child: const CircleAvatar(
                radius: 10,
                backgroundColor: Colors.red,
                child: Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyingToId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    "Replying to @$replyingToUsername",
                    style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() {
                      replyingToId = null;
                      replyingToUsername = null;
                    }),
                    child: const Icon(Icons.cancel, size: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              IconButton(icon: const Icon(Icons.image_outlined), onPressed: () => _pickMedia(false)),
              IconButton(icon: const Icon(Icons.videocam_outlined), onPressed: () => _pickMedia(true)),
              Expanded(
                child: TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: "Write a comment...",
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.blue),
                onPressed: isUploading ? null : _submitComment,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CommentVideoPlayer extends StatefulWidget {
  final String url;
  const CommentVideoPlayer({super.key, required this.url});
  @override
  State<CommentVideoPlayer> createState() => _CommentVideoPlayerState();
}

class _CommentVideoPlayerState extends State<CommentVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() => _initialized = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const SizedBox(
        height: 150,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return GestureDetector(
      onTap: () => setState(() => _controller.value.isPlaying ? _controller.pause() : _controller.play()),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),
          if (!_controller.value.isPlaying)
            const Icon(Icons.play_circle_fill, size: 50, color: Colors.white70),
        ],
      ),
    );
  }
}