import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class VoiceController extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();
  bool _isVoiceEnabled = true;
  bool _isInitialized = false;

  VoiceController() {
    _initTts();
  }

  bool get isVoiceEnabled => _isVoiceEnabled;
  bool get isInitialized => _isInitialized;

  Future<void> _initTts() async {
    try {
      // ✅ FIX: iOS Safari voice issue - initialize early and test
      if (kIsWeb) {
        // Web-specific configuration
        await _tts.setLanguage("en-US");
        await _tts.setSpeechRate(0.5);
        await _tts.setPitch(1.0);
        await _tts.setVolume(1.0);
        
        // ✅ CRITICAL: Warm up TTS on web to avoid first-call silence
        // This "primes" the speech synthesizer
        await _tts.speak(" "); // Speak silent space
        await Future.delayed(const Duration(milliseconds: 100));
        await _tts.stop();
        
        debugPrint("✅ Voice initialized for WEB (warmed up)");
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        // Native iOS with premium voice
        await _tts.setVoice({"name": "Samantha", "locale": "en-US"});
        await _tts.setLanguage("en-US");
        await _tts.setSpeechRate(0.5);
        await _tts.setPitch(1.1);
        await _tts.setVolume(1.0);
        
        debugPrint("✅ Voice initialized for iOS (Samantha)");
      } else {
        // Android and other platforms
        await _tts.setLanguage("en-US");
        await _tts.setSpeechRate(0.5);
        await _tts.setPitch(1.0);
        await _tts.setVolume(1.0);
        
        debugPrint("✅ Voice initialized (default)");
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint("⚠️ Error initializing voice: $e");
      _isInitialized = false;
    }
  }

  /// ✅ FIX: Re-initialize TTS if needed (call this when run starts on web)
  Future<void> ensureInitialized() async {
    if (!_isInitialized || kIsWeb) {
      debugPrint("🔄 Re-initializing TTS...");
      await _initTts();
    }
  }

  void toggleVoice() {
    _isVoiceEnabled = !_isVoiceEnabled;
    notifyListeners();
  }

  Future<void> _speak(String text) async {
    if (!_isVoiceEnabled) return;
    
    try {
      // ✅ Ensure initialized before speaking
      if (!_isInitialized) {
        await _initTts();
      }
      
      await _tts.speak(text);
      debugPrint("🔊 Speaking: $text");
    } catch (e) {
      debugPrint("⚠️ Error speaking: $e");
      // Try to recover
      await _initTts();
    }
  }

  /// Public method for training announcements
  Future<void> speakTraining(String text) async {
    await _speak(text);
  }

  /// Play celebration sound for major milestones (5km, 10km, 21km, 42km)
  Future<void> _playMilestoneSound(int km) async {
    // Only play for 5km, 10km, half marathon, full marathon
    if (km != 5 && km != 10 && km != 21 && km != 42) return;

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

  /// Play subtle "ting" sound for half-kilometer milestones (0.5, 1.5, 2.5, etc.)
  Future<void> _playTingSound() async {
    try {
      // Light haptic for subtle notification
      await HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 50));
      await HapticFeedback.selectionClick();
      debugPrint("🔔 Ting sound played for half-km milestone!");
    } catch (e) {
      debugPrint("⚠️ Error playing ting sound: $e");
    }
  }

  /// NEW: Announcement for half-kilometer milestones (0.5km, 1.5km, 2.5km, etc.)
  Future<void> speakHalfKmMilestone({
    required double distanceKm,
    required String currentPace,
  }) async {
    if (!_isVoiceEnabled) return;

    // Play subtle ting sound
    await _playTingSound();

    // Parse current pace (format: "5:30" = 5 minutes 30 seconds per km)
    final paceParts = currentPace.split(':');
    final paceMin = int.tryParse(paceParts[0]) ?? 0;
    final paceSec = int.tryParse(paceParts.length > 1 ? paceParts[1] : '0') ?? 0;

    // Build short, concise announcement
    final announcement = StringBuffer();

    // Distance announcement
    final distanceStr = distanceKm.toStringAsFixed(1); // e.g., "0.5", "1.5", "2.5"
    announcement.write("$distanceStr kilometers. ");

    // Current pace
    announcement.write("Pace: $paceMin ");
    announcement.write(paceMin == 1 ? "minute " : "minutes ");
    if (paceSec > 0) {
      announcement.write("$paceSec. ");
    } else {
      announcement.write(". ");
    }

    await _speak(announcement.toString());
  }

  /// Full kilometer milestone announcement
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

    // Build complete announcement
    final announcement = StringBuffer();

    // Special celebration for major milestones
    if (km == 5) {
      announcement.write("Congratulations! ");
    } else if (km == 10) {
      announcement.write("Incredible achievement! ");
    } else if (km == 21) {
      announcement.write("Half marathon complete! You're amazing! ");
    } else if (km == 42) {
      announcement.write("Full marathon! This is legendary! ");
    }

    // Main milestone
    announcement.write("You've completed $km ");
    announcement.write(km == 1 ? "kilometer. " : "kilometers. ");

    // Time
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

    // Average pace
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

    // Encouragement
    if (km == 42) {
      announcement.write("You've conquered a full marathon! Absolute champion!");
    } else if (km == 21) {
      announcement.write("Half marathon done! Incredible effort!");
    } else if (km == 10) {
      announcement.write("You've hit 10K! You're unstoppable!");
    } else if (km == 5) {
      announcement.write("5K complete! Amazing work!");
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
    // ✅ Ensure TTS is ready (critical for web)
    await ensureInitialized();
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

  /// Test voice to let users hear it
  Future<void> testVoice() async {
    await ensureInitialized();
    await _speak("Hi! I'm your running coach. Let's get moving!");
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}