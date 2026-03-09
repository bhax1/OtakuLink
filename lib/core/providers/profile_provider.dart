import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfile {
  final String id;
  final String username;
  final String? avatarUrl;

  UserProfile({required this.id, required this.username, this.avatarUrl});
}

final userProfileProvider = FutureProvider.family<UserProfile?, String>((
  ref,
  userId,
) async {
  final client = Supabase.instance.client;
  final data = await client
      .from('profiles')
      .select('id, username, avatar_url')
      .eq('id', userId)
      .maybeSingle();

  if (data == null) return null;
  return UserProfile(
    id: data['id'],
    username: data['username'] ?? 'Anonymous',
    avatarUrl: data['avatar_url'],
  );
});
