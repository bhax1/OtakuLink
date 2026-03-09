import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app.dart';
import 'core/services/supabase_service.dart';
import 'core/providers/shared_prefs_provider.dart';
import 'core/constants/app_constants.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Load app version
  final packageInfo = await PackageInfo.fromPlatform();
  AppConstants.version = packageInfo.version;

  // Initialize Core Services (like Supabase, Analytics, etc.)
  await SupabaseService.initialize();

  final prefs = await SharedPreferences.getInstance();

  // Run the app wrapped in Riverpod's ProviderScope for state management injection
  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const OtakuLinkApp(),
    ),
  );
}
