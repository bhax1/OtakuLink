import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/core/api/anilist_service.dart';
import 'package:otakulink/pages/manga/manga_widgets/manga_card.dart';
import 'package:otakulink/core/providers/settings_provider.dart';

enum CategoryType {
  trending,
  newReleases,
  hallOfFame,
  favorites,
  manhwa,
  recommendations,
}

class SeeMorePage extends ConsumerStatefulWidget {
  final String title;
  final CategoryType category;
  final int? mangaId;

  const SeeMorePage({
    super.key,
    required this.title,
    required this.category,
    this.mangaId,
  });

  @override
  ConsumerState<SeeMorePage> createState() => _SeeMorePageState();
}

class _SeeMorePageState extends ConsumerState<SeeMorePage> {
  bool _isLoading = true;
  List<dynamic> _items = [];
  int _currentPage = 1;
  int _lastPage = 1;

  final ScrollController _scrollController = ScrollController();
  final Map<int, List<dynamic>> _pageCache = {};

  @override
  void initState() {
    super.initState();
    // FIX 1: Safely trigger the Riverpod read after the first frame is built
    Future.microtask(() => _fetchPage(1));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchPage(int page) async {
    if (page < 1) return;

    if (_pageCache.containsKey(page)) {
      setState(() {
        _items = _pageCache[page]!;
        _currentPage = page;
        _isLoading = false;
      });
      _scrollToTop();
      return;
    }

    setState(() => _isLoading = true);
    PaginatedResult? result;

    try {
      final isNsfw = ref.read(settingsProvider).value?.isNsfw ?? false;

      switch (widget.category) {
        case CategoryType.trending:
          result = await AniListService.fetchPaginatedManga(
              page: page, isNsfw: isNsfw, sort: ['TRENDING_DESC']);
          break;
        case CategoryType.newReleases:
          int year = DateTime.now().year;
          result = await AniListService.fetchPaginatedManga(
              page: page,
              isNsfw: isNsfw,
              status: 'RELEASING',
              yearGreater: year,
              sort: ['POPULARITY_DESC']);
          break;
        case CategoryType.hallOfFame:
          result = await AniListService.fetchPaginatedManga(
              page: page, isNsfw: isNsfw, minScore: 88, sort: ['SCORE_DESC']);
          break;
        case CategoryType.favorites:
          result = await AniListService.fetchPaginatedManga(
              page: page, isNsfw: isNsfw, sort: ['FAVOURITES_DESC']);
          break;
        case CategoryType.manhwa:
          result = await AniListService.fetchPaginatedManga(
              page: page,
              isNsfw: isNsfw,
              country: 'KR',
              sort: ['TRENDING_DESC']);
          break;
        case CategoryType.recommendations:
          if (widget.mangaId != null) {
            result = await AniListService.fetchPaginatedRecommendations(
              mangaId: widget.mangaId!,
              page: page,
            );
          }
          break;
      }

      if (mounted) {
        setState(() {
          if (result != null) {
            _items = result.items;
            _currentPage = result.currentPage;

            _pageCache[_currentPage] = _items;

            if (_lastPage == 1 || result.lastPage < _lastPage) {
              _lastPage = result.lastPage;
            }

            _scrollToTop();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading page: $e')),
        );
      }
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showJumpToDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Jump to Page"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: "1 - $_lastPage",
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              final int? page = int.tryParse(controller.text);
              if (page != null && page > 0 && page <= _lastPage) {
                Navigator.pop(context);
                _fetchPage(page);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Invalid page number")),
                );
              }
            },
            child: const Text("Go"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        backgroundColor: theme.colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            // FIX 2: Removed AnimatedSwitcher and ValueKey to prevent layout crashes
            child: _isLoading
                ? _buildShimmerGrid()
                : _items.isEmpty
                    ? _buildEmptyState()
                    : GridView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.55,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          return MangaCard(manga: _items[index]);
                        },
                      ),
          ),

          // PAGINATION CONTROLS
          if (!_isLoading && _items.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, -2))
                ],
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: _currentPage > 1
                          ? () => _fetchPage(_currentPage - 1)
                          : null,
                      icon: const Icon(Icons.arrow_back_ios),
                    ),
                    InkWell(
                      onTap: !_isLoading ? _showJumpToDialog : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Text(
                              "Page $_currentPage / $_lastPage",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800]),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.unfold_more,
                                size: 16, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _currentPage < _lastPage
                          ? () => _fetchPage(_currentPage + 1)
                          : null,
                      icon: const Icon(Icons.arrow_forward_ios),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.55,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: 10,
      itemBuilder: (context, index) {
        return const MangaCard(isPlaceholder: true);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            "Page $_currentPage is empty",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "We couldn't find any manga here.",
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          if (_currentPage > 1)
            ElevatedButton.icon(
              onPressed: () => _fetchPage(1),
              icon: const Icon(Icons.refresh),
              label: const Text("Go Back to Start"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}
