import 'package:flutter_tts/flutter_tts.dart';

class VoiceAnnouncer {
  static final VoiceAnnouncer _instance = VoiceAnnouncer._internal();
  factory VoiceAnnouncer() => _instance;
  VoiceAnnouncer._internal();

  late FlutterTts _tts;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    _tts = FlutterTts();
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5); // slightly slower for clarity
    await _tts.setVolume(1.0);
    _isInitialized = true;
  }

  Future<void> speak(String text) async {
    await init();
    await _tts.speak(text);
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