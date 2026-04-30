import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:majurun/core/services/crash_reporting_service.dart';

/// Centralized error handling service
class ErrorHandlerService {
  static final ErrorHandlerService _instance = ErrorHandlerService._internal();
  factory ErrorHandlerService() => _instance;
  ErrorHandlerService._internal();

  // Error stream for listening to errors app-wide
  final _errorController = StreamController<AppError>.broadcast();
  Stream<AppError> get errorStream => _errorController.stream;

  /// Log and optionally report an error
  void handleError(
    dynamic error, {
    StackTrace? stackTrace,
    String? context,
    ErrorSeverity severity = ErrorSeverity.medium,
    bool reportToCrashlytics = true,
  }) {
    final appError = AppError(
      error: error,
      stackTrace: stackTrace,
      context: context,
      severity: severity,
      timestamp: DateTime.now(),
    );

    // Always log to console in debug mode
    if (kDebugMode) {
      debugPrint('═══════════════════════════════════════');
      debugPrint('ERROR [${severity.name.toUpperCase()}]: $context');
      debugPrint('Message: $error');
      if (stackTrace != null) {
        debugPrint('Stack trace:\n$stackTrace');
      }
      debugPrint('═══════════════════════════════════════');
    }

    // Broadcast to listeners
    _errorController.add(appError);

    if (reportToCrashlytics && !kDebugMode) {
      CrashReportingService().recordError(
        error,
        stackTrace,
        reason: context,
        fatal: severity == ErrorSeverity.critical,
      );
    }
  }

  /// Show user-friendly error message
  void showErrorSnackBar(BuildContext context, String message, {Duration? duration}) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: duration ?? const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Show success message
  void showSuccessSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF00E676),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show error dialog for critical errors
  Future<void> showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) async {
    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFD32F2F).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.error_outline, color: Color(0xFFD32F2F), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        ),
        actions: [
          if (onAction != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onAction();
              },
              child: Text(
                actionLabel ?? 'Retry',
                style: const TextStyle(color: Color(0xFF00E676)),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ),
    );
  }

  /// Wrap async operations with error handling
  Future<T?> safeAsync<T>(
    Future<T> Function() operation, {
    String? context,
    T? defaultValue,
    void Function(dynamic error)? onError,
  }) async {
    try {
      return await operation();
    } catch (e, st) {
      handleError(e, stackTrace: st, context: context);
      onError?.call(e);
      return defaultValue;
    }
  }

  void dispose() {
    _errorController.close();
  }
}

/// Error severity levels
enum ErrorSeverity {
  low,    // Logging only
  medium, // Show snackbar
  high,   // Show dialog
  critical, // Show dialog + report to crashlytics
}

/// App error model
class AppError {
  final dynamic error;
  final StackTrace? stackTrace;
  final String? context;
  final ErrorSeverity severity;
  final DateTime timestamp;

  AppError({
    required this.error,
    this.stackTrace,
    this.context,
    required this.severity,
    required this.timestamp,
  });

  String get message {
    if (error is Exception) {
      return error.toString().replaceAll('Exception: ', '');
    }
    return error.toString();
  }

  @override
  String toString() => 'AppError[$severity]: $message (context: $context)';
}

/// Extension for easy error handling on Futures
extension FutureErrorHandling<T> on Future<T> {
  Future<T?> handleErrors({
    String? context,
    T? defaultValue,
    void Function(dynamic error)? onError,
  }) async {
    return ErrorHandlerService().safeAsync(
      () => this,
      context: context,
      defaultValue: defaultValue,
      onError: onError,
    );
  }
}
