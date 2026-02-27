import 'dart:async';
import 'package:flutter/material.dart';
import 'package:otakulink/core/api/anilist_service.dart';
import 'package:otakulink/core/models/search_models.dart';

class SearchFilterModal extends StatefulWidget {
  final FilterOptions initialFilters;

  const SearchFilterModal({Key? key, required this.initialFilters})
      : super(key: key);

  @override
  _SearchFilterModalState createState() => _SearchFilterModalState();
}

class _SearchFilterModalState extends State<SearchFilterModal>
    with SingleTickerProviderStateMixin {
  late FilterOptions _filters;
  Future<Map<String, List<String>>>? _filterDataFuture;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _filterDataFuture = AniListService.fetchAvailableFilters();

    // Safely copy the initial filters so we can mutate them locally
    _filters = FilterOptions(
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
                Text("Filters",
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => setState(() => _filters = FilterOptions()),
                  child: Text("Reset",
                      style: TextStyle(color: theme.colorScheme.error)),
                )
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
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());

                  final allGenres = snapshot.data!['genres']!;
                  final allTags = snapshot.data!['tags']!;

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      // Removed onChanged callback: State is handled internally now
                      _GeneralTab(filters: _filters),
                      _TagsTab(
                        filters: _filters,
                        genres: allGenres,
                        tags: allTags,
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
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context, _filters),
                  child: const Text("Apply Filters",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
  final FilterOptions filters;

  const _GeneralTab({required this.filters});

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
          Text("Sort By",
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            children: [
              'Most Popular',
              'Top Rated',
              'Trending',
              'Newest',
              'Oldest'
            ].map((key) {
              final valMap = {
                'Most Popular': 'POPULARITY_DESC',
                'Top Rated': 'SCORE_DESC',
                'Trending': 'TRENDING_DESC',
                'Newest': 'START_DATE_DESC',
                'Oldest': 'START_DATE_ASC'
              };
              final val = valMap[key];
              final isSelected = widget.filters.sort == val;

              return _OtakuChip(
                label: key,
                isSelected: isSelected,
                onTap: () {
                  FocusScope.of(context).unfocus();
                  // Update local state directly instead of rebuilding parent modal
                  setState(() {
                    widget.filters.sort = val!;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Text("Status",
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: widget.filters.status ?? '',
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: const [
              DropdownMenuItem(value: '', child: Text('Any Status')),
              DropdownMenuItem(value: 'RELEASING', child: Text('Releasing')),
              DropdownMenuItem(value: 'FINISHED', child: Text('Finished')),
              DropdownMenuItem(value: 'HIATUS', child: Text('Hiatus')),
            ],
            onChanged: (val) {
              FocusScope.of(context).unfocus();
              setState(() {
                widget.filters.status = (val == '') ? null : val;
              });
            },
          ),
        ],
      ),
    );
  }
}

// --- TAB 2: TAGS ---
class _TagsTab extends StatefulWidget {
  final FilterOptions filters;
  final List<String> genres;
  final List<String> tags;

  const _TagsTab({
    required this.filters,
    required this.genres,
    required this.tags,
  });

  @override
  _TagsTabState createState() => _TagsTabState();
}

class _TagsTabState extends State<_TagsTab> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  // Keep track of what to show so we don't calculate during build()
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

      // O(N) execution is safely contained in this one-off timer callback
      final results =
          widget.tags.where((t) => t.toLowerCase().contains(query)).toList();

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
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
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
                        setState(() {
                          val == true
                              ? widget.filters.tags.add(t)
                              : widget.filters.tags.remove(t);
                        });
                      },
                    );
                  },
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Genres",
                          style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.textTheme.bodyMedium?.color)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.genres
                            .map((g) => _OtakuChip(
                                  label: g,
                                  isSelected: widget.filters.genres.contains(g),
                                  onTap: () {
                                    FocusScope.of(context).unfocus();
                                    setState(() {
                                      widget.filters.genres.contains(g)
                                          ? widget.filters.genres.remove(g)
                                          : widget.filters.genres.add(g);
                                    });
                                  },
                                ))
                            .toList(),
                      ),
                      const Divider(height: 30),
                      Text("Popular Tags",
                          style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.textTheme.bodyMedium?.color)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _visibleTags
                            .map((t) => _OtakuChip(
                                  label: t,
                                  isSelected: widget.filters.tags.contains(t),
                                  onTap: () {
                                    FocusScope.of(context).unfocus();
                                    setState(() {
                                      widget.filters.tags.contains(t)
                                          ? widget.filters.tags.remove(t)
                                          : widget.filters.tags.add(t);
                                    });
                                  },
                                ))
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
              color:
                  isSelected ? theme.colorScheme.primary : Colors.transparent,
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
