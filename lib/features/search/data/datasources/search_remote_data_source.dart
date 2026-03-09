import 'package:otakulink/core/services/anilist_queries.dart';
import 'package:otakulink/core/services/anilist_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:otakulink/features/search/data/models/search_result_model.dart';
import 'package:otakulink/features/search/domain/entities/search_filter_options.dart';

abstract class SearchRemoteDataSource {
  Future<List<SearchResultModel>> searchMedia({
    required String query,
    required String category,
    required SearchFilterOptions filters,
    required bool isNsfw,
  });

  Future<List<SearchResultModel>> searchUsers(String query);
}

class SearchRemoteDataSourceImpl implements SearchRemoteDataSource {
  final SupabaseClient supabase;

  SearchRemoteDataSourceImpl({required this.supabase});

  @override
  Future<List<SearchResultModel>> searchMedia({
    required String query,
    required String category,
    required SearchFilterOptions filters,
    required bool isNsfw,
  }) async {
    final Map<String, dynamic> variables = {
      'search': query,
      'sort': [filters.sort],
    };

    if (filters.status != null && filters.status!.isNotEmpty) {
      variables['status'] = filters.status;
    }
    if (filters.genres.isNotEmpty) variables['genres'] = filters.genres;
    if (filters.tags.isNotEmpty) variables['tags'] = filters.tags;
    if (category == 'Novels') variables['format'] = 'NOVEL';
    if (category == 'Manhwa') variables['country'] = 'KR';
    if (category == 'Manhua') variables['country'] = 'CN';

    final rawData = await AniListService.fetchStandardList(
      query: AniListQueries.search,
      cacheKey: 'search_${query}_${category}_${filters.sort}',
      forceRefresh: true,
      isNsfw: isNsfw,
      variables: variables,
    );

    return rawData
        .map((e) => SearchResultModel.fromAniList(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<SearchResultModel>> searchUsers(String query) async {
    final response = await supabase
        .from('profiles')
        .select()
        .ilike('username', '%$query%')
        .limit(10);

    return response
        .map((data) => SearchResultModel.fromSupabase(data))
        .toList();
  }
}
