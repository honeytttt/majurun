import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceController extends ChangeNotifier {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isVoiceEnabled = true;

  bool get isVoiceEnabled => _isVoiceEnabled;

  VoiceController() {
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      debugPrint("TTS initialized");
    } catch (e) {
      debugPrint("TTS initialization error: $e");
    }
  }

  void toggleVoice() {
    _isVoiceEnabled = !_isVoiceEnabled;
    notifyListeners();
    debugPrint("Voice ${_isVoiceEnabled ? 'enabled' : 'disabled'}");
  }

  Future<void> _speak(String text) async {
    if (!_isVoiceEnabled) return;
    try {
      debugPrint("🔊 Speaking: $text");
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint("TTS speak error: $e");
    }
  }

  // Basic announcements
  Future<void> speakRunStarted() async {
    await _speak("Run started. Good luck!");
  }

  Future<void> speakRunPaused() async {
    await _speak("Run paused");
  }

  Future<void> speakRunResumed() async {
    await _speak("Run resumed");
  }

  Future<void> speakRunStopped() async {
    await _speak("Run stopped");
  }

  // Enhanced km milestone announcements
  Future<void> speakKmMilestone({
    required int km,
    required String totalTime,
    required String lastKmPace,
    required String averagePace,
    String? comparison,
  }) async {
    if (!_isVoiceEnabled) return;

    // Build the announcement
    String announcement = "";

    // Milestone
    announcement += "$km kilometer completed. ";

    // Total time
    announcement += "Total time: $totalTime. ";

    // Last km pace
    announcement += "Last kilometer pace: $lastKmPace. ";

    // Average pace
    announcement += "Average pace: $averagePace. ";

    // Comparison with previous km (if available)
    if (comparison != null && comparison.isNotEmpty) {
      announcement += comparison;
    }

    debugPrint("🎯 KM Milestone: $announcement");
    await _speak(announcement);
  }

  // Custom announcement
  Future<void> speak(String text) async {
    await _speak(text);
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }
}