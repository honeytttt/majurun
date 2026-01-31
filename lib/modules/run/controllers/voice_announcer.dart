import 'package:flutter_tts/flutter_tts.dart';

class VoiceAnnouncer {
  FlutterTts? _tts;

  VoiceAnnouncer() {
    _initTts();
  }

  Future<void> _initTts() async {
    _tts = FlutterTts();
    await _tts!.setLanguage("en-US");
    await _tts!.setSpeechRate(0.5);
    await _tts!.setVolume(1.0);
    await _tts!.setPitch(1.0);
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
    if (_tts == null) await _initTts();
    await _tts!.speak(text);
  }

  Future<void> stopAllSpeech() async {
    if (_tts != null) {
      await _tts!.stop();
    }
  }
}