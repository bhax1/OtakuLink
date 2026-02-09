import 'package:flutter/material.dart';
import 'package:otakulink/pages/home/manga_widgets/person_card.dart';
import 'package:otakulink/services/anilist_service.dart';
import 'package:otakulink/theme.dart';

class PersonListPage extends StatefulWidget {
  final int mangaId;
  final String title;
  final bool isStaff;
  final List<dynamic>? initialItems;

  const PersonListPage({
    Key? key,
    required this.mangaId,
    required this.title,
    required this.isStaff,
    this.initialItems,
  }) : super(key: key);

  @override
  State<PersonListPage> createState() => _PersonListPageState();
}

class _PersonListPageState extends State<PersonListPage> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  
  List<dynamic> _items = [];
  final Set<int> _existingIds = {}; 

  bool _isLoading = false;
  bool _hasNextPage = true;
  int _currentPage = 1;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // 1. Load initial items and track their IDs
    if (widget.initialItems != null) {
      for (var item in widget.initialItems!) {
        if (item['node'] != null) {
          final id = item['node']['id'];
          if (!_existingIds.contains(id)) {
            _items.add(item);
            _existingIds.add(id);
          }
        }
      }
    }
    
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fetchNextPage();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasNextPage) {
      _fetchNextPage();
    }
  }

  Future<void> _fetchNextPage() async {
    if (!_hasNextPage || _isLoading) return;

    setState(() => _isLoading = true);

    final data = await AniListService.getFullPersonList(
      mediaId: widget.mangaId,
      isStaff: widget.isStaff,
      page: _currentPage,
    );

    if (mounted) {
      setState(() {
        if (data != null) {
          final newItems = data['edges'] as List;
          
          if (_currentPage == 1) {
            _items.clear();
            _existingIds.clear();
          }

          for (var item in newItems) {
            final id = item['node']['id'];
            if (!_existingIds.contains(id)) {
              _items.add(item);
              _existingIds.add(id);
            }
          }
          
          _hasNextPage = data['pageInfo']['hasNextPage'] ?? false;
          _currentPage++;
        } else {
          _hasNextPage = false;
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: Text(
          "${widget.isStaff ? 'Staff' : 'Characters'} - ${widget.title}",
          style: const TextStyle(fontSize: 16, overflow: TextOverflow.ellipsis, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _items.isEmpty && _isLoading
          ? _buildFullSkeletonGrid()
          : GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.7,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _items.length + (_hasNextPage ? 3 : 0),
              itemBuilder: (context, index) {
                if (index >= _items.length) {
                  return _buildSingleSkeletonItem();
                }

                final edge = _items[index];
                final node = edge['node'];
                final personId = node['id'];
                
                // RESTORED: Matches the tag used in MangaDetailsPage
                final String heroTag = 'person_${widget.mangaId}_$personId';
                
                return PersonCard(
                  id: personId,
                  name: node['name']['full'] ?? 'Unknown',
                  role: edge['role'] ?? (widget.isStaff ? 'Staff' : 'Character'),
                  imageUrl: node['image']['large'] ?? '',
                  isStaff: widget.isStaff,
                  heroTag: heroTag, // Pass the matching tag
                );
              },
            ),
    );
  }

  Widget _buildFullSkeletonGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 15, 
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) => _buildSingleSkeletonItem(),
    );
  }

  Widget _buildSingleSkeletonItem() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _pulseAnimation.value,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(height: 10, width: double.infinity, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 4),
              Container(height: 8, width: 60, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            ],
          ),
        );
      },
    );
  }
}