import 'package:flutter/material.dart' hide SearchBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:otakulink/features/search/domain/entities/search_filter_options.dart';
import 'package:otakulink/features/search/presentation/controllers/search_controller.dart';
import 'package:otakulink/features/search/widgets/search_filter_modal.dart';
import 'package:otakulink/features/search/widgets/search_result_tile.dart';
import 'package:otakulink/features/search/widgets/search_bar.dart';
import 'package:otakulink/features/auth/presentation/controllers/auth_controller.dart';

class SearchPage extends ConsumerStatefulWidget {
  final Function(int) onTabChange;
  const SearchPage({super.key, required this.onTabChange});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  String _currentQuery = '';
  String _selectedCategory = 'Manga';
  final List<String> _categories = [
    'Manga',
    'Manhwa',
    'Manhua',
    'Novels',
    'Users',
  ];
  SearchFilterOptions _filters = SearchFilterOptions();

  void _onSearchInputChanged(String query) {
    _currentQuery = query;
    ref
        .read(searchControllerProvider.notifier)
        .onSearchInputChanged(
          query: query,
          category: _selectedCategory,
          filters: _filters,
        );
  }

  void _performInstantSearch(String query) {
    _currentQuery = query;
    ref
        .read(searchControllerProvider.notifier)
        .performInstantSearch(
          query: query,
          category: _selectedCategory,
          filters: _filters,
        );
  }

  void _clearHistory() {
    ref.read(searchControllerProvider.notifier).clearHistory();
    // Invalidate the provider so it fetches empty history
    ref.invalidate(searchHistoryProvider);
  }

  void _showFilters() async {
    final result = await showModalBottomSheet<SearchFilterOptions>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SearchFilterModal(initialFilters: _filters),
    );

    if (result != null) {
      setState(() => _filters = result);
      _performInstantSearch(_currentQuery);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 12),
                if (_filters.isActive && _selectedCategory != 'Users')
                  _buildActiveFilters(),
                if (_filters.isActive && _selectedCategory != 'Users')
                  const SizedBox(height: 10),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCategory,
              icon: const Icon(Icons.arrow_drop_down, size: 20),
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              items: _categories
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedCategory = val;
                    if (val == 'Users') {
                      _filters = SearchFilterOptions();
                    }
                  });
                  _performInstantSearch(_currentQuery);
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SearchBar(
            onChanged: _onSearchInputChanged,
            onFilterTap: _showFilters,
            areFiltersActive: _filters.isActive,
            hintText: 'Search $_selectedCategory...',
          ),
        ),
      ],
    );
  }

  Widget _buildActiveFilters() {
    return SizedBox(
      height: 30,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (_filters.status != null) _buildMiniChip(_filters.status!),
          ..._filters.genres.map((g) => _buildMiniChip(g)),
        ],
      ),
    );
  }

  Widget _buildMiniChip(String label) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBody() {
    final searchState = ref.watch(searchControllerProvider);

    if (searchState.isLoading) {
      return Center(child: Image.asset('assets/gif/loading.gif', height: 150));
    }

    if (searchState.isError) {
      return Center(child: Text("Error: ${searchState.errorMessage}"));
    }

    if (_currentQuery.isNotEmpty && searchState.results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/pic/sorry.png', width: 150),
            const SizedBox(height: 10),
            const Text("No results found."),
          ],
        ),
      );
    }

    if (_currentQuery.isEmpty) {
      return _buildHistory();
    }

    return ListView.builder(
      itemCount: searchState.results.length,
      itemBuilder: (context, index) {
        final item = searchState.results[index];
        final currentUserId = ref.read(authControllerProvider).valueOrNull?.id;

        return SearchResultTile(
          item: item,
          onTap: () {
            if (item.type == 'user') {
              if (currentUserId != null && item.stringId == currentUserId) {
                // If clicking ourselves, just go to the 'Me' tab
                widget.onTabChange(4);
              } else {
                context.push(
                  '/profile/${item.title}',
                  extra: {'targetUserId': item.stringId},
                );
              }
            } else {
              context.push('/manga/${item.id}');
            }
          },
        );
      },
    );
  }

  Widget _buildHistory() {
    final historyAsyncValue = ref.watch(searchHistoryProvider);

    return historyAsyncValue.when(
      data: (history) {
        if (history.isEmpty) {
          return const Center(
            child: Icon(Icons.search, size: 80, color: Colors.grey),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Recent Searches",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: _clearHistory,
                  child: Text(
                    "Clear All",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: history
                  .map(
                    (term) => ActionChip(
                      label: Text(term),
                      onPressed: () => _performInstantSearch(term),
                    ),
                  )
                  .toList(),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
    );
  }
}
