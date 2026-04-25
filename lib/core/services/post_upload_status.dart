import 'package:flutter/foundation.dart';

/// Tracks the background post-upload state so the UI can show
/// a Strava-style "Posting your run…" / "Run posted ✓" banner.
///
/// Singleton — listen to it anywhere in the widget tree.
class PostUploadStatus extends ChangeNotifier {
  static final PostUploadStatus instance = PostUploadStatus._();
  PostUploadStatus._();

  _UploadState _state = _UploadState.idle;
  String? _errorMessage;

  bool get isIdle     => _state == _UploadState.idle;
  bool get isUploading => _state == _UploadState.uploading;
  bool get isSuccess  => _state == _UploadState.success;
  bool get isFailed   => _state == _UploadState.failed;
  String? get errorMessage => _errorMessage;

  void markUploading() {
    _state = _UploadState.uploading;
    _errorMessage = null;
    notifyListeners();
  }

  void markSuccess() {
    _state = _UploadState.success;
    _errorMessage = null;
    notifyListeners();
    // Auto-reset to idle after 5 s so the banner disappears
    Future.delayed(const Duration(seconds: 5), reset);
  }

  void markFailed(String? message) {
    _state = _UploadState.failed;
    _errorMessage = message;
    notifyListeners();
  }

  void reset() {
    _state = _UploadState.idle;
    _errorMessage = null;
    notifyListeners();
  }
}

enum _UploadState { idle, uploading, success, failed }
