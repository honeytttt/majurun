import 'dart:async';

/// Broadcasts a "pause all videos" signal so any active PostVideoPlayer
/// can stop when the user switches tabs or navigates away.
///
/// Usage:
///   Pause  → VideoSessionManager.pauseAll()
///   Listen → VideoSessionManager.onPause.listen((_) => _controller.pause())
class VideoSessionManager {
  VideoSessionManager._();

  static final StreamController<void> _controller =
      StreamController<void>.broadcast();

  /// Stream that PostVideoPlayer widgets subscribe to.
  static Stream<void> get onPause => _controller.stream;

  /// Call this whenever the user switches away from the feed tab.
  static void pauseAll() => _controller.add(null);
}
