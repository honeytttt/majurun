import 'package:flutter_test/flutter_test.dart';
import 'package:majurun/core/services/voice_settings_service.dart';

void main() {
  group('VoiceSettings', () {
    test('defaults() should have all major toggles enabled', () {
      final settings = VoiceSettings.defaults();
      expect(settings.masterEnabled, isTrue);
      expect(settings.runStartStop, isTrue);
      expect(settings.fullKmUpdates, isTrue);
      expect(settings.coachingVoiceIndex, 0);
    });

    test('silent() should have all toggles disabled except master', () {
      final settings = VoiceSettings.silent();
      expect(settings.masterEnabled, isFalse);
      expect(settings.runStartStop, isFalse);
      expect(settings.fullKmUpdates, isFalse);
    });

    test('toMap and fromMap should be consistent', () {
      final original = VoiceSettings(
        masterEnabled: false,
        voiceName: 'Alex',
        speechRate: 0.5,
        coachingVoiceIndex: 2,
      );
      
      final map = original.toMap();
      final decoded = VoiceSettings.fromMap(map);
      
      expect(decoded.masterEnabled, original.masterEnabled);
      expect(decoded.voiceName, original.voiceName);
      expect(decoded.speechRate, original.speechRate);
      expect(decoded.coachingVoiceIndex, original.coachingVoiceIndex);
    });

    test('copyWith should only update specified fields', () {
      final original = VoiceSettings.defaults();
      final updated = original.copyWith(masterEnabled: false, coachingVoiceIndex: 3);
      
      expect(updated.masterEnabled, isFalse);
      expect(updated.coachingVoiceIndex, 3);
      expect(updated.runStartStop, original.runStartStop); // Unchanged
    });
  });
}
