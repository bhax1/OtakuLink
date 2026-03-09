import 'package:otakulink/features/manga/domain/entities/manga_entities.dart';

abstract class MangaRepositoryInterface {
  Future<void> cleanCache();

  Future<void> invalidateSpecificCaches(List<String> cacheKeys);

  Future<List<MangaEntity>> fetchStandardList({
    required String query,
    required String cacheKey,
    required bool forceRefresh,
    required bool isNsfw,
    Map<String, dynamic>? variables,
  });

  Future<Map<String, dynamic>?> fetchRecommendations(
    int sourceId,
    String? currentTitle,
  );

  Future<MangaDetailEntity?> getMangaDetails(int id);

  Future<PersonEntity?> getPersonDetails(int id, bool isStaff);

  Future<List<PersonEntity>> getFullPersonList({
    required int mediaId,
    required bool isStaff,
    int page = 1,
  });

  Future<PaginatedMangaResultEntity?> fetchPaginatedManga({
    required int page,
    required bool isNsfw,
    List<String> sort = const ['TRENDING_DESC'],
    String? status,
    int? minScore,
    String? country,
    int? yearGreater,
  });

  Future<PaginatedMangaResultEntity?> fetchPaginatedRecommendations({
    required int mangaId,
    required int page,
  });

  Future<Map<String, List<String>>> fetchAvailableFilters({
    required bool isNsfw,
  });
}
