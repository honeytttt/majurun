import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:majurun/core/services/logging_service.dart';

/// Writes WARNING-level and above logs to Firestore → app_logs collection.
/// Visible in the admin panel Log Viewer tab.
///
/// Setup (call once at app startup):
///   RemoteLogger.attach();
///
/// Logs are stored at:
///   app_logs/{auto-id}
///   Fields: level, tag, message, error, userId, platform, timestamp
///
/// Retention: auto-delete logs older than 7 days via a Firestore TTL rule
/// or the admin panel "Clear Old Logs" button.
class RemoteLogger {
  RemoteLogger._();

  static bool _attached = false;
  static const int _maxMessageLength = 800;

  /// Attach to LoggingService — call once after Firebase is initialized.
  static void attach() {
    if (_attached) return;
    _attached = true;

    LoggingService.instance.onLog = (level, tag, message, error, stackTrace) {
      // Only send WARNING and above to Firestore to avoid spam
      if (level.index < LogLevel.warning.index) return;
      _write(level, tag, message, error, stackTrace);
    };

    debugPrint('[RemoteLogger] Attached — WARNING+ logs → Firestore app_logs');
  }

  static void _write(
    LogLevel level,
    String tag,
    String message,
    Object? error,
    StackTrace? stackTrace,
  ) {
    // Fire-and-forget — never await, never block the UI
    Future.microtask(() async {
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        final truncated = message.length > _maxMessageLength
            ? '${message.substring(0, _maxMessageLength)}…'
            : message;

        await FirebaseFirestore.instance.collection('app_logs').add({
          'level':     _levelName(level),
          'levelIndex': level.index,
          'tag':       tag,
          'message':   truncated,
          'error':     error?.toString(),
          'stack':     stackTrace != null
              ? stackTrace.toString().substring(
                  0, stackTrace.toString().length.clamp(0, 500))
              : null,
          'userId':    uid,
          'platform':  defaultTargetPlatform.name, // android / iOS / etc.
          'isRelease': kReleaseMode,
          'timestamp': FieldValue.serverTimestamp(),
          // TTL field — Firestore TTL policy can auto-delete after 7 days
          'expireAt':  Timestamp.fromDate(
              DateTime.now().add(const Duration(days: 7))),
        });
      } catch (_) {
        // Never throw from logger — silent failure
      }
    });
  }

  static String _levelName(LogLevel level) {
    switch (level) {
      case LogLevel.verbose: return 'VERBOSE';
      case LogLevel.debug:   return 'DEBUG';
      case LogLevel.info:    return 'INFO';
      case LogLevel.warning: return 'WARNING';
      case LogLevel.error:   return 'ERROR';
    }
  }

  /// Manually log a message at ERROR level (for use outside LoggingService).
  static void logError(String tag, String message, {Object? error, StackTrace? stack}) {
    _write(LogLevel.error, tag, message, error, stack);
  }
}
