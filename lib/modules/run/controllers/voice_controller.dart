import 'package:flutter/material.dart';
import 'package:majurun/modules/run/services/voice_announcer.dart';

class VoiceController extends ChangeNotifier {
  bool _isVoiceEnabled = true;
  bool get isVoiceEnabled => _isVoiceEnabled;

  final VoiceAnnouncer _voice = VoiceAnnouncer();
  bool _isSpeaking = false; // Flag to prevent double/overlapping voice calls

  VoiceController() {
    // Initialize TTS when controller is created
    _voice.init();
  }

  void toggleVoice() {
    _isVoiceEnabled = !_isVoiceEnabled;
    debugPrint("VoiceController: Voice ${_isVoiceEnabled ? 'ENABLED' : 'DISABLED'}");
    notifyListeners();
  }

  Future<void> speakRunStarted() async {
    if (!_isVoiceEnabled) {
      debugPrint("VoiceController: speakRunStarted - Voice disabled, skipping");
      return;
    }
    
    // Add a cooldown period to prevent rapid double calls
    if (_isSpeaking) {
      debugPrint("VoiceController: speakRunStarted - Already speaking, skipping");
      return;
    }
    
    _isSpeaking = true;
    debugPrint("VoiceController: speakRunStarted - Starting announcement");
    try {
      await _voice.runStarted();
      debugPrint("VoiceController: speakRunStarted - Announcement completed");
    } catch (e) {
      debugPrint("VoiceController: speakRunStarted - Error: $e");
    } finally {
      // Add a small delay before allowing another announcement
      await Future.delayed(const Duration(milliseconds: 500));
      _isSpeaking = false;
    }
  }

  Future<void> speakRunPaused() async {
    if (!_isVoiceEnabled) {
      debugPrint("VoiceController: speakRunPaused - Voice disabled, skipping");
      return;
    }
    
    if (_isSpeaking) {
      debugPrint("VoiceController: speakRunPaused - Already speaking, skipping");
      return;
    }
    
    _isSpeaking = true;
    debugPrint("VoiceController: speakRunPaused - Starting announcement");
    try {
      await _voice.runPaused();
      debugPrint("VoiceController: speakRunPaused - Announcement completed");
    } catch (e) {
      debugPrint("VoiceController: speakRunPaused - Error: $e");
    } finally {
      await Future.delayed(const Duration(milliseconds: 500));
      _isSpeaking = false;
    }
  }

  Future<void> speakRunResumed() async {
    if (!_isVoiceEnabled) {
      debugPrint("VoiceController: speakRunResumed - Voice disabled, skipping");
      return;
    }
    
    if (_isSpeaking) {
      debugPrint("VoiceController: speakRunResumed - Already speaking, skipping");
      return;
    }
    
    _isSpeaking = true;
    debugPrint("VoiceController: speakRunResumed - Starting announcement");
    try {
      await _voice.runResumed();
      debugPrint("VoiceController: speakRunResumed - Announcement completed");
    } catch (e) {
      debugPrint("VoiceController: speakRunResumed - Error: $e");
    } finally {
      await Future.delayed(const Duration(milliseconds: 500));
      _isSpeaking = false;
    }
  }

  Future<void> speakRunStopped() async {
    if (!_isVoiceEnabled) {
      debugPrint("VoiceController: speakRunStopped - Voice disabled, skipping");
      return;
    }
    
    if (_isSpeaking) {
      debugPrint("VoiceController: speakRunStopped - Already speaking, skipping");
      return;
    }
    
    _isSpeaking = true;
    debugPrint("VoiceController: speakRunStopped - Starting announcement");
    try {
      await _voice.runStopped();
      debugPrint("VoiceController: speakRunStopped - Announcement completed");
    } catch (e) {
      debugPrint("VoiceController: speakRunStopped - Error: $e");
    } finally {
      await Future.delayed(const Duration(milliseconds: 500));
      _isSpeaking = false;
    }
  }

  Future<void> announceKm(int km) async {
    if (!_isVoiceEnabled || _isSpeaking) return;
    _isSpeaking = true;
    try {
      await _voice.announceKm(km);
    } catch (e) {
      debugPrint("VoiceController: announceKm - Error: $e");
    } finally {
      await Future.delayed(const Duration(milliseconds: 500));
      _isSpeaking = false;
    }
  }

  Future<void> speak(String text) async {
    if (!_isVoiceEnabled || _isSpeaking) return;
    _isSpeaking = true;
    try {
      await _voice.speak(text);
    } catch (e) {
      debugPrint("VoiceController: speak - Error: $e");
    } finally {
      await Future.delayed(const Duration(milliseconds: 500));
      _isSpeaking = false;
    }
  }
}