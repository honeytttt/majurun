import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class VoiceController extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();
  bool _isVoiceEnabled = true;

  VoiceController() {
    _initTts();
  }

  bool get isVoiceEnabled => _isVoiceEnabled;

  Future<void> _initTts() async {
    try {
      // Configure for iOS with premium voice
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _tts.setVoice({"name": "Samantha", "locale": "en-US"}); // Premium female voice
        // Alternatives: "Nicky" (also female), "Karen" (Australian)
      } else if (kIsWeb) {
        await _tts.setVoice({"name": "Google US English", "locale": "en-US"});
      }

      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.5); // Slower = clearer (0.5 = normal pace)
      await _tts.setPitch(1.1); // Slightly higher pitch for female voice
      await _tts.setVolume(1.0);

      debugPrint("✅ Voice initialized with premium female voice");
    } catch (e) {
      debugPrint("⚠️ Error initializing voice: $e");
    }
  }

  void toggleVoice() {
    _isVoiceEnabled = !_isVoiceEnabled;
    notifyListeners();
  }

  Future<void> _speak(String text) async {
    if (!_isVoiceEnabled) return;
    
    try {
      await _tts.speak(text);
      debugPrint("🔊 Speaking: $text");
    } catch (e) {
      debugPrint("⚠️ Error speaking: $e");
    }
  }

  // NEW: Public method for training announcements
  Future<void> speakTraining(String text) async {
    await _speak(text);
  }

  /// Play celebration sound for major milestones (5km, 10km)
  Future<void> _playMilestoneSound(int km) async {
    // Only play for 5km and 10km milestones
    if (km != 5 && km != 10) return;

    try {
      // Use system haptic feedback as a "celebration" notification
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.lightImpact();
      debugPrint("🎉 Milestone celebration haptic played for ${km}km!");
    } catch (e) {
      debugPrint("⚠️ Error playing milestone haptic: $e");
    }
  }

  // FIXED: Complete announcement with all details including average pace
  Future<void> speakKmMilestone({
    required int km,
    required String totalTime,
    required String lastKmPace,
    required String averagePace,
    String? comparison,
  }) async {
    if (!_isVoiceEnabled) return;

    // Play celebration sound BEFORE announcement for major milestones
    await _playMilestoneSound(km);

    // Parse totalTime (format: "32:15" = 32 minutes 15 seconds)
    final timeParts = totalTime.split(':');
    final minutes = int.tryParse(timeParts[0]) ?? 0;
    final seconds = int.tryParse(timeParts.length > 1 ? timeParts[1] : '0') ?? 0;

    // Parse average pace (format: "5:30" = 5 minutes 30 seconds per km)
    final avgPaceParts = averagePace.split(':');
    final avgPaceMin = int.tryParse(avgPaceParts[0]) ?? 0;
    final avgPaceSec = int.tryParse(avgPaceParts.length > 1 ? avgPaceParts[1] : '0') ?? 0;

    // FIXED: Build complete announcement
    final announcement = StringBuffer();

    // Special celebration for major milestones
    if (km == 5) {
      announcement.write("Congratulations! ");
    } else if (km == 10) {
      announcement.write("Incredible achievement! ");
    }

    // Main milestone
    announcement.write("You've completed $km ");
    announcement.write(km == 1 ? "kilometer. " : "kilometers. ");

    // Time - FIXED: Say "minutes" not "hours"
    announcement.write("Your total time is $minutes ");
    announcement.write(minutes == 1 ? "minute " : "minutes ");
    if (seconds > 0) {
      announcement.write("and $seconds ");
      announcement.write(seconds == 1 ? "second. " : "seconds. ");
    } else {
      announcement.write(". ");
    }

    // Last km pace
    final paceParts = lastKmPace.split(':');
    final paceMin = int.tryParse(paceParts[0]) ?? 0;
    final paceSec = int.tryParse(paceParts.length > 1 ? paceParts[1] : '0') ?? 0;

    announcement.write("Your last kilometer pace was $paceMin ");
    announcement.write(paceMin == 1 ? "minute " : "minutes ");
    if (paceSec > 0) {
      announcement.write("and $paceSec ");
      announcement.write(paceSec == 1 ? "second " : "seconds ");
    }
    announcement.write("per kilometer. ");

    // Average pace (NEW)
    announcement.write("Your average pace is $avgPaceMin ");
    announcement.write(avgPaceMin == 1 ? "minute " : "minutes ");
    if (avgPaceSec > 0) {
      announcement.write("and $avgPaceSec ");
      announcement.write(avgPaceSec == 1 ? "second " : "seconds ");
    }
    announcement.write("per kilometer. ");

    // Comparison if available
    if (comparison != null && comparison.isNotEmpty) {
      announcement.write(comparison);
      announcement.write(". ");
    }

    // Encouragement - enhanced for major milestones
    if (km == 5) {
      announcement.write("You're halfway to 10K! Keep pushing!");
    } else if (km == 10) {
      announcement.write("You've hit 10K! You're unstoppable!");
    } else if (km % 5 == 0) {
      announcement.write("Amazing progress! Keep it up!");
    } else if (km % 3 == 0) {
      announcement.write("You're doing great!");
    } else {
      announcement.write("Keep going strong!");
    }

    await _speak(announcement.toString());
  }

  Future<void> speakRunStarted() async {
    await _speak("Run started. Stay safe and enjoy your run!");
  }

  Future<void> speakRunPaused() async {
    await _speak("Run paused. Take a breath!");
  }

  Future<void> speakRunResumed() async {
    await _speak("Run resumed. Let's go!");
  }

  Future<void> speakRunStopped() async {
    await _speak("Great job! Run completed. Check your stats!");
  }

  // NEW: Test voice to let users hear it
  Future<void> testVoice() async {
    await _speak("Hi! I'm your running coach. Let's get moving!");
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}