import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide SearchBar;
import 'package:flutter_riverpod/flutter_riverpod.dart'; // ADD THIS
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:otakulink/core/api/anilist_queries.dart';
import 'package:otakulink/core/models/search_models.dart';
import 'package:otakulink/pages/search/widgets/search_filter_modal.dart';
import 'package:otakulink/core/api/anilist_service.dart';
import 'package:otakulink/pages/search/widgets/search_result_tile.dart';
import 'package:otakulink/pages/search/widgets/search_bar.dart';
import 'package:otakulink/core/providers/settings_provider.dart'; // Import Settings

// Convert to ConsumerStatefulWidget
class SearchPage extends ConsumerStatefulWidget {
  final Function(int) onTabChange;
  const SearchPage({Key? key, required this.onTabChange}) : super(key: key);

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  List<SearchResult> _results = [];
  bool _isLoading = false;
  bool _noResultsFound = false;
  String _currentQuery = '';

  Timer? _debounce;
  int _searchRequestId = 0;

  String _selectedCategory = 'Manga';
  final List<String> _categories = [
    'Manga',
    'Manhwa',
    'Manhua',
    'Novels',
    'Users'
  ];
  FilterOptions _filters = FilterOptions();

  late Future<Box> _historyBoxFuture;

  @override
  void initState() {
    super.initState();
    _historyBoxFuture = Hive.openBox('searchHistory');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchInputChanged(String query) {
    _currentQuery = query;

    if (query.trim().isEmpty) {
      _debounce?.cancel();
      setState(() {
        _results = [];
        _noResultsFound = false;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _noResultsFound = false;
    });

    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 600), () {
      _executeSearch(query);
    });
  }

  void _performInstantSearch(String query) {
    _debounce?.cancel();
    _currentQuery = query;

    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _noResultsFound = false;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _noResultsFound = false;
    });

    _executeSearch(query);
  }

  Future<void> _executeSearch(String query) async {
    final int currentRequestId = ++_searchRequestId;

    try {
      List<SearchResult> tempResults = [];

      if (_selectedCategory == 'Users') {
        tempResults = await _searchUsers(query);
      } else {
        final Map<String, dynamic> variables = {
          'search': query,
          'sort': [_filters.sort],
        };

        if (_filters.status != null && _filters.status!.isNotEmpty) {
          variables['status'] = _filters.status;
        }
        if (_filters.genres.isNotEmpty) variables['genres'] = _filters.genres;
        if (_filters.tags.isNotEmpty) variables['tags'] = _filters.tags;
        if (_selectedCategory == 'Novels') variables['format'] = 'NOVEL';
        if (_selectedCategory == 'Manhwa') variables['country'] = 'KR';
        if (_selectedCategory == 'Manhua') variables['country'] = 'CN';

        // 1. Instantly read the NSFW setting from RAM via Riverpod
        final isNsfw = ref.watch(settingsProvider).value?.isNsfw ?? false;
        // 2. Pass it down synchronously
        final rawData = await AniListService.fetchStandardList(
          query: AniListQueries.search,
          cacheKey: 'search_${query}_${_selectedCategory}_${_filters.sort}',
          forceRefresh: true,
          isNsfw: isNsfw, // <-- Provide it here
          variables: variables,
        );

        tempResults = rawData.map((e) => SearchResult.fromAniList(e)).toList();
      }

      if (currentRequestId != _searchRequestId) return;

      if (mounted) {
        setState(() {
          _results = tempResults;
          _noResultsFound = tempResults.isEmpty;
          _isLoading = false;
        });
        if (tempResults.isNotEmpty) _saveHistory(query);
      }
    } catch (e) {
      if (currentRequestId != _searchRequestId) return;
      debugPrint("Search Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<SearchResult>> _searchUsers(String query) async {
    try {
      String lowercaseQuery = query.toLowerCase();

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('usernameLowercase', isGreaterThanOrEqualTo: lowercaseQuery)
          .where('usernameLowercase',
              isLessThanOrEqualTo: '$lowercaseQuery\uf8ff')
          .limit(10)
          .get();

      return snapshot.docs
          .map((doc) => SearchResult.fromFirebase(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint("User Search Error: $e");
      return [];
    }
  }

  Future<void> _saveHistory(String query) async {
    var box = await Hive.openBox('searchHistory');
    List<String> history =
        box.get('recent', defaultValue: <String>[])!.cast<String>();
    history.remove(query);
    history.insert(0, query);
    if (history.length > 10) history = history.sublist(0, 10);
    await box.put('recent', history);
  }

  Future<void> _clearHistory() async {
    var box = await Hive.openBox('searchHistory');
    await box.clear();
    setState(() {});
  }

  void _showFilters() async {
    final result = await showModalBottomSheet<FilterOptions>(
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

  // --- UI Methods ---

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
                  fontSize: 13),
              items: _categories
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedCategory = val;
                    if (val == 'Users') {
                      _results.clear();
                      _filters = FilterOptions();
                    }
                  });
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SearchBar(
            onChanged: _onSearchInputChanged, // Trigger the debounced path
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
          color: theme.colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: theme.colorScheme.primary.withOpacity(0.3))),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: Image.asset('assets/gif/loading.gif', height: 150));
    }

    if (_noResultsFound) {
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

    if (_results.isEmpty) {
      return _buildHistory();
    }

    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final item = _results[index];
        return SearchResultTile(
          item: item,
          onTap: () {
            if (item.type == 'user') {
              final currentUid = FirebaseAuth.instance.currentUser?.uid;
              if (currentUid == item.stringId) {
                widget.onTabChange(4);
              } else {
                // FIX: Use item.title instead of item.username
                context.push(
                  '/profile/${item.title}',
                  extra: {'targetUserId': item.stringId},
                );
              }
            } else {
              // FIX: Update Manga details to use GoRouter as well!
              context.push('/manga/${item.id}');
            }
          },
        );
      },
    );
  }

  Widget _buildHistory() {
    return FutureBuilder(
      future: _historyBoxFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final box = snapshot.data as Box;
          final List<String> history =
              box.get('recent', defaultValue: <String>[])!.cast<String>();

          if (history.isEmpty) {
            return const Center(
                child: Icon(Icons.search, size: 80, color: Colors.grey));
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Recent Searches",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: _clearHistory,
                    child: Text("Clear All",
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12)),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: history
                    .map((term) => ActionChip(
                          label: Text(term),
                          onPressed: () => _performInstantSearch(
                              term), // Trigger the instant path
                        ))
                    .toList(),
              ),
            ],
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
