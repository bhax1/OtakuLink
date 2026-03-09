import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/i_discussion_repository.dart';
import 'supabase_discussion_repository.dart';

final discussionRepositoryProvider = Provider<IDiscussionRepository>((ref) {
  final client = Supabase.instance.client;
  return SupabaseDiscussionRepository(client);
});

// This file is now redirected to SupabaseDiscussionRepository via the provider above.
