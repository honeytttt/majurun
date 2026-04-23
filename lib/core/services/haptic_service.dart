import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Centralized service for haptic feedback to ensure consistency across the app.
class HapticService {
  static final HapticService _instance = HapticService._internal();
  factory HapticService() => _instance;
  HapticService._internal();

  /// Light tap for subtle feedback (e.g., liking a post, toggling a switch)
  Future<void> light() async {
    if (kIsWeb) return;
    await HapticFeedback.lightImpact();
  }

  /// Medium tap for standard actions (e.g., button press, navigation)
  Future<void> medium() async {
    if (kIsWeb) return;
    await HapticFeedback.mediumImpact();
  }

  /// Heavy tap for significant actions (e.g., finishing a run, earning a badge)
  Future<void> heavy() async {
    if (kIsWeb) return;
    await HapticFeedback.heavyImpact();
  }

  /// Success pattern (multiple taps) for positive outcomes
  Future<void> success() async {
    if (kIsWeb) return;
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
  }

  /// Error pattern for failed actions
  Future<void> error() async {
    if (kIsWeb) return;
    await HapticFeedback.vibrate();
  }

  /// Selection feedback (very subtle) for scrolling or picking items
  Future<void> selection() async {
    if (kIsWeb) return;
    await HapticFeedback.selectionClick();
  }
}
