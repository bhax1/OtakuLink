import 'package:flutter/foundation.dart';

enum LogSeverity { info, warning, error, fatal }

class SecureLogger {
  /// Simple wrapper for standard info logs
  static void info(String message) {
    _log(LogSeverity.info, message);
  }

  static void warning(String message) {
    _log(LogSeverity.warning, message);
  }

  /// Secure error tracker that intercepts exceptions for debugging and monitoring
  static void logError(
    String context,
    dynamic error, [
    StackTrace? stackTrace,
    LogSeverity severity = LogSeverity.error,
  ]) {
    final message = 'Error in $context: $error';
    _log(severity, message, stackTrace);
  }

  static void _log(
    LogSeverity severity,
    String message, [
    StackTrace? stackTrace,
  ]) {
    final prefix = '[${severity.name.toUpperCase()}]';
    final fullMessage = '$prefix $message';

    if (kDebugMode) {
      debugPrint('====================================');
      debugPrint(fullMessage);
      if (stackTrace != null) {
        debugPrint('Stacktrace:\n$stackTrace');
      }
      debugPrint('====================================');
    } else {
      // In Production, this is where you would send logs to Sentry, Firebase, or a local log file.
      // For now, we use debugPrint to ensure it's captured by log collectors but doesn't crash the UI.
      debugPrint(fullMessage);
      if (severity == LogSeverity.fatal || severity == LogSeverity.error) {
        // Placeholder for remote crash reporting
        // Sentry.captureException(error, stackTrace: stackTrace);
      }
    }
  }
}
