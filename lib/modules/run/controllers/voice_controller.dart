import 'package:flutter/material.dart';
import 'package:majurun/modules/run/services/voice_announcer.dart';

class VoiceController extends ChangeNotifier {
  bool _isVoiceEnabled = true;
  bool get isVoiceEnabled => _isVoiceEnabled;

  final VoiceAnnouncer _voice = VoiceAnnouncer();

  void toggleVoice() {
    _isVoiceEnabled = !_isVoiceEnabled;
    notifyListeners();
  }

  Future<void> speakRunStarted() async {
    if (_isVoiceEnabled) {
      debugPrint("Voice: Run started");
      await _voice.runStarted();
    }
  }

  Future<void> speakRunPaused() async {
    if (_isVoiceEnabled) {
      debugPrint("Voice: Run paused");
      await _voice.runPaused();
    }
  }

  Future<void> speakRunResumed() async {
    if (_isVoiceEnabled) {
      debugPrint("Voice: Run resumed");
      await _voice.runResumed();
    }
  }

  Future<void> speakRunStopped() async {
    if (_isVoiceEnabled) {
      debugPrint("Voice: Run stopped");
      await _voice.runStopped();
    }
  }

  Future<void> announceKm(int km) async {
    if (_isVoiceEnabled) await _voice.announceKm(km);
  }

  Future<void> speak(String text) async {
    if (_isVoiceEnabled) await _voice.speak(text);
  }
}