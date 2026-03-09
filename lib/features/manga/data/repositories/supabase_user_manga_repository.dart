import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:otakulink/features/manga/domain/entities/user_manga_entity.dart';
import 'package:otakulink/features/manga/domain/repositories/user_manga_repository_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/core/providers/supabase_provider.dart';

class SupabaseUserMangaRepository implements UserMangaRepositoryInterface {
  final SupabaseClient _client;

  SupabaseUserMangaRepository(this._client);

  @override
  Future<UserMangaEntry?> getUserMangaEntry(String userId, int mangaId) async {
    // 1. Fetch core library data and manga metadata
    final response = await _client
        .from('user_manga_list')
        .select('*, mangas(*)')
        .eq('user_id', userId)
        .eq('manga_id', mangaId)
        .maybeSingle();

    if (response == null) return null;

    final Map<String, dynamic> data = Map.from(response);

    // 2. Fetch private notes separately (prevents PGRST200 join error)
    final notesResponse = await _client
        .from('user_manga_notes')
        .select('notes')
        .eq('user_id', userId)
        .eq('manga_id', mangaId)
        .maybeSingle();

    if (notesResponse != null) {
      data['comment'] = notesResponse['notes'];
    }

    return UserMangaEntry.fromJson(data);
  }

  @override
  Future<void> saveEntry(UserMangaEntry entry) async {
    // 1. Sync central manga metadata first via RPC (handles RLS/exists checks)
    if (entry.title != null) {
      await _client.rpc(
        'sync_manga_metadata',
        params: {
          'p_id': entry.mangaId,
          'p_title': entry.title,
          'p_cover_url': entry.coverUrl,
          'p_description': entry.description,
        },
      );
    }

    // 2. Sync user-specific library data
    final Map<String, dynamic> libraryData = entry.toJson();
    await _client
        .from('user_manga_list')
        .upsert(libraryData, onConflict: 'user_id,manga_id');

    // 3. Sync private notes
    if (entry.comment != null) {
      await _client.from('user_manga_notes').upsert({
        'user_id': entry.userId,
        'manga_id': entry.mangaId,
        'notes': entry.comment,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,manga_id');
    }
  }

  @override
  Future<List<UserMangaEntry>> getUserLibrary(String userId) async {
    // 1. Fetch all library entries for the user
    final List<dynamic> libraryResponse = await _client
        .from('user_manga_list')
        .select('*, mangas(*)')
        .eq('user_id', userId)
        .order('updated_at', ascending: false);

    // 2. Fetch all notes for the user in a single batch query
    final List<dynamic> notesResponse = await _client
        .from('user_manga_notes')
        .select('manga_id, notes')
        .eq('user_id', userId);

    // 3. Map notes to manga IDs for quick lookup
    final Map<int, String> notesMap = {
      for (var note in notesResponse)
        note['manga_id'] as int: note['notes'] as String,
    };

    // 4. Combine data and map to entities
    return libraryResponse.map((res) {
      final Map<String, dynamic> data = Map.from(res);
      data['comment'] = notesMap[data['manga_id']];
      return UserMangaEntry.fromJson(data);
    }).toList();
  }

  @override
  Future<void> deleteEntry(String userId, int mangaId) async {
    // Note: user_manga_notes has ON DELETE CASCADE from user_id,
    // but not from manga_id? Actually I should check the schema.
    // It has ON DELETE CASCADE for user_id.
    // For manga_id, we should manually delete or add a foreign key if appropriate.
    // For now, let's just delete both manually to be sure.

    await Future.wait([
      _client
          .from('user_manga_list')
          .delete()
          .eq('user_id', userId)
          .eq('manga_id', mangaId),
      _client
          .from('user_manga_notes')
          .delete()
          .eq('user_id', userId)
          .eq('manga_id', mangaId),
    ]);
  }
}

final userMangaRepositoryProvider = Provider<UserMangaRepositoryInterface>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseUserMangaRepository(client);
});
