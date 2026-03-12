import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app.dart';
import 'core/services/supabase_service.dart';
import 'core/providers/shared_prefs_provider.dart';
import 'core/constants/app_constants.dart';
import 'core/utils/secure_logger.dart';
import 'core/utils/error_observer.dart';

void main() async {
  // 1. Initialize Flutter Bindings
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Setup Global Framework Error Handling
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    SecureLogger.logError(
      'FlutterFramework',
      details.exception,
      details.stack,
      LogSeverity.fatal,
    );
  };

  // 3. Setup Global Asynchronous Error Handling (Platform Level)
  PlatformDispatcher.instance.onError = (error, stack) {
    SecureLogger.logError(
      'PlatformDispatcher',
      error,
      stack,
      LogSeverity.fatal,
    );
    return true; // Error has been handled
  };

  try {
    // 4. Load Environment & Constants
    await dotenv.load(fileName: ".env");
    final packageInfo = await PackageInfo.fromPlatform();
    AppConstants.version = packageInfo.version;

    // 5. Initialize Core Services
    await SupabaseService.initialize();
    final prefs = await SharedPreferences.getInstance();

    // 6. Run the app with Riverpod Observer
    runApp(
      ProviderScope(
        observers: [GlobalErrorObserver()],
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: const OtakuLinkApp(),
      ),
    );
  } catch (e, stack) {
    SecureLogger.logError('AppInitialization', e, stack, LogSeverity.fatal);
    // Optionally show a basic "Fatal Error" UI here if needed
  }
}
