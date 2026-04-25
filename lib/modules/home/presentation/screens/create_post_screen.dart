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

// Popular running hashtags for suggestions
const List<String> _kRunningTags = [
  'running', 'run', 'runner', 'runnerscommunity', 'runnersofinstagram',
  'marathon', 'halfmarathon', '5k', '10k', 'ultramarathon',
  'morningrun', 'eveningrun', 'trailrunning', 'roadrunning',
  'fitness', 'workout', 'training', 'cardio', 'exercise',
  'health', 'healthy', 'healthylifestyle', 'active', 'activelife',
  'motivation', 'mondaymotivation', 'fitnessmotivation', 'goals',
  'personalrecord', 'pr', 'pb', 'newrecord', 'pacemaker',
  'majurun', 'runmalaysia', 'runskuad',
  'strava', 'garmin', 'nike', 'adidas', 'runwithme',
];

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final StorageService _storage = StorageService();
  final PostRepositoryImpl _postRepo = PostRepositoryImpl();
  final PostLimitService _limitService = PostLimitService();

  final List<PostMedia> _mediaList = [];
  bool _isUploading = false;
  // ignore: unused_field
  Map<String, int> _remainingPosts = {};

  // Hashtag suggestion state
  List<String> _tagSuggestions = [];
  String _currentTagQuery = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _loadRemainingPosts();
  }

  void _onTextChanged() {
    setState(() {});
    _updateTagSuggestions();
  }

  void _updateTagSuggestions() {
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;
    if (cursor < 0 || cursor > text.length) {
      setState(() { _tagSuggestions = []; _currentTagQuery = ''; });
      return;
    }
    // Find the word the cursor is in
    final before = text.substring(0, cursor);
    final hashIndex = before.lastIndexOf('#');
    if (hashIndex == -1) {
      setState(() { _tagSuggestions = []; _currentTagQuery = ''; });
      return;
    }
    // Check there's no space between # and cursor
    final partial = before.substring(hashIndex + 1);
    if (partial.contains(' ') || partial.contains('\n')) {
      setState(() { _tagSuggestions = []; _currentTagQuery = ''; });
      return;
    }
    _currentTagQuery = partial.toLowerCase();
    if (_currentTagQuery.isEmpty) {
      // Show top suggestions when just # is typed
      setState(() { _tagSuggestions = _kRunningTags.take(8).toList(); });
      return;
    }
    final matches = _kRunningTags
        .where((t) => t.startsWith(_currentTagQuery))
        .take(6)
        .toList();
    setState(() { _tagSuggestions = matches; });
  }

  void _insertTag(String tag) {
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;
    if (cursor < 0) return;
    final before = text.substring(0, cursor);
    final after = text.substring(cursor);
    final hashIndex = before.lastIndexOf('#');
    if (hashIndex == -1) return;
    final newText = '${text.substring(0, hashIndex)}#$tag $after';
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: hashIndex + tag.length + 2),
    );
    setState(() { _tagSuggestions = []; _currentTagQuery = ''; });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
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
        });
      }
    }
  }

  /// Show a bottom sheet to pick photo source (Camera or Gallery), then pick.
  Future<void> _showPhotoSourceSheet() async {
    if (_mediaList.where((m) => m.type == MediaType.image).length >= PostLimitService.maxImagesPerPost) {
      _showError(_limitService.getImageCountMessage());
      return;
    }
    ImageSource? source;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF7ED957), size: 20),
                SizedBox(width: 10),
                Text('Add Photo', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _sourceBtn(
                  icon: Icons.camera_alt_outlined,
                  label: 'Camera',
                  onTap: () { source = ImageSource.camera; Navigator.of(ctx).pop(); },
                )),
                const SizedBox(width: 12),
                Expanded(child: _sourceBtn(
                  icon: Icons.photo_library_outlined,
                  label: 'Gallery',
                  onTap: () { source = ImageSource.gallery; Navigator.of(ctx).pop(); },
                )),
              ],
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickMedia(false, source: source!);
  }

  Widget _sourceBtn({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF2D7A3E),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  /// Pick and validate media (image or video)
  Future<void> _pickMedia(bool isVideo, {ImageSource source = ImageSource.gallery}) async {
    // ✅ Check image count limit BEFORE picking (only for images)
    if (!isVideo && _mediaList.where((m) => m.type == MediaType.image).length >= PostLimitService.maxImagesPerPost) {
      _showError(_limitService.getImageCountMessage());
      return;
    }

    final picker = ImagePicker();
    final XFile? file = isVideo
        ? await picker.pickVideo(source: ImageSource.gallery)
        : await picker.pickImage(source: source, imageQuality: 85, maxWidth: 1080);

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
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Column(
        children: [
          // TEXT INPUT
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              maxLines: null,
              autofocus: true,
              style: const TextStyle(fontSize: 16),
              decoration: const InputDecoration(
                hintText: "What's on your mind? Type # for tags",
                hintStyle: TextStyle(color: Colors.grey),
                contentPadding: EdgeInsets.all(20),
                border: InputBorder.none,
              ),
            ),
          ),

          // HASHTAG SUGGESTIONS
          if (_tagSuggestions.isNotEmpty)
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                itemCount: _tagSuggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final tag = _tagSuggestions[i];
                  return GestureDetector(
                    onTap: () => _insertTag(tag),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '#$tag',
                        style: const TextStyle(
                          color: Color(0xFF00897B),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
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
                      onPressed: _isUploading ? null : _showPhotoSourceSheet,
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
        ), // Column
      ), // GestureDetector
    );
  }
}
