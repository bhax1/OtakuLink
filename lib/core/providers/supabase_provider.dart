import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

/// Provides the globally initialized SupabaseClient instance
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return SupabaseService.client;
});
