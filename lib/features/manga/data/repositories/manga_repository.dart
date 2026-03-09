import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/features/manga/data/datasources/anilist_remote_data_source.dart';
import 'package:otakulink/features/manga/data/models/manga_models.dart';
import 'package:otakulink/features/manga/domain/entities/manga_entities.dart';
import 'package:otakulink/features/manga/domain/repositories/manga_repository_interface.dart';

export 'package:otakulink/features/manga/data/datasources/anilist_remote_data_source.dart'
    show PaginatedResult;

final anilistDataSourceProvider = Provider<AnilistRemoteDataSource>((ref) {
  return AnilistRemoteDataSource();
});

final mangaRepositoryProvider = Provider<MangaRepositoryInterface>((ref) {
  return MangaRepositoryImpl(
    remoteDataSource: ref.watch(anilistDataSourceProvider),
  );
});

/// Concrete implementation mapping raw data/DTOs to Domain Entities
class MangaRepositoryImpl implements MangaRepositoryInterface {
  final AnilistRemoteDataSource remoteDataSource;

  MangaRepositoryImpl({required this.remoteDataSource});

  // Global instance strictly for backwards compatibility of non-refactored widgets
  // TO BE REMOVED in Phase 4 once all UI is migrated
  static final MangaRepositoryImpl instance = MangaRepositoryImpl(
    remoteDataSource: AnilistRemoteDataSource(),
  );

  @override
  Future<void> cleanCache() {
    return remoteDataSource.cleanCache();
  }

  @override
  Future<void> invalidateSpecificCaches(List<String> cacheKeys) {
    return remoteDataSource.invalidateSpecificCaches(cacheKeys);
  }

  @override
  Future<List<MangaEntity>> fetchStandardList({
    required String query,
    required String cacheKey,
    required bool forceRefresh,
    required bool isNsfw,
    Map<String, dynamic>? variables,
  }) async {
    final rawList = await remoteDataSource.fetchStandardList(
      query: query,
      cacheKey: cacheKey,
      forceRefresh: forceRefresh,
      isNsfw: isNsfw,
      variables: variables,
    );
    return rawList
        .map((e) => MangaModel.fromAniList(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Map<String, dynamic>?> fetchRecommendations(
    int sourceId,
    String? currentTitle,
  ) async {
    // Kept as dynamic temporarily until Recommendations specific UI is refactored
    return remoteDataSource.fetchRecommendations(sourceId, currentTitle);
  }

  @override
  Future<MangaDetailEntity?> getMangaDetails(int id) async {
    final rawData = await remoteDataSource.getMangaDetails(id);
    if (rawData == null) return null;

    final manga = MangaModel.fromAniList(rawData);

    final characters =
        (rawData['characters']?['edges'] as List<dynamic>?)?.map((edge) {
          final person = PersonModel.fromAniListCharacter(
            edge['node'] as Map<String, dynamic>,
          );
          return person.copyWith(role: edge['role']?.toString());
        }).toList() ??
        [];

    final staff =
        (rawData['staff']?['edges'] as List<dynamic>?)?.map((edge) {
          final person = PersonModel.fromAniListStaff(
            edge['node'] as Map<String, dynamic>,
          );
          return person.copyWith(role: edge['role']?.toString());
        }).toList() ??
        [];

    final recommendations =
        (rawData['recommendations']?['nodes'] as List<dynamic>?)
            ?.where((node) => node['mediaRecommendation'] != null)
            .map(
              (node) => MangaModel.fromAniList(
                node['mediaRecommendation'] as Map<String, dynamic>,
              ),
            )
            .toList() ??
        [];

    return MangaDetailEntity(
      manga: manga,
      description: rawData['description']?.toString(),
      characters: characters,
      staff: staff,
      recommendations: recommendations,
    );
  }

  @override
  Future<PersonEntity?> getPersonDetails(int id, bool isStaff) async {
    final rawData = await remoteDataSource.getPersonDetails(id, isStaff);
    if (rawData == null) return null;
    return isStaff
        ? PersonModel.fromAniListStaff(rawData)
        : PersonModel.fromAniListCharacter(rawData);
  }

  @override
  Future<List<PersonEntity>> getFullPersonList({
    required int mediaId,
    required bool isStaff,
    int page = 1,
  }) async {
    final rawData = await remoteDataSource.getFullPersonList(
      mediaId: mediaId,
      isStaff: isStaff,
      page: page,
    );

    if (rawData == null) return [];

    final edges = rawData['edges'] as List<dynamic>? ?? [];

    return edges.map((edge) {
      final node = edge['node'] as Map<String, dynamic>;
      final person = isStaff
          ? PersonModel.fromAniListStaff(node)
          : PersonModel.fromAniListCharacter(node);
      return person.copyWith(role: edge['role']?.toString());
    }).toList();
  }

  @override
  Future<PaginatedMangaResultEntity?> fetchPaginatedManga({
    required int page,
    required bool isNsfw,
    List<String> sort = const ['TRENDING_DESC'],
    String? status,
    int? minScore,
    String? country,
    int? yearGreater,
  }) async {
    final rawResult = await remoteDataSource.fetchPaginatedManga(
      page: page,
      isNsfw: isNsfw,
      sort: sort,
      status: status,
      minScore: minScore,
      country: country,
      yearGreater: yearGreater,
    );

    if (rawResult == null) return null;

    final items = rawResult.items
        .map((e) => MangaModel.fromAniList(e as Map<String, dynamic>))
        .toList();

    return PaginatedMangaResultEntity(
      items: items,
      hasNextPage: rawResult.hasNextPage,
      lastPage: rawResult.lastPage,
      currentPage: rawResult.currentPage,
    );
  }

  @override
  Future<PaginatedMangaResultEntity?> fetchPaginatedRecommendations({
    required int mangaId,
    required int page,
  }) async {
    final rawResult = await remoteDataSource.fetchPaginatedRecommendations(
      mangaId: mangaId,
      page: page,
    );

    if (rawResult == null) return null;

    final items = rawResult.items
        .map((e) => MangaModel.fromAniList(e as Map<String, dynamic>))
        .toList();

    return PaginatedMangaResultEntity(
      items: items,
      hasNextPage: rawResult.hasNextPage,
      lastPage: rawResult.lastPage,
      currentPage: rawResult.currentPage,
    );
  }

  @override
  Future<Map<String, List<String>>> fetchAvailableFilters({
    required bool isNsfw,
  }) {
    return remoteDataSource.fetchAvailableFilters(isNsfw: isNsfw);
  }
}
