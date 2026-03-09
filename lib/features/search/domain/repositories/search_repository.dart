import 'package:otakulink/features/search/domain/entities/search_filter_options.dart';
import 'package:otakulink/features/search/domain/entities/search_result_entity.dart';

abstract class SearchRepository {
  Future<List<SearchResultEntity>> searchMedia({
    required String query,
    required String category,
    required SearchFilterOptions filters,
    required bool isNsfw,
  });

  Future<List<SearchResultEntity>> searchUsers(String query);

  Future<List<String>> getSearchHistory();

  Future<void> saveSearchHistory(String query);

  Future<void> clearSearchHistory();
}
