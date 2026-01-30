import 'package:flutter/foundation.dart'; // ← ADD THIS LINE
import 'package:flutter_tts/flutter_tts.dart';

class VoiceAnnouncer {
  static final VoiceAnnouncer _instance = VoiceAnnouncer._internal();
  factory VoiceAnnouncer() => _instance;
  VoiceAnnouncer._internal();

  FlutterTts? _tts;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    _tts = FlutterTts();

    // Force init for web/iOS Safari
    await _tts!.awaitSpeakCompletion(true);
    await _tts!.setLanguage("en-US");
    await _tts!.setSpeechRate(0.52);
    await _tts!.setVolume(1.0);
    await _tts!.setPitch(1.0);

    // Log available voices
    final voices = await _tts!.getVoices;
    debugPrint("TTS initialized - ${voices.length} voices available");

    _isInitialized = true;
  }

  Future<bool> speak(String text) async {
    await init();

    if (_tts == null) {
      debugPrint("TTS not initialized");
      return false;
    }

    debugPrint("TTS speaking: '$text'");
    final result = await _tts!.speak(text);

    if (result == 1) {
      debugPrint("TTS speak queued successfully");
      return true;
    } else {
      debugPrint("TTS speak failed");
      return false;
    }
  }

  Future<void> announceKm(int km) async {
    await speak("You have completed $km kilometers. Keep going!");
  }

  Future<void> announceSummary(double avgPaceMinKm, int totalSeconds, String comparison) async {
    final paceStr = "${avgPaceMinKm.floor()}:${((avgPaceMinKm - avgPaceMinKm.floor()) * 60).round().toString().padLeft(2, '0')}";
    final timeStr = "${(totalSeconds ~/ 3600).toString().padLeft(2, '0')}:${((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0')}:${(totalSeconds % 60).toString().padLeft(2, '0')}";
    String message = "Run complete! Total time $timeStr. Average pace $paceStr per kilometer. $comparison";
    await speak(message);
  }
}