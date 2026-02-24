import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Voice coach settings - controls which voice announcements are enabled
class VoiceSettings {
  final bool masterEnabled;        // Master toggle for all voice
  final bool runStartStop;         // "Run started" / "Run completed"
  final bool pauseResume;          // "Run paused" / "Run resumed"
  final bool halfKmUpdates;        // 0.5km, 1.5km, 2.5km updates
  final bool fullKmUpdates;        // 1km, 2km, 3km milestone announcements
  final bool lastKmPace;           // "Your last kilometer pace was..."
  final bool averagePace;          // "Your average pace is..."
  final bool totalTime;            // "Your total time is..."
  final bool encouragement;        // "Keep going strong!" etc.
  final bool majorMilestones;      // 5km, 10km, half/full marathon celebrations
  final bool hapticFeedback;       // Vibration for milestones

  const VoiceSettings({
    this.masterEnabled = true,
    this.runStartStop = true,
    this.pauseResume = true,
    this.halfKmUpdates = true,
    this.fullKmUpdates = true,
    this.lastKmPace = true,
    this.averagePace = true,
    this.totalTime = true,
    this.encouragement = true,
    this.majorMilestones = true,
    this.hapticFeedback = true,
  });

  /// All enabled by default
  factory VoiceSettings.defaults() => const VoiceSettings();

  /// All disabled except master
  factory VoiceSettings.silent() => const VoiceSettings(
    masterEnabled: false,
    runStartStop: false,
    pauseResume: false,
    halfKmUpdates: false,
    fullKmUpdates: false,
    lastKmPace: false,
    averagePace: false,
    totalTime: false,
    encouragement: false,
    majorMilestones: false,
    hapticFeedback: false,
  );

  Map<String, dynamic> toMap() => {
    'masterEnabled': masterEnabled,
    'runStartStop': runStartStop,
    'pauseResume': pauseResume,
    'halfKmUpdates': halfKmUpdates,
    'fullKmUpdates': fullKmUpdates,
    'lastKmPace': lastKmPace,
    'averagePace': averagePace,
    'totalTime': totalTime,
    'encouragement': encouragement,
    'majorMilestones': majorMilestones,
    'hapticFeedback': hapticFeedback,
  };

  factory VoiceSettings.fromMap(Map<String, dynamic> map) => VoiceSettings(
    masterEnabled: map['masterEnabled'] ?? true,
    runStartStop: map['runStartStop'] ?? true,
    pauseResume: map['pauseResume'] ?? true,
    halfKmUpdates: map['halfKmUpdates'] ?? true,
    fullKmUpdates: map['fullKmUpdates'] ?? true,
    lastKmPace: map['lastKmPace'] ?? true,
    averagePace: map['averagePace'] ?? true,
    totalTime: map['totalTime'] ?? true,
    encouragement: map['encouragement'] ?? true,
    majorMilestones: map['majorMilestones'] ?? true,
    hapticFeedback: map['hapticFeedback'] ?? true,
  );

  VoiceSettings copyWith({
    bool? masterEnabled,
    bool? runStartStop,
    bool? pauseResume,
    bool? halfKmUpdates,
    bool? fullKmUpdates,
    bool? lastKmPace,
    bool? averagePace,
    bool? totalTime,
    bool? encouragement,
    bool? majorMilestones,
    bool? hapticFeedback,
  }) => VoiceSettings(
    masterEnabled: masterEnabled ?? this.masterEnabled,
    runStartStop: runStartStop ?? this.runStartStop,
    pauseResume: pauseResume ?? this.pauseResume,
    halfKmUpdates: halfKmUpdates ?? this.halfKmUpdates,
    fullKmUpdates: fullKmUpdates ?? this.fullKmUpdates,
    lastKmPace: lastKmPace ?? this.lastKmPace,
    averagePace: averagePace ?? this.averagePace,
    totalTime: totalTime ?? this.totalTime,
    encouragement: encouragement ?? this.encouragement,
    majorMilestones: majorMilestones ?? this.majorMilestones,
    hapticFeedback: hapticFeedback ?? this.hapticFeedback,
  );
}

/// Service to manage voice settings persistence
class VoiceSettingsService extends ChangeNotifier {
  static final VoiceSettingsService _instance = VoiceSettingsService._internal();
  factory VoiceSettingsService() => _instance;
  VoiceSettingsService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  VoiceSettings _settings = VoiceSettings.defaults();
  bool _isLoaded = false;

  VoiceSettings get settings => _settings;
  bool get isLoaded => _isLoaded;

  /// Load settings from Firestore
  Future<void> loadSettings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('voice')
          .get();

      if (doc.exists && doc.data() != null) {
        _settings = VoiceSettings.fromMap(doc.data()!);
      } else {
        _settings = VoiceSettings.defaults();
      }
      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading voice settings: $e');
      _settings = VoiceSettings.defaults();
      _isLoaded = true;
    }
  }

  /// Save settings to Firestore
  Future<void> saveSettings(VoiceSettings newSettings) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('voice')
          .set(newSettings.toMap());

      _settings = newSettings;
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving voice settings: $e');
      rethrow;
    }
  }

  /// Update a single setting
  Future<void> updateSetting(String key, bool value) async {
    final Map<String, dynamic> currentMap = _settings.toMap();
    currentMap[key] = value;
    await saveSettings(VoiceSettings.fromMap(currentMap));
  }

  /// Reset to defaults
  Future<void> resetToDefaults() async {
    await saveSettings(VoiceSettings.defaults());
  }
}
