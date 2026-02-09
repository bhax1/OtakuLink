import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:otakulink/services/anilist_service.dart';
import 'package:otakulink/pages/home/manga_widgets/manga_card.dart';

enum CategoryType {
  trending,
  newReleases,
  hallOfFame,
  favorites,
  manhwa,
}

class SeeMorePage extends StatefulWidget {
  final String title;
  final CategoryType category;

  const SeeMorePage({super.key, required this.title, required this.category});

  @override
  State<SeeMorePage> createState() => _SeeMorePageState();
}

class _SeeMorePageState extends State<SeeMorePage> {
  bool _isLoading = true;
  List<dynamic> _items = [];
  int _currentPage = 1;
  int _lastPage = 1;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchPage(1);
  }

  Future<void> _fetchPage(int page) async {
    if (page < 1) return;
    
    setState(() => _isLoading = true);

    // Map Enum to Query Parameters
    PaginatedResult? result;
    
    switch (widget.category) {
      case CategoryType.trending:
        result = await AniListService.fetchPaginatedManga(page: page, sort: ['TRENDING_DESC']);
        break;
      case CategoryType.newReleases:
        int year = DateTime.now().year * 10000;
        result = await AniListService.fetchPaginatedManga(page: page, status: 'RELEASING', yearGreater: year, sort: ['POPULARITY_DESC']);
        break;
      case CategoryType.hallOfFame:
        result = await AniListService.fetchPaginatedManga(page: page, minScore: 88, sort: ['SCORE_DESC']);
        break;
      case CategoryType.favorites:
        result = await AniListService.fetchPaginatedManga(page: page, sort: ['FAVOURITES_DESC']);
        break;
      case CategoryType.manhwa:
         result = await AniListService.fetchPaginatedManga(page: page, country: 'KR', sort: ['TRENDING_DESC']);
        break;
    }

    if (mounted) {
      setState(() {
        if (result != null) {
          _items = result.items;
          _currentPage = result.currentPage;
          
          if (_lastPage == 1) {
            _lastPage = result.lastPage;
          } 
          else if (result.lastPage < _lastPage) {
            _lastPage = result.lastPage;
          }
          if (_scrollController.hasClients) _scrollController.jumpTo(0);
        }
        _isLoading = false;
      });
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
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
          // GRID
          Expanded(
            child: _isLoading 
              ? _buildShimmerGrid()
              : _items.isEmpty 
                  ? _buildEmptyState() // <--- NEW CHECK
                  : GridView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.55,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        return MangaCard(
                          manga: _items[index],
                          // Pass the current user ID just like you did in HomePage!
                          userId: FirebaseAuth.instance.currentUser?.uid, 
                        );
                      },
                    ),
          ),
          
          // PAGINATION CONTROLS
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _currentPage > 1 ? () => _fetchPage(_currentPage - 1) : null,
                    icon: const Icon(Icons.arrow_back_ios),
                  ),
                  
                  // Jump Trigger
                  InkWell(
                    onTap: !_isLoading ? _showJumpToDialog : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Text(
                            "Page $_currentPage / $_lastPage",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.unfold_more, size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  
                  IconButton(
                    onPressed: _currentPage < _lastPage ? () => _fetchPage(_currentPage + 1) : null,
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
      itemCount: 15,
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
          ElevatedButton.icon(
            onPressed: () => _fetchPage(1), // Reset to Page 1
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