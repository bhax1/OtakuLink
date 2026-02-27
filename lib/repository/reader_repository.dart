import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/core/api/mangadex_service.dart';

class ReaderRepository {
  Future<List<Map<String, dynamic>>> fetchChapters(String title) async {
    try {
      final dexId = await MangaDexService.searchMangaId(title);
      if (dexId == null) throw Exception("Manga not found on MangaDex.");

      final chapters = await MangaDexService.getChapters(dexId);
      if (chapters.isEmpty) throw Exception("No English chapters available.");

      return chapters;
    } catch (e) {
      rethrow;
    }
  }
}

final readerRepositoryProvider = Provider<ReaderRepository>((ref) {
  return ReaderRepository();
});
