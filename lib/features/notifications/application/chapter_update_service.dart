import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/core/utils/secure_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:otakulink/core/services/mangadex_service.dart';
import 'package:otakulink/features/auth/presentation/controllers/auth_controller.dart';
import 'package:otakulink/core/providers/supabase_provider.dart';

class ChapterUpdateService {
  final SupabaseClient _client;
  final String? _userId;

  ChapterUpdateService(this._client, this._userId);

  Future<void> checkForUpdates() async {
    if (_userId == null) return;

    try {
      // 1. Fetch user's reading list (where status is not 'Dropped')
      final response = await _client
          .from('user_manga_list')
          .select(
            'manga_id, status, latest_chapter_notified, mangas(title, cover_url)',
          )
          .eq('user_id', _userId)
          .neq('status', 'Dropped');

      final list = List<Map<String, dynamic>>.from(response);

      for (final item in list) {
        // Mangas is queried as an inner join object
        final mangasData = item['mangas'];
        final Map<String, dynamic>? manga = mangasData is List
            ? (mangasData.isNotEmpty ? mangasData[0] : null)
            : mangasData;

        if (manga == null) continue;

        final mangaId = item['manga_id'];
        final title = manga['title'] as String?;
        final latestNotified = item['latest_chapter_notified'] as String?;

        if (title == null || title.isEmpty) continue;

        // 2. Resolve MangaDex ID
        final mangadexId = await MangaDexService.searchMangaId(title);
        if (mangadexId == null) continue;

        // 3. Fetch latest chapter
        final latestChapter = await MangaDexService.getLatestChapter(
          mangadexId,
        );
        if (latestChapter == null) continue;

        final chapterId = latestChapter['id'] as String;

        // 4. Compare and Insert if new
        if (latestNotified != chapterId) {
          // Double check if we haven't already inserted a notification for this chapter
          final existingNotif = await _client
              .from('notifications')
              .select('id')
              .eq('user_id', _userId)
              .eq('manga_id', mangaId)
              .eq('chapter_id', chapterId)
              .maybeSingle();

          if (existingNotif == null) {
            await _client.from('notifications').insert({
              'user_id': _userId,
              'type': 'new_chapter',
              'manga_id': mangaId,
              'chapter_id': chapterId,
              'chapter_number': latestChapter['chapter'],
            });
          }

          // Update library tracker
          await _client
              .from('user_manga_list')
              .update({'latest_chapter_notified': chapterId})
              .eq('user_id', _userId)
              .eq('manga_id', mangaId);
        }
      }
    } catch (e, stack) {
      SecureLogger.logError("ChapterUpdateService checkForUpdates", e, stack);
    }
  }
}

final chapterUpdateServiceProvider = Provider<ChapterUpdateService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final userId = ref.watch(authControllerProvider).valueOrNull?.id;
  return ChapterUpdateService(client, userId);
});
