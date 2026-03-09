import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/core/services/anilist_service.dart';
import 'package:otakulink/features/search/domain/entities/search_filter_options.dart';
import 'package:otakulink/features/settings/providers/settings_provider.dart';

class SearchFilterModal extends ConsumerStatefulWidget {
  final SearchFilterOptions initialFilters;

  const SearchFilterModal({super.key, required this.initialFilters});

  @override
  ConsumerState<SearchFilterModal> createState() => SearchFilterModalState();
}

class SearchFilterModalState extends ConsumerState<SearchFilterModal>
    with SingleTickerProviderStateMixin {
  late SearchFilterOptions _filters;
  Future<Map<String, List<String>>>? _filterDataFuture;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final isNsfw = ref.read(settingsProvider).showAdultContent;
    _filterDataFuture = AniListService.fetchAvailableFilters(isNsfw: isNsfw);

    _filters = SearchFilterOptions(
      sort: widget.initialFilters.sort,
      status: widget.initialFilters.status,
      genres: List.from(widget.initialFilters.genres),
      tags: List.from(widget.initialFilters.tags),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updateFilters(SearchFilterOptions newFilters) {
    setState(() {
      _filters = newFilters;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Filters",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => _filters = SearchFilterOptions()),
                  child: Text(
                    "Reset",
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ],
            ),

            // Tabs
            TabBar(
              controller: _tabController,
              labelColor: theme.colorScheme.secondary,
              unselectedLabelColor: theme.disabledColor,
              indicatorColor: theme.colorScheme.secondary,
              tabs: const [
                Tab(text: "General"),
                Tab(text: "Tags & Genres"),
              ],
            ),

            const SizedBox(height: 10),

            // Content
            Expanded(
              child: FutureBuilder<Map<String, List<String>>>(
                future: _filterDataFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allGenres = snapshot.data!['genres']!;
                  final allTags = snapshot.data!['tags']!;

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _GeneralTab(filters: _filters, onChanged: _updateFilters),
                      _TagsTab(
                        filters: _filters,
                        genres: allGenres,
                        tags: allTags,
                        onChanged: _updateFilters,
                      ),
                    ],
                  );
                },
              ),
            ),

            // Apply Button
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context, _filters),
                  child: const Text(
                    "Apply Filters",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- TAB 1: GENERAL ---
class _GeneralTab extends StatefulWidget {
  final SearchFilterOptions filters;
  final ValueChanged<SearchFilterOptions> onChanged;

  const _GeneralTab({required this.filters, required this.onChanged});

  @override
  _GeneralTabState createState() => _GeneralTabState();
}

class _GeneralTabState extends State<_GeneralTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Sort By",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            children:
                [
                  'Most Popular',
                  'Top Rated',
                  'Trending',
                  'Newest',
                  'Oldest',
                ].map((key) {
                  final valMap = {
                    'Most Popular': 'POPULARITY_DESC',
                    'Top Rated': 'SCORE_DESC',
                    'Trending': 'TRENDING_DESC',
                    'Newest': 'START_DATE_DESC',
                    'Oldest': 'START_DATE_ASC',
                  };
                  final val = valMap[key]!;
                  final isSelected = widget.filters.sort == val;

                  return _OtakuChip(
                    label: key,
                    isSelected: isSelected,
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      widget.onChanged(widget.filters.copyWith(sort: val));
                    },
                  );
                }).toList(),
          ),
          const SizedBox(height: 20),
          Text(
            "Status",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: widget.filters.status ?? '',
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: const [
              DropdownMenuItem(value: '', child: Text('Any Status')),
              DropdownMenuItem(value: 'RELEASING', child: Text('Releasing')),
              DropdownMenuItem(value: 'FINISHED', child: Text('Finished')),
              DropdownMenuItem(value: 'HIATUS', child: Text('Hiatus')),
            ],
            onChanged: (val) {
              FocusScope.of(context).unfocus();
              widget.onChanged(
                widget.filters.copyWith(status: val == '' ? null : val),
              );
            },
          ),
        ],
      ),
    );
  }
}

// --- TAB 2: TAGS ---
class _TagsTab extends StatefulWidget {
  final SearchFilterOptions filters;
  final List<String> genres;
  final List<String> tags;
  final ValueChanged<SearchFilterOptions> onChanged;

  const _TagsTab({
    required this.filters,
    required this.genres,
    required this.tags,
    required this.onChanged,
  });

  @override
  _TagsTabState createState() => _TagsTabState();
}

class _TagsTabState extends State<_TagsTab> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  late List<String> _visibleTags;
  bool _isSearching = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _visibleTags = widget.tags.take(40).toList();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;

      if (val.trim().isEmpty) {
        setState(() {
          _isSearching = false;
          _visibleTags = widget.tags.take(40).toList();
        });
        return;
      }

      final query = val.toLowerCase();

      final results = widget.tags
          .where((t) => t.toLowerCase().contains(query))
          .toList();

      setState(() {
        _isSearching = true;
        _visibleTags = results;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return Column(
      children: [
        const SizedBox(height: 15),
        TextField(
          controller: _searchController,
          onChanged: _onSearch,
          decoration: InputDecoration(
            hintText: "Search tags...",
            prefixIcon: const Icon(Icons.search),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 0,
              horizontal: 10,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _isSearching
              ? ListView.builder(
                  itemCount: _visibleTags.length,
                  itemBuilder: (context, index) {
                    final t = _visibleTags[index];
                    final isSelected = widget.filters.tags.contains(t);
                    return CheckboxListTile(
                      title: Text(t),
                      value: isSelected,
                      activeColor: theme.colorScheme.primary,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        final updatedTags = List<String>.from(
                          widget.filters.tags,
                        );
                        if (val == true) {
                          updatedTags.add(t);
                        } else {
                          updatedTags.remove(t);
                        }
                        widget.onChanged(
                          widget.filters.copyWith(tags: updatedTags),
                        );
                      },
                    );
                  },
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Genres",
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.genres
                            .map(
                              (g) => _OtakuChip(
                                label: g,
                                isSelected: widget.filters.genres.contains(g),
                                onTap: () {
                                  FocusScope.of(context).unfocus();
                                  final updatedGenres = List<String>.from(
                                    widget.filters.genres,
                                  );
                                  if (updatedGenres.contains(g)) {
                                    updatedGenres.remove(g);
                                  } else {
                                    updatedGenres.add(g);
                                  }
                                  widget.onChanged(
                                    widget.filters.copyWith(
                                      genres: updatedGenres,
                                    ),
                                  );
                                },
                              ),
                            )
                            .toList(),
                      ),
                      const Divider(height: 30),
                      Text(
                        "Popular Tags",
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _visibleTags
                            .map(
                              (t) => _OtakuChip(
                                label: t,
                                isSelected: widget.filters.tags.contains(t),
                                onTap: () {
                                  FocusScope.of(context).unfocus();
                                  final updatedTags = List<String>.from(
                                    widget.filters.tags,
                                  );
                                  if (updatedTags.contains(t)) {
                                    updatedTags.remove(t);
                                  } else {
                                    updatedTags.add(t);
                                  }
                                  widget.onChanged(
                                    widget.filters.copyWith(tags: updatedTags),
                                  );
                                },
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _OtakuChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _OtakuChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary
                : (isDark ? Colors.grey[800] : Colors.grey[200]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.textTheme.bodyMedium?.color,
            ),
          ),
        ),
      ),
    );
  }
}
