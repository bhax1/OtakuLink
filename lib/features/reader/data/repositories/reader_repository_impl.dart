import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:otakulink/core/services/mangadex_service.dart';
import 'package:otakulink/core/utils/secure_logger.dart';
import 'package:otakulink/features/reader/domain/repositories/reader_repository_interface.dart';

class ReaderRepositoryImpl implements ReaderRepositoryInterface {
  final SupabaseClient _client;

  ReaderRepositoryImpl(this._client);

  @override
  Future<List<Map<String, dynamic>>> fetchChapters(
    String mangaIdOrTitle, {
    String? dexId,
    List<String> titles = const [],
  }) async {
    String? finalDexId = dexId;

    // Basic UUID check: MangaDex IDs are 36-char UUIDs
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );

    SecureLogger.info(
      "ReaderRepository: Fetching chapters for '$mangaIdOrTitle'",
    );
    if (finalDexId != null && uuidRegex.hasMatch(finalDexId)) {
      SecureLogger.info(
        "ReaderRepository: Using provided MangaDex ID: $finalDexId",
      );
    } else if (uuidRegex.hasMatch(mangaIdOrTitle)) {
      finalDexId = mangaIdOrTitle;
      SecureLogger.info(
        "ReaderRepository: Found UUID in title string, using: $finalDexId",
      );
    } else {
      final searchTitles = [mangaIdOrTitle, ...titles];
      finalDexId = await MangaDexService.searchMangaIdWithFallbacks(searchTitles);
      SecureLogger.info(
        "ReaderRepository: Search for titles $searchTitles returned: $finalDexId",
      );
    }

    if (finalDexId == null) {
      SecureLogger.info(
        "ReaderRepository: dexId is null, returning empty list.",
      );
      return [];
    }

    final chapters = await MangaDexService.getChapters(finalDexId);
    SecureLogger.info("ReaderRepository: Found ${chapters.length} chapters.");
    return chapters;
  }

  @override
  Future<List<String>> fetchChapterPages(String chapterId) async {
    return MangaDexService.getChapterPages(chapterId);
  }

  @override
  Future<void> syncProgress({
    required String userId,
    required String mangaId,
    required String chapterId,
    required String chapterNum,
    int? pageIndex,
    double? verticalPixels,
  }) async {
    try {
      // We update the user_manga_list table with the last read information
      // metadata (title/image) is handled by the MangaDetailsPage/Controller
      await _client.from('user_manga_list').upsert({
        'user_id': userId,
        'manga_id': int.tryParse(mangaId) ?? 0,
        'last_read_id': chapterId,
        'last_chapter_num': chapterNum,
        'last_read_page': pageIndex ?? 0,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,manga_id');

      // We could also store more granular progress (page/pixels) if the schema supports it.
      // For now, we prioritize the core 'last read' state.
    } catch (e, stack) {
      // Silently fail or log error - progress sync shouldn't block the UI
      SecureLogger.logError("ReaderRepository syncProgress", e, stack);
    }
  }
}
