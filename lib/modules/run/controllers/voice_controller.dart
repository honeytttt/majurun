import 'package:flutter/material.dart';
import 'package:majurun/modules/run/services/voice_announcer.dart'; // the TTS wrapper

class VoiceController extends ChangeNotifier {
  bool _isVoiceEnabled = true;
  bool get isVoiceEnabled => _isVoiceEnabled;

  final VoiceAnnouncer _voice = VoiceAnnouncer();

  bool _isSpeaking = false;

  void toggleVoice() {
    _isVoiceEnabled = !_isVoiceEnabled;
    notifyListeners();
  }

  Future<void> speakRunStarted() async {
    if (!_isVoiceEnabled || _isSpeaking) return;
    _isSpeaking = true;
    await _voice.runStarted();
    _isSpeaking = false;
  }

  Future<void> speakRunPaused() async {
    if (!_isVoiceEnabled || _isSpeaking) return;
    _isSpeaking = true;
    await _voice.runPaused();
    _isSpeaking = false;
  }

  Future<void> speakRunResumed() async {
    if (!_isVoiceEnabled || _isSpeaking) return;
    _isSpeaking = true;
    await _voice.runResumed();
    _isSpeaking = false;
  }

  Future<void> speakRunStopped() async {
    if (!_isVoiceEnabled || _isSpeaking) return;
    _isSpeaking = true;
    await _voice.runStopped();
    _isSpeaking = false;
  }

  Future<void> announceKm(int km) async {
    if (!_isVoiceEnabled || _isSpeaking) return;
    _isSpeaking = true;
    await _voice.announceKm(km);
    _isSpeaking = false;
  }

  Future<void> speak(String text) async {
    if (!_isVoiceEnabled || _isSpeaking) return;
    _isSpeaking = true;
    await _voice.speak(text);
    _isSpeaking = false;
  }

  Future<void> stopAllSpeech() async {
    await _voice.stopAllSpeech();
    _isSpeaking = false;
  }
}