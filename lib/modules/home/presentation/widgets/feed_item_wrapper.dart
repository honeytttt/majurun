import 'package:flutter/material.dart';
import 'package:majurun/modules/home/domain/entities/post.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'dart:html' as html; // Used for Web Downloads

class FeedItemWrapper extends StatelessWidget {
  final AppPost post;
  const FeedItemWrapper({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0.5,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.blueGrey, child: Icon(Icons.person, color: Colors.white)),
            title: Text(post.username, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(DateFormat('MMM d, HH:mm').format(post.createdAt)),
          ),
          if (post.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(post.content, style: const TextStyle(fontSize: 16)),
            ),
          if (post.media.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: _buildMedia(context, post.media.first),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.favorite_border), onPressed: () {}),
                Text("${post.likes.length}"),
                const SizedBox(width: 16),
                IconButton(icon: const Icon(Icons.chat_bubble_outline), onPressed: () {}),
                const Text("0"),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMedia(BuildContext context, PostMedia media) {
    if (media.type == MediaType.image) {
      return GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImage(imageUrl: media.url))),
        child: Hero(
          tag: media.url,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 500),
            child: Image.network(media.url, fit: BoxFit.contain),
          ),
        ),
      );
    } else {
      return VideoPlayerWidget(videoUrl: media.url);
    }
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  const VideoPlayerWidget({super.key, required this.videoUrl});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    await _videoController.initialize();
    _chewieController = ChewieController(
      videoPlayerController: _videoController,
      autoPlay: false,
      looping: false,
      aspectRatio: _videoController.value.aspectRatio,
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _videoController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      width: double.infinity,
      color: Colors.black,
      child: _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized
          ? Chewie(controller: _chewieController!)
          : const Center(child: CircularProgressIndicator()),
    );
  }
}

class FullScreenImage extends StatelessWidget {
  final String imageUrl;
  const FullScreenImage({super.key, required this.imageUrl});

  // Web-friendly download function
  void _downloadImage() {
    html.AnchorElement(href: imageUrl)
      ..setAttribute("download", "majurun_image.png")
      ..click();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _downloadImage,
            tooltip: "Download Image",
          ),
        ],
      ),
      body: Center(
        child: Hero(
          tag: imageUrl,
          child: InteractiveViewer(child: Image.network(imageUrl, fit: BoxFit.contain)),
        ),
      ),
    );
  }
}