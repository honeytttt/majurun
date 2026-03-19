// @UI_LOCK: Complete Workout Player with GIF Exercises - 2026-02-27
// -----------------------------------------------------------------------
// Features: Exercise GIFs, timer, progress tracking, voice guidance
// Platform: iOS, Android, Web compatible
// -----------------------------------------------------------------------

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:majurun/modules/workout/data/workout_videos.dart';

class WorkoutPlayerScreen extends StatefulWidget {
  final String workoutType;
  final String workoutTitle;
  final Color accentColor;

  const WorkoutPlayerScreen({
    super.key,
    required this.workoutType,
    required this.workoutTitle,
    required this.accentColor,
  });

  @override
  State<WorkoutPlayerScreen> createState() => _WorkoutPlayerScreenState();
}

class _WorkoutPlayerScreenState extends State<WorkoutPlayerScreen>
    with TickerProviderStateMixin {
  // State
  List<Map<String, dynamic>> _exercises = [];
  int _currentExerciseIndex = 0;
  bool _isPlaying = false;
  bool _isResting = false;
  int _timeRemaining = 0;
  int _elapsedTime = 0;
  Timer? _timer;

  // Video controllers
  final Map<int, VideoPlayerController> _videoControllers = {};
  final Map<int, ChewieController> _chewieControllers = {};
  bool _videoInitialized = false;

  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Constants
  static const int restDuration = 15; // seconds between exercises
  static const Color darkBg = Color(0xFF0A0A0F);
  static const Color darkSurface = Color(0xFF151520);
  static const Color darkCard = Color(0xFF1A1A2E);

  @override
  void initState() {
    super.initState();
    _loadExercises();
    _setupAnimations();
    _setSystemUI();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  void _setSystemUI() {
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: darkBg,
        systemNavigationBarIconBrightness: Brightness.light,
      ));
    }
  }

  void _loadExercises() {
    _exercises = WorkoutVideoData.getExercisesByType(widget.workoutType);

    // If no exercises found for this type, use strength as default
    if (_exercises.isEmpty) {
      _exercises = WorkoutVideoData.strengthExercises;
    }

    // Set initial exercise time
    if (_exercises.isNotEmpty) {
      _timeRemaining = (_exercises[0]['duration'] as int?) ?? 30;
    }

    // Initialize video controller for first exercise
    _initializeVideoController(0);
  }

  Future<void> _initializeVideoController(int index) async {
    if (index >= _exercises.length) return;

    final exercise = _exercises[index];
    final videoUrl = exercise['videoUrl'] as String? ?? exercise['gifUrl'] as String?;

    if (videoUrl == null || !videoUrl.endsWith('.mp4')) {
      debugPrint('⚠️ Exercise $index: No valid MP4 URL - $videoUrl');
      return;
    }

    // Dispose existing controllers for this index
    _chewieControllers[index]?.dispose();
    _chewieControllers.remove(index);
    _videoControllers[index]?.removeListener(_onVideoStateChanged);
    _videoControllers[index]?.dispose();

    try {
      debugPrint('🎬 Initializing video $index: $videoUrl');
      final videoController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _videoControllers[index] = videoController;

      // Add listener to update UI when video state changes
      videoController.addListener(_onVideoStateChanged);

      await videoController.initialize();

      if (!videoController.value.isInitialized) {
        debugPrint('❌ Video $index failed to initialize');
        return;
      }

      debugPrint('✅ Video $index initialized: ${videoController.value.duration}');

      // Create Chewie controller for better playback handling
      final chewieController = ChewieController(
        videoPlayerController: videoController,
        autoPlay: index == _currentExerciseIndex,
        looping: true,
        showControls: false, // We have our own controls
        allowFullScreen: false,
        allowMuting: false,
        allowPlaybackSpeedChanging: false,
        placeholder: Container(color: darkSurface),
        errorBuilder: (context, errorMessage) {
          debugPrint('❌ Chewie error: $errorMessage');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, color: Colors.red.withValues(alpha: 0.7), size: 42),
                const SizedBox(height: 8),
                Text(
                  'Video failed to load',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
              ],
            ),
          );
        },
      );
      _chewieControllers[index] = chewieController;

      if (mounted) {
        setState(() => _videoInitialized = true);
      }

      // Pre-initialize next video (with delay to avoid overwhelming)
      if (index + 1 < _exercises.length) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _initializeVideoController(index + 1);
        });
      }
    } catch (e) {
      debugPrint('❌ Error initializing video $index: $e');
      // Remove failed controller
      _chewieControllers.remove(index);
      _videoControllers.remove(index);
    }
  }

  void _onVideoStateChanged() {
    if (!mounted) return;

    final videoController = _videoControllers[_currentExerciseIndex];
    final chewieController = _chewieControllers[_currentExerciseIndex];
    if (videoController == null || chewieController == null) return;

    // If workout is playing but video stopped/ended, restart it
    if (_isPlaying && videoController.value.isInitialized && !videoController.value.isPlaying) {
      // Check if it's not just buffering
      if (!videoController.value.isBuffering &&
          videoController.value.position < videoController.value.duration) {
        debugPrint('🔄 Video stopped unexpectedly, restarting...');
        chewieController.play();
      }
    }

    // Trigger rebuild when video state changes
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    // Dispose all Chewie controllers first
    for (final controller in _chewieControllers.values) {
      controller.dispose();
    }
    _chewieControllers.clear();
    // Then dispose video controllers
    for (final controller in _videoControllers.values) {
      controller.removeListener(_onVideoStateChanged);
      controller.dispose();
    }
    _videoControllers.clear();
    if (!kIsWeb) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values,
      );
    }
    super.dispose();
  }

  void _startWorkout() {
    setState(() => _isPlaying = true);
    _startTimer();
    // Ensure current video is playing
    _playCurrentVideo();
  }

  void _pauseWorkout() {
    setState(() => _isPlaying = false);
    _timer?.cancel();
    // Pause current video
    _pauseCurrentVideo();
  }

  void _playCurrentVideo() {
    final chewie = _chewieControllers[_currentExerciseIndex];
    if (chewie != null) {
      chewie.play();
      debugPrint('▶️ Playing video for exercise $_currentExerciseIndex');
    }
  }

  void _pauseCurrentVideo() {
    final chewie = _chewieControllers[_currentExerciseIndex];
    if (chewie != null) {
      chewie.pause();
      debugPrint('⏸️ Paused video for exercise $_currentExerciseIndex');
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _elapsedTime++;
        _timeRemaining--;

        if (_timeRemaining <= 0) {
          if (_isResting) {
            // Rest finished, move to next exercise
            _isResting = false;
            _currentExerciseIndex++;
            if (_currentExerciseIndex >= _exercises.length) {
              // Workout complete
              _completeWorkout();
            } else {
              _timeRemaining = (_exercises[_currentExerciseIndex]['duration'] as int?) ?? 30;
            }
          } else {
            // Exercise finished, start rest
            if (_currentExerciseIndex < _exercises.length - 1) {
              _isResting = true;
              _timeRemaining = restDuration;
            } else {
              _completeWorkout();
            }
          }
        }
      });
    });
  }

  void _completeWorkout() {
    _timer?.cancel();
    setState(() => _isPlaying = false);
    _showCompletionDialog();
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: widget.accentColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.celebration, color: widget.accentColor, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'Workout Complete!',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              '${_exercises.length} exercises completed',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
            ),
            Text(
              '${(_elapsedTime / 60).floor()}:${(_elapsedTime % 60).toString().padLeft(2, '0')} total time',
              style: TextStyle(color: widget.accentColor, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Close workout player
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.accentColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _skipExercise() {
    if (_currentExerciseIndex < _exercises.length - 1) {
      // Pause current video
      _pauseCurrentVideo();

      setState(() {
        _currentExerciseIndex++;
        _isResting = false;
        _timeRemaining = (_exercises[_currentExerciseIndex]['duration'] as int?) ?? 30;
      });

      // Play new video (if already initialized) or initialize it
      final chewieController = _chewieControllers[_currentExerciseIndex];
      if (chewieController != null) {
        chewieController.play();
      } else {
        // Will auto-play when initialized since it's now current exercise
        _initializeVideoController(_currentExerciseIndex);
      }
    }
  }

  void _previousExercise() {
    if (_currentExerciseIndex > 0) {
      // Pause current video
      _pauseCurrentVideo();

      setState(() {
        _currentExerciseIndex--;
        _isResting = false;
        _timeRemaining = (_exercises[_currentExerciseIndex]['duration'] as int?) ?? 30;
      });

      // Play previous video (should already be initialized)
      _playCurrentVideo();
    }
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_exercises.isEmpty) {
      return _buildEmptyState();
    }

    final currentExercise = _exercises[_currentExerciseIndex];

    return Scaffold(
      backgroundColor: darkBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isResting ? _buildRestScreen() : _buildExerciseScreen(currentExercise),
            ),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final progress = _exercises.isEmpty ? 0.0 : (_currentExerciseIndex + 1) / _exercises.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Close button
              GestureDetector(
                onTap: () => _showExitConfirmation(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: darkCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 22),
                ),
              ),
              // Workout title
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      Text(
                        widget.workoutTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Exercise ${_currentExerciseIndex + 1} of ${_exercises.length}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Time elapsed
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: darkCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer, color: widget.accentColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      _formatTime(_elapsedTime),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white12,
              color: widget.accentColor,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseScreen(Map<String, dynamic> exercise) {
    final videoUrl = exercise['videoUrl'] as String? ?? exercise['gifUrl'] as String?;
    final thumbnail = exercise['thumbnail'] as String?;
    final name = exercise['name'] as String? ?? 'Exercise';
    final reps = exercise['reps'] as String? ?? '10 reps';
    final sets = exercise['sets'] as int? ?? 3;
    final targetMuscles = (exercise['targetMuscles'] as List?)?.cast<String>() ?? [];
    final difficulty = exercise['difficulty'] as String? ?? 'Beginner';
    final isVideo = videoUrl != null && videoUrl.endsWith('.mp4');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Video/GIF Container
          Container(
            width: double.infinity,
            height: 280,
            decoration: BoxDecoration(
              color: darkCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: widget.accentColor.withValues(alpha: 0.3), width: 2),
              boxShadow: [
                BoxShadow(
                  color: widget.accentColor.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Video Player or Fallback
                  Builder(
                    builder: (context) {
                      final chewieController = _chewieControllers[_currentExerciseIndex];
                      final videoController = _videoControllers[_currentExerciseIndex];
                      final hasVideo = isVideo && chewieController != null &&
                          videoController != null && videoController.value.isInitialized;

                      if (hasVideo) {
                        // Use Chewie for better video playback
                        return Center(
                          key: ValueKey('chewie_$_currentExerciseIndex'),
                          child: AspectRatio(
                            aspectRatio: videoController.value.aspectRatio,
                            child: Chewie(controller: chewieController),
                          ),
                        );
                      } else if (isVideo) {
                        // Video is loading - show loading placeholder with thumbnail background
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            if (thumbnail != null)
                              CachedNetworkImage(
                                imageUrl: thumbnail,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => _buildIconPlaceholder(),
                                errorWidget: (context, url, error) => _buildIconPlaceholder(),
                              ),
                            Container(
                              color: Colors.black54,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: CircularProgressIndicator(
                                        color: widget.accentColor,
                                        strokeWidth: 3,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Loading video...',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.8),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      } else if (videoUrl != null && videoUrl.isNotEmpty) {
                        // GIF or image URL
                        return CachedNetworkImage(
                          imageUrl: videoUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => _buildGifPlaceholder(thumbnail),
                          errorWidget: (context, url, error) => _buildGifPlaceholder(thumbnail),
                        );
                      } else if (thumbnail != null) {
                        return CachedNetworkImage(
                          imageUrl: thumbnail,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => _buildGifPlaceholder(null),
                          errorWidget: (context, url, error) => _buildGifPlaceholder(null),
                        );
                      } else {
                        return _buildVideoLoadingPlaceholder(name);
                      }
                    },
                  ),

                  // Gradient overlay at bottom
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 80,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.8),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Difficulty badge
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _getDifficultyColor(difficulty).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        difficulty.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Exercise name
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Timer display
          ScaleTransition(
            scale: _isPlaying ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: widget.accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: widget.accentColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                _formatTime(_timeRemaining),
                style: TextStyle(
                  color: widget.accentColor,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Exercise details
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDetailChip(Icons.repeat, reps),
              const SizedBox(width: 12),
              _buildDetailChip(Icons.layers, '$sets sets'),
            ],
          ),

          const SizedBox(height: 16),

          // Target muscles
          if (targetMuscles.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: targetMuscles.map((muscle) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  muscle,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              )).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildGifPlaceholder(String? thumbnailUrl) {
    if (thumbnailUrl != null) {
      return CachedNetworkImage(
        imageUrl: thumbnailUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildIconPlaceholder(),
        errorWidget: (context, url, error) => _buildIconPlaceholder(),
      );
    }
    return _buildIconPlaceholder();
  }

  Widget _buildIconPlaceholder() {
    return Container(
      color: darkSurface,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center, size: 60, color: widget.accentColor.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              'Loading...',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoLoadingPlaceholder(String exerciseName) {
    return Container(
      color: darkSurface,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                color: widget.accentColor,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              exerciseName,
              style: TextStyle(
                color: widget.accentColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Loading video...',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: widget.accentColor, size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildRestScreen() {
    final nextExercise = _currentExerciseIndex < _exercises.length - 1
        ? _exercises[_currentExerciseIndex + 1]
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF3B82F6), width: 3),
            ),
            child: Center(
              child: Text(
                '$_timeRemaining',
                style: const TextStyle(
                  color: Color(0xFF3B82F6),
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'REST',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Take a breath!',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
          ),
          if (nextExercise != null) ...[
            const SizedBox(height: 24),
            Text(
              'UP NEXT',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: darkCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: widget.accentColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.fitness_center, color: widget.accentColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        nextExercise['name'] as String? ?? 'Next Exercise',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${nextExercise['reps']} x ${nextExercise['sets']} sets',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextButton(
            onPressed: _skipExercise,
            child: Text(
              'Skip Rest',
              style: TextStyle(color: widget.accentColor, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Previous
            _buildControlButton(
              icon: Icons.skip_previous_rounded,
              onTap: _currentExerciseIndex > 0 ? _previousExercise : null,
              size: 52,
            ),
            // Play/Pause
            GestureDetector(
              onTap: _isPlaying ? _pauseWorkout : _startWorkout,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [widget.accentColor, widget.accentColor.withValues(alpha: 0.8)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.accentColor.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.black,
                  size: 36,
                ),
              ),
            ),
            // Next/Skip
            _buildControlButton(
              icon: Icons.skip_next_rounded,
              onTap: _currentExerciseIndex < _exercises.length - 1 ? _skipExercise : null,
              size: 52,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onTap,
    required double size,
  }) {
    final isEnabled = onTap != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isEnabled ? darkCard : darkCard.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          border: Border.all(color: isEnabled ? Colors.white24 : Colors.white12),
        ),
        child: Icon(
          icon,
          color: isEnabled ? Colors.white : Colors.white38,
          size: size * 0.5,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Scaffold(
      backgroundColor: darkBg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.fitness_center, size: 80, color: widget.accentColor.withValues(alpha: 0.5)),
                const SizedBox(height: 24),
                const Text(
                  'No exercises found',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'Exercises for ${widget.workoutTitle} are being prepared',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.accentColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showExitConfirmation() {
    if (!_isPlaying && _elapsedTime == 0) {
      Navigator.pop(context);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('End Workout?', style: TextStyle(color: Colors.white)),
        content: Text(
          'You\'ve been working out for ${_formatTime(_elapsedTime)}. Are you sure you want to quit?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Continue', style: TextStyle(color: widget.accentColor)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close workout
            },
            child: const Text('End Workout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return const Color(0xFF22C55E);
      case 'intermediate':
        return const Color(0xFFFF9800);
      case 'advanced':
        return const Color(0xFFFF4757);
      default:
        return widget.accentColor;
    }
  }
}
