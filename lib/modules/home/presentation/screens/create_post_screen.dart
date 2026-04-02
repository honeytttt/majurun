import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:majurun/core/services/storage_service.dart';
import 'package:majurun/core/services/post_limit_service.dart';
import 'package:majurun/modules/home/domain/entities/post.dart';
import 'package:majurun/modules/home/data/repositories/post_repository_impl.dart';
import 'package:video_player/video_player.dart';
import 'dart:io' show File;

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _controller = TextEditingController();
  final StorageService _storage = StorageService();
  final PostRepositoryImpl _postRepo = PostRepositoryImpl();
  final PostLimitService _limitService = PostLimitService();
  
  final List<PostMedia> _mediaList = [];
  bool _isUploading = false;
  // Limit state kept only for backend validation in _handlePost — not shown upfront
  Map<String, int> _remainingPosts = {};
  bool _isLoadingLimits = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    // Load limits silently for backend validation only — not shown in UI
    _loadRemainingPosts();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Load how many posts user can still make today
  Future<void> _loadRemainingPosts() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final remaining = await _limitService.getRemainingPostsToday(userId);
      if (mounted) {
        setState(() {
          _remainingPosts = remaining;
          _isLoadingLimits = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading post limits: $e');
      if (mounted) {
        setState(() {
          _remainingPosts = {
            'total': PostLimitService.maxTotalPostsPerDay,
            'image': PostLimitService.maxImagePostsPerDay,
            'video': PostLimitService.maxVideoPostsPerDay,
            'text': PostLimitService.maxTextPostsPerDay,
          };
          _isLoadingLimits = false;
        });
      }
    }
  }

  /// Get remaining posts for current post type
  int get _totalRemaining => _remainingPosts['total'] ?? PostLimitService.maxTotalPostsPerDay;

  bool get _shouldShowWarning => _totalRemaining <= 5;

  /// Pick and validate media (image or video)
  Future<void> _pickMedia(bool isVideo) async {
    // ✅ Check image count limit BEFORE picking (only for images)
    if (!isVideo && _mediaList.where((m) => m.type == MediaType.image).length >= PostLimitService.maxImagesPerPost) {
      _showError(_limitService.getImageCountMessage());
      return;
    }

    final picker = ImagePicker();
    final XFile? file = isVideo
        ? await picker.pickVideo(source: ImageSource.gallery)
        : await picker.pickImage(source: ImageSource.gallery);

    if (file == null) return;

    try {
      final bytes = await file.readAsBytes();
      
      // ✅ VALIDATE FILE SIZE
      final sizeError = _limitService.validateMediaUpload(
        fileSizeBytes: bytes.length,
        isVideo: isVideo,
      );
      
      if (sizeError != null) {
        _showError(sizeError);
        return;
      }

      // ✅ VALIDATE VIDEO DURATION (if it's a video)
      if (isVideo) {
        final durationValid = await _validateVideoDuration(file.path);
        if (!durationValid) {
          _showError(_limitService.getVideoDurationMessage());
          return;
        }
      }

      // Show file size to user
      final sizeStr = _limitService.formatFileSize(bytes.length);
      debugPrint('📎 ${isVideo ? "Video" : "Image"} size: $sizeStr');

      // Upload to S3
      setState(() => _isUploading = true);
      
      final url = await _storage.uploadMedia(bytes, file.name, isVideo);

      if (url != null && mounted) {
        setState(() {
          _mediaList.add(PostMedia(
            url: url,
            type: isVideo ? MediaType.video : MediaType.image,
          ));
        });
        
        _showSuccess('${isVideo ? "Video" : "Image"} uploaded ($sizeStr)');
      } else {
        _showError('Upload failed. Please try again.');
      }
    } catch (e) {
      debugPrint("❌ Media upload error: $e");
      _showError('Upload failed: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /// Validate video duration using video_player
  Future<bool> _validateVideoDuration(String videoPath) async {
    try {
      debugPrint('🎬 Checking video duration...');
      
      // Initialize video player to get duration
      final controller = kIsWeb
          ? VideoPlayerController.networkUrl(Uri.parse(videoPath))
          : VideoPlayerController.file(File(videoPath));
      
      await controller.initialize();
      
      final durationSeconds = controller.value.duration.inSeconds;
      debugPrint('⏱️ Video duration: $durationSeconds seconds');
      
      controller.dispose();
      
      return _limitService.isVideoDurationValid(durationSeconds);
    } catch (e) {
      debugPrint('⚠️ Could not check video duration: $e');
      // If we can't check duration, allow the video (don't block user)
      return true;
    }
  }

  /// Create and submit the post
  Future<void> _handlePost() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _mediaList.isEmpty) {
      _showError('Please add some content or media');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('Please log in to post');
      return;
    }

    // ✅ VALIDATE POST LIMITS
    final hasVideo = _mediaList.any((m) => m.type == MediaType.video);
    final imageCount = _mediaList.where((m) => m.type == MediaType.image).length;

    final validationError = await _limitService.validatePost(
      userId: user.uid,
      imageCount: imageCount,
      hasVideo: hasVideo,
    );
    
    if (validationError != null) {
      _showError(validationError);
      return;
    }

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

      if (mounted) {
        _showSuccess('Post created successfully! 🎉');
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("❌ Post creation failed: $e");
      _showError('Failed to create post: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /// Show error message
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show success message
  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF00E676),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
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
          // POST BUTTON
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _isUploading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF00E676),
                      ),
                    ),
                  )
                : TextButton(
                    onPressed: canPost ? _handlePost : null,
                    child: Text(
                      "POST",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: canPost ? const Color(0xFF00E676) : Colors.grey,
                      ),
                    ),
                  ),
          )
        ],
      ),
      body: Column(
        children: [
          // TEXT INPUT
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: null,
              autofocus: true,
              style: const TextStyle(fontSize: 16),
              decoration: const InputDecoration(
                hintText: "What's on your mind?",
                hintStyle: TextStyle(color: Colors.grey),
                contentPadding: EdgeInsets.all(20),
                border: InputBorder.none,
              ),
            ),
          ),

          // MEDIA PREVIEW
          if (_mediaList.isNotEmpty)
            Container(
              height: 140,
              padding: const EdgeInsets.symmetric(vertical: 8),
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
                                ? Image.network(
                                    media.url,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Center(
                                        child: Icon(Icons.error, color: Colors.red),
                                      );
                                    },
                                  )
                                : const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.videocam, size: 40, color: Colors.grey),
                                        SizedBox(height: 4),
                                        Text('Video', style: TextStyle(color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                        // Remove button
                        Positioned(
                          right: 4,
                          top: 4,
                          child: GestureDetector(
                            onTap: () => setState(() => _mediaList.removeAt(i)),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
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

          // MEDIA PICKER BUTTONS
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  // Image button
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Photo', style: TextStyle(fontSize: 13)),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF00E676),
                      ),
                      onPressed: _isUploading ? null : () => _pickMedia(false),
                    ),
                  ),

                  // Video button
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.videocam_outlined),
                      label: const Text('Video', style: TextStyle(fontSize: 13)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      onPressed: _isUploading ? null : () => _pickMedia(true),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
