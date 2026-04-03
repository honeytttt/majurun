import 'dart:math';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:majurun/core/services/voice_settings_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 100 varied encouragement phrases so users never hear the same one twice
// in a row. Randomly selected each time.
// ─────────────────────────────────────────────────────────────────────────────
const List<String> _kEncouragements = [
  "You're doing amazing! Keep it up!",
  "Every step counts — you've got this!",
  "Your legs are stronger than you think!",
  "Champions are made on days like this!",
  "Push through — the finish line is closer than you know!",
  "You showed up, and that's already half the battle!",
  "Keep moving forward — one foot at a time!",
  "Breathe deep, stay steady, keep going!",
  "You are built for this moment!",
  "Pain is temporary, glory is forever — keep running!",
  "Your body can do this — trust your training!",
  "Strong mind, strong legs, strong finish!",
  "You've already beaten everyone who stayed on the couch!",
  "This is YOUR run — own every meter!",
  "Nothing stops you today — nothing!",
  "Feel the rhythm of your run and go!",
  "You're getting faster, stronger, better with every step!",
  "Dig deep — there's more in the tank!",
  "Progress, not perfection — keep running!",
  "You're writing your own story with every kilometer!",
  "Incredible pace — don't slow down now!",
  "You were born to run — show the world!",
  "Every kilometer is a victory — celebrate this one!",
  "The road is yours — take it!",
  "Sweat, smile, repeat — you've got this!",
  "You're proving something to yourself right now!",
  "Endurance is built one step at a time — keep building!",
  "Running is a gift — enjoy every stride!",
  "Your future self will thank you for not stopping!",
  "Feel those feet hitting the ground — that's power!",
  "You are unstoppable when you choose to be!",
  "Consistent effort creates extraordinary results — keep going!",
  "The hardest part is already behind you!",
  "Believe in the distance you've already covered!",
  "You're tougher than any hill, any wind, any doubt!",
  "You are 100 percent capable of finishing this!",
  "Keep your eyes forward and your spirit high!",
  "Every runner hits a wall — and every runner breaks through!",
  "Lean in, breathe out, and keep moving!",
  "You chose to run today — now see it through!",
  "Strong legs carry strong hearts — yours is the strongest!",
  "The miles are melting — you're almost there!",
  "Run with purpose, run with heart, run with everything you have!",
  "Winners don't quit and quitters don't win — keep running!",
  "You make this look easy because you've trained hard!",
  "Pace yourself and own this run!",
  "There's a better version of you at the finish — go find them!",
  "Head up, chest out, eyes forward — let's go!",
  "Your determination is your superpower today!",
  "You came this far — don't stop now!",
  "Running is 90 percent mental — your mind is winning!",
  "Every drop of sweat is a step toward greatness!",
  "Stay strong, stay consistent, stay running!",
  "You are a machine right now — don't stop the engine!",
  "Listen to your body and tell it to keep going!",
  "This pace, this distance, this day — all yours!",
  "You're lapping everyone who didn't start!",
  "Resilience is your middle name — prove it!",
  "Go for it — you'll regret stopping, not pushing!",
  "Excellence is a habit you're building right now!",
  "Feel the strength in your stride — you are powerful!",
  "Hard work is working — keep at it!",
  "Your journey today inspires more people than you know!",
  "Sweat is fat crying — make it cry harder!",
  "You are a runner, and runners finish what they start!",
  "Look how far you've come — now go even further!",
  "Stay the course — greatness is straight ahead!",
  "You're not just running — you're becoming someone stronger!",
  "Every second of effort is investing in a healthier you!",
  "Let the rhythm carry you — flow into this run!",
  "You've broken limits before — break another one today!",
  "Keep your cadence, keep your calm, keep going!",
  "You're doing something most people only wish they did!",
  "One step at a time — just one more step!",
  "Your grit is showing — and it looks incredible!",
  "This run belongs to you — claim it!",
  "The best view comes after the hardest climb — keep going!",
  "You are more resilient than you realize!",
  "Stay hungry, stay humble, stay running!",
  "Your consistency today is your confidence tomorrow!",
  "You're writing a comeback story with every stride!",
  "Don't count the kilometers — make the kilometers count!",
  "Keep the fire burning — you're almost at the breakthrough!",
  "You're a warrior out here — warriors don't stop!",
  "Breathe, believe, and keep your feet moving!",
  "Pain is just weakness leaving the body — push through!",
  "You chose the harder path today — that's why you'll win!",
  "Light feet, strong heart, clear mind — go!",
  "Your effort today is the gift you give your future self!",
  "Nobody remembers the easy runs — make this one legendary!",
  "You're fueled by determination — and you have plenty left!",
  "Run tall, run strong, run proud!",
  "There are no shortcuts to any place worth going — run on!",
  "You're in the zone — stay there!",
  "Champions train when nobody's watching — you're doing it!",
  "Every meter you've run today is a personal record of effort!",
  "Stay loose, stay focused, stay moving!",
  "The only run you regret is the one you didn't finish!",
  "You are the athlete you always wanted to be — right now!",
  "Go hard — rest is coming, but not yet!",
  "This is the run that makes the next one easier — push on!",
];

