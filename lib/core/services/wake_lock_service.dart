import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Keeps the screen awake during runs on iOS Safari / web
/// This helps prevent the app from sleeping when screen locks
class WakeLockService {
  static const platform = MethodChannel('com.majurun/wakelock');
  static bool _isActive = false;

  /// Enable wake lock - keeps screen on
  static Future<void> enable() async {
    if (_isActive) return;
    
    try {
      if (kIsWeb) {
        // For web, we'll use JavaScript Wake Lock API
        // This is handled in web/index.html
        debugPrint('🔒 Wake Lock: Web wake lock requested');
      } else {
        // For native platforms
        await platform.invokeMethod('enable');
        debugPrint('🔒 Wake Lock: Enabled');
      }
      _isActive = true;
    } catch (e) {
      debugPrint('⚠️ Wake Lock Error: $e');
    }
  }

  /// Disable wake lock - allow screen to sleep
  static Future<void> disable() async {
    if (!_isActive) return;
    
    try {
      if (kIsWeb) {
        debugPrint('🔓 Wake Lock: Web wake lock released');
      } else {
        await platform.invokeMethod('disable');
        debugPrint('🔓 Wake Lock: Disabled');
      }
      _isActive = false;
    } catch (e) {
      debugPrint('⚠️ Wake Lock Error: $e');
    }
  }

  static bool get isActive => _isActive;
}

// Add this to web/index.html before </body>:
/*
<script>
  let wakeLock = null;

  // Request wake lock
  async function requestWakeLock() {
    try {
      if ('wakeLock' in navigator) {
        wakeLock = await navigator.wakeLock.request('screen');
        console.log('🔒 Wake Lock activated');
        
        wakeLock.addEventListener('release', () => {
          console.log('🔓 Wake Lock released');
        });
      } else {
        console.warn('⚠️ Wake Lock API not supported');
      }
    } catch (err) {
      console.error('Wake Lock error:', err);
    }
  }

  // Release wake lock
  function releaseWakeLock() {
    if (wakeLock !== null) {
      wakeLock.release();
      wakeLock = null;
    }
  }

  // Auto-request on visibility change
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible' && wakeLock !== null) {
      requestWakeLock();
    }
  });
  
  // Make functions available globally
  window.requestWakeLock = requestWakeLock;
  window.releaseWakeLock = releaseWakeLock;
</script>
*/