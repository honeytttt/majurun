import 'package:flutter/foundation.dart';

/// Log levels in order of severity
enum LogLevel {
  verbose,
  debug,
  info,
  warning,
  error,
}

/// Centralized logging service for the app.
///
/// Usage:
/// ```dart
/// final log = LoggingService.instance;
/// log.d('Debug message');
/// log.i('Info message');
/// log.w('Warning message');
/// log.e('Error message', error: e, stackTrace: stack);
/// ```
///
/// For module-specific logging:
/// ```dart
/// final log = LoggingService.instance.withTag('RunController');
/// log.d('Starting run tracking');
/// ```
class LoggingService {
  static final LoggingService _instance = LoggingService._internal();
  static LoggingService get instance => _instance;

  LoggingService._internal();

  /// Minimum log level to output (only logs at this level or higher are shown)
  LogLevel _minLevel = kReleaseMode ? LogLevel.warning : LogLevel.debug;

  /// Whether to include timestamps in logs
  bool includeTimestamp = true;

  /// Optional callback for external logging (e.g., Sentry, Crashlytics)
  void Function(LogLevel level, String tag, String message, Object? error, StackTrace? stackTrace)?
      onLog;

  /// Set minimum log level
  void setMinLevel(LogLevel level) {
    _minLevel = level;
  }

  /// Create a tagged logger for a specific module/class
  TaggedLogger withTag(String tag) => TaggedLogger._(this, tag);

  /// Verbose logging (most detailed, typically disabled in debug)
  void v(String message, {String tag = 'App', Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.verbose, tag, message, error, stackTrace);
  }

  /// Debug logging
  void d(String message, {String tag = 'App', Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.debug, tag, message, error, stackTrace);
  }

  /// Info logging
  void i(String message, {String tag = 'App', Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.info, tag, message, error, stackTrace);
  }

  /// Warning logging
  void w(String message, {String tag = 'App', Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.warning, tag, message, error, stackTrace);
  }

  /// Error logging
  void e(String message, {String tag = 'App', Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.error, tag, message, error, stackTrace);
  }

  void _log(LogLevel level, String tag, String message, Object? error, StackTrace? stackTrace) {
    if (level.index < _minLevel.index) return;

    final buffer = StringBuffer();

    // Timestamp
    if (includeTimestamp) {
      final now = DateTime.now();
      buffer.write('${now.hour.toString().padLeft(2, '0')}:');
      buffer.write('${now.minute.toString().padLeft(2, '0')}:');
      buffer.write('${now.second.toString().padLeft(2, '0')}.');
      buffer.write('${now.millisecond.toString().padLeft(3, '0')} ');
    }

    // Level indicator
    buffer.write(_levelPrefix(level));

    // Tag
    buffer.write('[$tag] ');

    // Message
    buffer.write(message);

    // Error
    if (error != null) {
      buffer.write(' | Error: $error');
    }

    // Output
    debugPrint(buffer.toString());

    // Stack trace (separate line for readability)
    if (stackTrace != null && level == LogLevel.error) {
      debugPrint('StackTrace: $stackTrace');
    }

    // External logging callback
    onLog?.call(level, tag, message, error, stackTrace);
  }

  String _levelPrefix(LogLevel level) {
    switch (level) {
      case LogLevel.verbose:
        return '[V] ';
      case LogLevel.debug:
        return '[D] ';
      case LogLevel.info:
        return '[I] ';
      case LogLevel.warning:
        return '[W] ';
      case LogLevel.error:
        return '[E] ';
    }
  }
}

/// Tagged logger that prepends a tag to all log messages
class TaggedLogger {
  final LoggingService _service;
  final String _tag;

  TaggedLogger._(this._service, this._tag);

  void v(String message, {Object? error, StackTrace? stackTrace}) {
    _service.v(message, tag: _tag, error: error, stackTrace: stackTrace);
  }

  void d(String message, {Object? error, StackTrace? stackTrace}) {
    _service.d(message, tag: _tag, error: error, stackTrace: stackTrace);
  }

  void i(String message, {Object? error, StackTrace? stackTrace}) {
    _service.i(message, tag: _tag, error: error, stackTrace: stackTrace);
  }

  void w(String message, {Object? error, StackTrace? stackTrace}) {
    _service.w(message, tag: _tag, error: error, stackTrace: stackTrace);
  }

  void e(String message, {Object? error, StackTrace? stackTrace}) {
    _service.e(message, tag: _tag, error: error, stackTrace: stackTrace);
  }
}

/// Global accessor for convenience
LoggingService get log => LoggingService.instance;
