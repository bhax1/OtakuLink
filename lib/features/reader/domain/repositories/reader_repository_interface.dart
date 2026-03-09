abstract class ReaderRepositoryInterface {
  /// Fetches the list of chapters for a given manga title/dexId
  Future<List<Map<String, dynamic>>> fetchChapters(String mangaIdOrTitle);

  /// Fetches the image URLs for a specific chapter
  Future<List<String>> fetchChapterPages(String chapterId);

  /// Updates reading progress in the backend (Supabase)
  Future<void> syncProgress({
    required String userId,
    required String mangaId,
    required String chapterId,
    required String chapterNum,
    int? pageIndex,
    double? verticalPixels,
  });
}
