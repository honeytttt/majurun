import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Conditional import for web
import 'workout_player_stub.dart'
    if (dart.library.html) 'workout_player_web.dart';

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

class _WorkoutPlayerScreenState extends State<WorkoutPlayerScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  String? _htmlContent;

  @override
  void initState() {
    super.initState();

    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
        overlays: [],
      );
    }

    _loadHtml();
  }

  Future<void> _loadHtml() async {
    final paths = [
      'assets/workouts/MajuRun_${widget.workoutType}.html',
      'lib/workouts/MajuRun_${widget.workoutType}.html',
    ];

    for (final path in paths) {
      try {
        final content = await rootBundle.loadString(path);
        debugPrint('WorkoutPlayer: Loaded from $path (${content.length} chars)');
        if (mounted) {
          setState(() {
            _htmlContent = content;
            _isLoading = false;
          });
        }
        return;
      } catch (e) {
        debugPrint('WorkoutPlayer: Not found at $path');
      }
    }

    if (mounted) {
      setState(() {
        _hasError = true;
        _isLoading = false;
        _errorMessage = 'File not found: MajuRun_${widget.workoutType}.html';
      });
    }
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: SystemUiOverlay.values,
      );
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040404),
      body: SafeArea(
        child: Stack(
          children: [
            // HTML Content
            if (!_isLoading && !_hasError && _htmlContent != null)
              _buildContent(),

            // Loading
            if (_isLoading && !_hasError)
              _buildLoading(),

            // Error
            if (_hasError)
              _buildError(),

            // Close button
            Positioned(
              top: 16,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: widget.accentColor.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: Icon(Icons.close, color: widget.accentColor, size: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (kIsWeb) {
      // Use iframe for web
      return createWebWorkoutView(_htmlContent!, widget.workoutType);
    }

    // For mobile - show workout info (WebView can be added for mobile builds)
    return Container(
      color: const Color(0xFF040404),
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center, size: 80, color: widget.accentColor),
            const SizedBox(height: 24),
            Text(
              widget.workoutTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Mobile workout player coming soon!',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      color: const Color(0xFF040404),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: widget.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: widget.accentColor.withValues(alpha: 0.3)),
              ),
              child: Icon(Icons.fitness_center, size: 50, color: widget.accentColor),
            ),
            const SizedBox(height: 24),
            CircularProgressIndicator(color: widget.accentColor, strokeWidth: 3),
            const SizedBox(height: 20),
            Text(
              'Loading ${widget.workoutTitle}...',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      color: const Color(0xFF040404),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: widget.accentColor, size: 64),
              const SizedBox(height: 20),
              const Text(
                'Unable to load workout',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _isLoading = true;
                    _htmlContent = null;
                  });
                  _loadHtml();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.accentColor,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
