import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'secure_logger.dart';

/// A Riverpod observer that intercepts errors occurring within any provider.
/// Prevents silent failures in the state management layer.
class GlobalErrorObserver extends ProviderObserver {
  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    if (newValue is AsyncError) {
      SecureLogger.logError(
        'Provider(${provider.name ?? provider.runtimeType})',
        newValue.error,
        newValue.stackTrace,
      );
    }
  }

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    SecureLogger.logError(
      'ProviderFail(${provider.name ?? provider.runtimeType})',
      error,
      stackTrace,
      LogSeverity.fatal,
    );
  }
}
