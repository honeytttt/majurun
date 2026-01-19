import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:majurun/core/services/cloudinary_service.dart';
import 'package:majurun/modules/home/domain/entities/post.dart';
import 'package:majurun/modules/home/data/repositories/post_repository_impl.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _controller = TextEditingController();
  final CloudinaryService _cloudinary = CloudinaryService();
  final PostRepositoryImpl _postRepo = PostRepositoryImpl();
  final List<PostMedia> _mediaList = [];
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(bool isVideo) async {
    final picker = ImagePicker();
    final XFile? file = isVideo
        ? await picker.pickVideo(source: ImageSource.gallery)
        : await picker.pickImage(source: ImageSource.gallery);

    if (file == null) return;

    setState(() => _isUploading = true);
    try {
      final Uint8List bytes = await file.readAsBytes();

      // Note: Make sure CloudinaryService.uploadMedia accepts these 3 positional parameters:
      // Uint8List bytes, String filename, bool isVideo
      String? url = await _cloudinary.uploadMedia(bytes, file.name, isVideo);

      if (url != null && mounted) {
        setState(() {
          _mediaList.add(PostMedia(
            url: url,
            type: isVideo ? MediaType.video : MediaType.image,
          ));
        });
      }
    } catch (e) {
      debugPrint("Media upload error: $e");
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _handlePost() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _mediaList.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isUploading = true);

    try {
      const uuid = Uuid();
      final post = AppPost(
        id: uuid.v4(),
        userId: user.uid,
        username: user.displayName ?? "Runner",
        content: text,
        media: List.from(_mediaList),
        createdAt: DateTime.now(),
        likes: const [],
        comments: const [],
        quotedPostId: null,
      );

      await _postRepo.createPost(post);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Post creation failed: $e");
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasContent =
        _controller.text.trim().isNotEmpty || _mediaList.isNotEmpty;
    final bool canPost = hasContent && !_isUploading;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("New Post", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _isUploading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton(
                    onPressed: canPost ? _handlePost : null,
                    child: Text(
                      "POST",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: canPost ? Colors.blue : Colors.grey,
                      ),
                    ),
                  ),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: null,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: "What's on your mind?",
                contentPadding: EdgeInsets.all(20),
                border: InputBorder.none,
              ),
            ),
          ),
          if (_mediaList.isNotEmpty)
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _mediaList.length,
                itemBuilder: (context, i) {
                  final media = _mediaList[i];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 120,
                            height: 120,
                            color: Colors.grey[200],
                            child: media.type == MediaType.image
                                ? Image.network(media.url, fit: BoxFit.cover)
                                : const Center(
                                    child: Icon(
                                      Icons.videocam,
                                      size: 40,
                                      color: Colors.grey,
                                    ),
                                  ),
                          ),
                        ),
                        Positioned(
                          right: 4,
                          top: 4,
                          child: GestureDetector(
                            onTap: () => setState(() => _mediaList.removeAt(i)),
                            child: const CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.black54,
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const Divider(height: 1),
          SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image_outlined, color: Colors.blue),
                  onPressed: () => _pickMedia(false),
                ),
                IconButton(
                  icon: const Icon(Icons.videocam_outlined, color: Colors.red),
                  onPressed: () => _pickMedia(true),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}