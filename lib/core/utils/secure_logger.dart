import 'package:flutter/foundation.dart';

class SecureLogger {
  /// Simple wrapper for standard info logs
  static void info(String message) {
    if (kDebugMode) {
      debugPrint('[INFO] $message');
    }
  }

  /// Secure error tracker that intercepts exceptions for debugging without crashing dev builds
  static void logError(
    String context,
    dynamic error, [
    StackTrace? stackTrace,
  ]) {
    if (kDebugMode) {
      debugPrint('====================================');
      debugPrint('[ERROR] in $context');
      debugPrint('Details: $error');
      if (stackTrace != null) {
        debugPrint('Stacktrace:\\n$stackTrace');
      }
      debugPrint('====================================');
    }
  }
}
