import 'package:flutter/foundation.dart';

class SecureLogger {
  /// Logs errors safely without leaking stack traces in production.
  static void logError(String context, Object error, [StackTrace? stackTrace]) {
    if (kReleaseMode) {
      // TODO: Route to a secure remote logging service (e.g., Firebase Crashlytics)
      // FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: context);
    } else {
      debugPrint('[ERROR - $context]: $error');
    }
  }

  /// Logs general info only during development.
  static void info(String message) {
    if (!kReleaseMode) {
      debugPrint('[INFO]: $message');
    }
  }
}
