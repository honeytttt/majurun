import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceAnnouncer {
  FlutterTts? _tts;
  bool _isInitialized = false;

  VoiceAnnouncer() {
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      debugPrint("🔊 Initializing TTS...");
      _tts = FlutterTts();
      await _tts!.setLanguage("en-US");
      await _tts!.setSpeechRate(0.5);
      await _tts!.setVolume(1.0);
      await _tts!.setPitch(1.0);
      _isInitialized = true;
      debugPrint("🔊 TTS initialized successfully");
    } catch (e) {
      debugPrint("❌ TTS initialization failed: $e");
    }
  }

  Future<void> runStarted() async {
    await speak("Run started.");
  }

  Future<void> runPaused() async {
    await speak("Run paused.");
  }

  Future<void> runResumed() async {
    await speak("Run resumed.");
  }

  Future<void> runStopped() async {
    await speak("Run stopped.");
  }

  Future<void> announceKm(int km) async {
    await speak("$km kilometers completed. Great job!");
  }

  Future<void> speak(String text) async {
    debugPrint("🔊 Speaking: $text");
    if (_tts == null || !_isInitialized) {
      await _initTts();
    }
    try {
      await _tts!.speak(text);
      debugPrint("🔊 Spoke: $text");
    } catch (e) {
      debugPrint("❌ TTS speak error: $e");
    }
  }

  Future<void> stopAllSpeech() async {
    if (_tts != null) {
      await _tts!.stop();
    }
  }
}