import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:otakulink/features/search/data/datasources/search_local_data_source.dart';
import 'package:otakulink/features/search/data/datasources/search_remote_data_source.dart';
import 'package:otakulink/features/search/domain/entities/search_filter_options.dart';
import 'package:otakulink/features/search/domain/entities/search_result_entity.dart';
import 'package:otakulink/features/search/domain/repositories/search_repository.dart';

final searchLocalDataSourceProvider = Provider<SearchLocalDataSource>((ref) {
  return SearchLocalDataSourceImpl();
});

final searchRemoteDataSourceProvider = Provider<SearchRemoteDataSource>((ref) {
  return SearchRemoteDataSourceImpl(supabase: Supabase.instance.client);
});

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepositoryImpl(
    remoteDataSource: ref.watch(searchRemoteDataSourceProvider),
    localDataSource: ref.watch(searchLocalDataSourceProvider),
  );
});

class SearchRepositoryImpl implements SearchRepository {
  final SearchRemoteDataSource remoteDataSource;
  final SearchLocalDataSource localDataSource;

  SearchRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<List<SearchResultEntity>> searchMedia({
    required String query,
    required String category,
    required SearchFilterOptions filters,
    required bool isNsfw,
  }) async {
    return await remoteDataSource.searchMedia(
      query: query,
      category: category,
      filters: filters,
      isNsfw: isNsfw,
    );
  }

  @override
  Future<List<SearchResultEntity>> searchUsers(String query) async {
    return await remoteDataSource.searchUsers(query);
  }

  @override
  Future<List<String>> getSearchHistory() async {
    return await localDataSource.getSearchHistory();
  }

  @override
  Future<void> saveSearchHistory(String query) async {
    return await localDataSource.saveSearchHistory(query);
  }

  @override
  Future<void> clearSearchHistory() async {
    return await localDataSource.clearSearchHistory();
  }
}
