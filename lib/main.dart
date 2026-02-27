import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:otakulink/core/providers/theme_provider.dart';
import 'package:otakulink/core/routes/app_router.dart';
import 'package:otakulink/core/theme/app_theme.dart';
import 'package:otakulink/core/security/security_guard.dart';
import 'package:otakulink/core/utils/true_time_service.dart';
import 'package:otakulink/core/cache/local_cache_service.dart';

import 'package:otakulink/features/shared/connectivity_wrapper.dart';
import 'package:otakulink/features/auth/pages/lockdown_page.dart';

import 'package:otakulink/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1️⃣ SECURITY CHECK
  final bool isSecure = await SecurityGuard.isDeviceSecure();

  if (!isSecure) {
    runApp(const LockdownPage());
    return;
  }

  // 2️⃣ INITIALIZATION
  ThemeMode startingTheme = ThemeMode.light; // Default fallback

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize Cache Service (This replaces Hive.initFlutter)
    await LocalCacheService.init();

    // Fetch the theme BEFORE the app runs to prevent UI flashing
    final String themeString =
        await LocalCacheService.getSetting('theme', defaultValue: 'light');
    startingTheme = themeString == 'light' ? ThemeMode.light : ThemeMode.dark;

    // Initialize TrueTime
    await TrueTimeService.init();
  } catch (e) {
    debugPrint('Initialization Error: $e');
    // TRAP THE USER: Prevent Firebase from being called down the line
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Failed to initialize app securely.\nPlease restart the application.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
    return;
  }

  // 3️⃣ RUN APP
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(
    ProviderScope(
      // Inject the pre-fetched theme into the Riverpod tree
      overrides: [
        initialThemeModeProvider.overrideWithValue(startingTheme),
      ],
      child: const OtakuLinkApp(),
    ),
  );
}

// main.dart (Inside OtakuLinkApp)
class OtakuLinkApp extends ConsumerWidget {
  const OtakuLinkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This will now instantly return the correct cached theme
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'OtakuLink',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      builder: (context, child) {
        return ConnectivityWrapper(
          child: child!,
        );
      },
      routerConfig: goRouter,
    );
  }
}
