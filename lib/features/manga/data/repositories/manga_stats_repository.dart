import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:otakulink/features/manga/domain/entities/manga_stats_entity.dart';
import 'package:otakulink/core/providers/supabase_provider.dart';

abstract class MangaStatsRepositoryInterface {
  Stream<MangaStatsEntity?> streamMangaStats(int mangaId);
}

class SupabaseMangaStatsRepository implements MangaStatsRepositoryInterface {
  final SupabaseClient _client;

  SupabaseMangaStatsRepository(this._client);

  @override
  Stream<MangaStatsEntity?> streamMangaStats(int mangaId) {
    return _client
        .from('manga_stats')
        .stream(primaryKey: ['manga_id'])
        .eq('manga_id', mangaId)
        .map((event) {
          if (event.isEmpty) return null;
          return MangaStatsEntity.fromJson(event.first);
        });
  }
}

final mangaStatsRepositoryProvider = Provider<MangaStatsRepositoryInterface>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseMangaStatsRepository(client);
});

final mangaStatsStreamProvider = StreamProvider.family<MangaStatsEntity?, int>((
  ref,
  mangaId,
) {
  final repo = ref.watch(mangaStatsRepositoryProvider);
  return repo.streamMangaStats(mangaId);
});
