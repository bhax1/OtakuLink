import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/features/search/data/repositories/search_repository_impl.dart';
import 'package:otakulink/features/search/domain/entities/search_filter_options.dart';
import 'package:otakulink/features/search/domain/entities/search_result_entity.dart';
import 'package:otakulink/features/settings/providers/settings_provider.dart';
import 'package:otakulink/core/utils/secure_logger.dart';

class SearchState {
  final List<SearchResultEntity> results;
  final bool isLoading;
  final bool isError;
  final String errorMessage;

  SearchState({
    this.results = const [],
    this.isLoading = false,
    this.isError = false,
    this.errorMessage = '',
  });

  SearchState copyWith({
    List<SearchResultEntity>? results,
    bool? isLoading,
    bool? isError,
    String? errorMessage,
  }) {
    return SearchState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      isError: isError ?? this.isError,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final searchHistoryProvider = FutureProvider.autoDispose<List<String>>((ref) {
  final repository = ref.watch(searchRepositoryProvider);
  return repository.getSearchHistory();
});

final searchControllerProvider =
    NotifierProvider<SearchController, SearchState>(SearchController.new);

class SearchController extends Notifier<SearchState> {
  Timer? _debounce;
  int _searchRequestId = 0;

  @override
  SearchState build() {
    ref.onDispose(() {
      _debounce?.cancel();
    });
    return SearchState();
  }

  void onSearchInputChanged({
    required String query,
    required String category,
    required SearchFilterOptions filters,
  }) {
    if (query.trim().isEmpty) {
      _debounce?.cancel();
      state = SearchState(results: [], isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true, isError: false, errorMessage: '');

    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 600), () {
      _executeSearch(query: query, category: category, filters: filters);
    });
  }

  void performInstantSearch({
    required String query,
    required String category,
    required SearchFilterOptions filters,
  }) {
    _debounce?.cancel();

    if (query.trim().isEmpty) {
      state = SearchState(results: [], isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true, isError: false, errorMessage: '');
    _executeSearch(query: query, category: category, filters: filters);
  }

  Future<void> _executeSearch({
    required String query,
    required String category,
    required SearchFilterOptions filters,
  }) async {
    final int currentRequestId = ++_searchRequestId;

    try {
      List<SearchResultEntity> results = [];
      final repository = ref.read(searchRepositoryProvider);
      if (category == 'Users') {
        results = await repository.searchUsers(query);
      } else {
        results = await repository.searchMedia(
          query: query,
          category: category,
          filters: filters,
          isNsfw: ref.read(settingsProvider).showAdultContent,
        );
      }

      if (currentRequestId != _searchRequestId) return;

      state = state.copyWith(results: results, isLoading: false);

      if (results.isNotEmpty) {
        await repository.saveSearchHistory(query);
      }
    } catch (e, stack) {
      if (currentRequestId != _searchRequestId) return;
      SecureLogger.logError("SearchController _executeSearch", e, stack);
      state = state.copyWith(
        isLoading: false,
        isError: true,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> clearHistory() async {
    await ref.read(searchRepositoryProvider).clearSearchHistory();
  }
}