// ─────────────────────────────────────────────────────────────────────────────
// Approaching-milestone phrases.
// Key  = distance in km that triggers the announcement.
// Value = what to say.
// ─────────────────────────────────────────────────────────────────────────────
final Map<double, String> _kApproachingPhrases = {
  4.0:  "You're just 1 kilometer away from 5K! Keep pushing!",
  8.0:  "Only 2 kilometers to 10K! You can do this!",
  9.0:  "Just 1 kilometer left to reach 10K! Give it everything!",
  19.0: "2 kilometers to the half marathon! You're so close!",
  20.0: "Just 1 kilometer to the half marathon! Dig deep!",
  40.0: "Only 2 kilometers to the full marathon! This is it!",
  41.0: "1 kilometer to the full marathon! You are a legend!",
};

class VoiceController extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();
  final VoiceSettingsService _settingsService = VoiceSettingsService();
  bool _isVoiceEnabled = true;
  bool _isInitialized = false;
  final _random = Random();

  // Tracks which approaching-milestone announcements have already fired
  // so they don't repeat on every GPS tick.
  final Set<double> _announcedApproaching = {};

  // Index of last encouragement phrase used (avoid immediate repeat)
  int _lastEncouragementIndex = -1;

  VoiceController() {
    _initTts();
    _settingsService.loadSettings();
  }

  VoiceSettings get _settings => _settingsService.settings;
  bool get isVoiceEnabled => _isVoiceEnabled;
  bool get isInitialized => _isInitialized;

  Future<void> _initTts() async {
    try {
      final voiceName = _settings.voiceName;

      if (kIsWeb) {
        await _tts.setLanguage("en-US");
        await _tts.setSpeechRate(0.42);
        await _tts.setPitch(1.0);
        await _tts.setVolume(1.0);
        await _tts.speak(" ");
        await Future.delayed(const Duration(milliseconds: 100));
        await _tts.stop();
        debugPrint("✅ Voice initialized for WEB (warmed up)");
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        // Critical: tell flutter_tts to use the shared AVAudioSession and configure
        // it with .mixWithOthers so Spotify / Udemy / podcasts keep playing when
        // the run coach voice speaks. Without this, flutter_tts re-activates the
        // session with .playback (no mixWithOthers) which interrupts background audio.
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.allowAirPlay,
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          ],
          IosTextToSpeechAudioMode.defaultMode,
        );
        final name = voiceName.isNotEmpty ? voiceName : 'Samantha';
        await _tts.setVoice({"name": name, "locale": "en-US"});
        await _tts.setLanguage("en-US");
        await _tts.setSpeechRate(_settings.speechRate);
        await _tts.setPitch(1.0);
        await _tts.setVolume(1.0);
        debugPrint("✅ Voice initialized for iOS ($name) with mixWithOthers");
      } else {
        await _tts.setLanguage("en-US");
        await _tts.setSpeechRate(_settings.speechRate);
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

  Future<void> ensureInitialized() async {
    if (!_isInitialized || kIsWeb) {
      debugPrint("🔄 Re-initializing TTS...");
      await _initTts();
    }
  }

  /// Re-initialize TTS when user changes voice settings (name, rate, etc.)
  Future<void> reloadVoice() async {
    _isInitialized = false;
    await _initTts();
  }

  void toggleVoice() {
    _isVoiceEnabled = !_isVoiceEnabled;
    notifyListeners();
  }

  /// Reset approaching-milestone tracker at the start of each run.
  void resetApproachingMilestones() {
    _announcedApproaching.clear();
  }

  Future<void> _speak(String text) async {
    if (!_isVoiceEnabled || !_settings.masterEnabled) return;
    try {
      if (!_isInitialized) await _initTts();
      await _tts.speak(text);
      debugPrint("🔊 Speaking: $text");
    } catch (e) {
      debugPrint("⚠️ Error speaking: $e");
      await _initTts();
    }
  }

  String _pickEncouragement() {
    int idx;
    do {
      idx = _random.nextInt(_kEncouragements.length);
    } while (idx == _lastEncouragementIndex && _kEncouragements.length > 1);
    _lastEncouragementIndex = idx;
    return _kEncouragements[idx];
  }

  /// Check whether we're approaching a major milestone and announce once.
  /// Call this on every GPS distance update (same place you call speakKmMilestone).
  Future<void> checkApproachingMilestone(double distanceKm) async {
    if (!_isVoiceEnabled || !_settings.masterEnabled || !_settings.encouragement) return;
    for (final entry in _kApproachingPhrases.entries) {
      final threshold = entry.key;
      // Fire when distance crosses the threshold (within a small window to avoid
      // missing due to GPS granularity), and only once per run.
      if (distanceKm >= threshold &&
          distanceKm < threshold + 0.15 &&
          !_announcedApproaching.contains(threshold)) {
        _announcedApproaching.add(threshold);
        await _speak(entry.value);
        return; // Only one approaching announcement at a time
      }
    }
  }

  Future<void> speakTraining(String text) async {
    await _speak(text);
  }

  Future<void> _playMilestoneSound(int km) async {
    if (!_settings.hapticFeedback) return;
    if (km != 5 && km != 10 && km != 21 && km != 42) return;
    try {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint("⚠️ Error playing milestone haptic: $e");
    }
  }

  Future<void> _playTingSound() async {
    if (!_settings.hapticFeedback) return;
    try {
      await HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 50));
      await HapticFeedback.selectionClick();
    } catch (e) {
      debugPrint("⚠️ Error playing ting sound: $e");
    }
  }

  Future<void> speakHalfKmMilestone({
    required double distanceKm,
    required String currentPace,
  }) async {
    if (!_isVoiceEnabled || !_settings.masterEnabled || !_settings.halfKmUpdates) return;

    await _playTingSound();

    final paceParts = currentPace.split(':');
    final paceMin = int.tryParse(paceParts[0]) ?? 0;
    final paceSec = int.tryParse(paceParts.length > 1 ? paceParts[1] : '0') ?? 0;

    final announcement = StringBuffer();
    final distanceStr = distanceKm.toStringAsFixed(1);
    announcement.write("$distanceStr kilometers. ");
    announcement.write("Pace: $paceMin ");
    announcement.write(paceMin == 1 ? "minute " : "minutes ");
    if (paceSec > 0) {
      announcement.write("$paceSec. ");
    } else {
      announcement.write(". ");
    }

    await _speak(announcement.toString());
  }

  Future<void> speakKmMilestone({
    required int km,
    required String totalTime,
    required String lastKmPace,
    required String averagePace,
    String? comparison,
  }) async {
    if (!_isVoiceEnabled || !_settings.masterEnabled || !_settings.fullKmUpdates) return;

    if (_settings.majorMilestones) await _playMilestoneSound(km);

    final timeParts = totalTime.split(':');
    int hours = 0, minutes = 0, seconds = 0;
    if (timeParts.length == 3) {
      hours = int.tryParse(timeParts[0]) ?? 0;
      minutes = int.tryParse(timeParts[1]) ?? 0;
      seconds = int.tryParse(timeParts[2]) ?? 0;
    } else if (timeParts.length == 2) {
      minutes = int.tryParse(timeParts[0]) ?? 0;
      seconds = int.tryParse(timeParts[1]) ?? 0;
    }

    final avgPaceParts = averagePace.split(':');
    final avgPaceMin = int.tryParse(avgPaceParts[0]) ?? 0;
    final avgPaceSec = int.tryParse(avgPaceParts.length > 1 ? avgPaceParts[1] : '0') ?? 0;

    final announcement = StringBuffer();

    if (_settings.majorMilestones) {
      if (km == 5) announcement.write("Congratulations! ");
      else if (km == 10) announcement.write("Incredible achievement! ");
      else if (km == 21) announcement.write("Half marathon complete! You're amazing! ");
      else if (km == 42) announcement.write("Full marathon! This is legendary! ");
    }

    announcement.write("You've completed $km ");
    announcement.write(km == 1 ? "kilometer. " : "kilometers. ");

    if (_settings.totalTime) {
      announcement.write("Your total time is ");
      if (hours > 0) {
        announcement.write("$hours ");
        announcement.write(hours == 1 ? "hour " : "hours ");
      }
      if (minutes > 0 || hours == 0) {
        if (hours > 0) announcement.write("and ");
        announcement.write("$minutes ");
        announcement.write(minutes == 1 ? "minute" : "minutes");
      }
      if (seconds > 0 && hours == 0) {
        announcement.write(" and $seconds ");
        announcement.write(seconds == 1 ? "second" : "seconds");
      }
      announcement.write(". ");
    }

    if (_settings.lastKmPace) {
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
    }

    if (_settings.averagePace) {
      announcement.write("Your average pace is $avgPaceMin ");
      announcement.write(avgPaceMin == 1 ? "minute " : "minutes ");
      if (avgPaceSec > 0) {
        announcement.write("and $avgPaceSec ");
        announcement.write(avgPaceSec == 1 ? "second " : "seconds ");
      }
      announcement.write("per kilometer. ");
    }

    if (comparison != null && comparison.isNotEmpty) {
      announcement.write(comparison);
      announcement.write(". ");
    }

    if (_settings.encouragement) {
      if (km == 42) {
        announcement.write("You've conquered a full marathon! Absolute champion!");
      } else if (km == 21) {
        announcement.write("Half marathon done! Incredible effort!");
      } else if (km == 10) {
        announcement.write("You've hit 10K! You're unstoppable!");
      } else if (km == 5) {
        announcement.write("5K complete! Amazing work!");
      } else {
        announcement.write(_pickEncouragement());
      }
    }

    await _speak(announcement.toString());
  }

  Future<void> speakRunStarted() async {
    if (!_settings.runStartStop) return;
    await ensureInitialized();
    resetApproachingMilestones();
    await _speak("Run started. Stay safe and enjoy your run!");
  }

  Future<void> speakRunPaused() async {
    if (!_settings.pauseResume) return;
    await _speak("Run paused. Take a breath!");
  }

  Future<void> speakRunResumed() async {
    if (!_settings.pauseResume) return;
    await _speak("Run resumed. Let's go!");
  }

  Future<void> speakRunStopped() async {
    if (!_settings.runStartStop) return;
    await _speak("Great job! Run completed. Check your stats!");
  }

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
