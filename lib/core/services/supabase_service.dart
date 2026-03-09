import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
import 'secure_storage_service.dart';

class SupabaseService {
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        localStorage: SecureStorageService(),
      ),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
