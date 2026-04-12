import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/foundation.dart';

class WakeLockService {
  static bool _isActive = false;

  static Future<void> enable() async {
    try {
      await WakelockPlus.enable();
      _isActive = true;
    } catch (e) {
      debugPrint('⚠️ Wake Lock Error: $e');
    }
  }

  static Future<void> disable() async {
    if (!_isActive) return;
    try {
      await WakelockPlus.disable();
      _isActive = false;
    } catch (e) {
      debugPrint('⚠️ Wake Lock Error: $e');
    }
  }

  static bool get isActive => _isActive;
}
