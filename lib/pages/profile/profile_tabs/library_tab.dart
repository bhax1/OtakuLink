import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:otakulink/core/models/library_filter_modal.dart';
import 'package:otakulink/repository/profile_repository.dart';
import 'package:otakulink/core/providers/settings_provider.dart';

class LibraryTab extends ConsumerStatefulWidget {
  final String userId;
  const LibraryTab({Key? key, required this.userId}) : super(key: key);

  @override
  ConsumerState<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends ConsumerState<LibraryTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _searchQuery = "";
  LibraryFilterSettings _settings = LibraryFilterSettings();
  final TextEditingController _searchController = TextEditingController();

  int _currentLimit = 30;
  static const int _limitIncrement = 30;
  bool _isFetchingMore = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openFilterModal() async {
    final result = await showModalBottomSheet<LibraryFilterSettings>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LibraryFilterModal(currentSettings: _settings),
    );

    if (result != null) {
      setState(() {
        _settings = result;
        _currentLimit = 30;
      });
    }
  }

  void _navigateToManga(String mangaId) {
    if (mangaId.isEmpty) return;
    final int? id = int.tryParse(mangaId);
    if (id != null) context.push('/manga/$id');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final profileRepo = ref.watch(profileRepositoryProvider);
    final isDataSaver = ref.watch(settingsProvider).value?.isDataSaver ?? false;
    final activeLimit = _searchQuery.isEmpty ? _currentLimit : 500;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search library...',
                    prefixIcon: Icon(Icons.search,
                        color: theme.colorScheme.onSurfaceVariant),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.3),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8), // Sharper corners
                      borderSide: BorderSide(
                          color: theme.dividerColor.withOpacity(0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: theme.dividerColor.withOpacity(0.2)),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = "");
                            },
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  InkWell(
                    onTap: _openFilterModal,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: theme.dividerColor.withOpacity(0.2)),
                      ),
                      child: Icon(Icons.tune_rounded,
                          color: theme.colorScheme.onSurface),
                    ),
                  ),
                  if (_settings.status != null || _settings.favoritesOnly)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: theme.colorScheme.surface, width: 2),
                        ),
                      ),
                    )
                ],
              )
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: profileRepo.getLibraryStream(
              uid: widget.userId,
              status: _settings.status,
              favoritesOnly: _settings.favoritesOnly,
              sortBy: _settings.sortBy,
              ascending: _settings.ascending,
              limit: activeLimit,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState(context, "Library empty.");
              }

              final totalDocsFetched = snapshot.data!.docs.length;
              var displayList = snapshot.data!.docs.where((doc) {
                if (_searchQuery.isEmpty) return true;
                final data = doc.data() as Map<String, dynamic>;
                final title = (data['title'] ?? '').toString().toLowerCase();
                return title.contains(_searchQuery.toLowerCase());
              }).toList();

              if (displayList.isEmpty)
                return _buildEmptyState(context, "No matches found.");

              return NotificationListener<ScrollNotification>(
                onNotification: (ScrollNotification scrollInfo) {
                  if (!_isFetchingMore &&
                      scrollInfo.metrics.pixels >=
                          scrollInfo.metrics.maxScrollExtent - 200) {
                    if (totalDocsFetched >= _currentLimit) {
                      setState(() {
                        _isFetchingMore = true;
                        _currentLimit += _limitIncrement;
                      });
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (mounted) setState(() => _isFetchingMore = false);
                      });
                    }
                  }
                  return false;
                },
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.68, // Taller covers
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: displayList.length,
                  itemBuilder: (context, index) {
                    return _buildLibraryItem(
                        context, displayList[index], isDataSaver);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLibraryItem(
      BuildContext context, DocumentSnapshot doc, bool isDataSaver) {
    final theme = Theme.of(context);
    final data = doc.data() as Map<String, dynamic>;
    final id = doc.id;
    final title = data['title'] ?? 'Unknown';
    final image = data['imageUrl'];
    final rating = (data['rating'] ?? 0).toDouble();
    final isFav = data['isFavorite'] == true;

    return GestureDetector(
      onTap: () => _navigateToManga(id),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: image != null
                  ? CachedNetworkImage(
                      imageUrl: image,
                      fit: BoxFit.cover,
                      memCacheHeight: isDataSaver ? 200 : 350,
                      errorWidget: (_, __, ___) => Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.broken_image)),
                    )
                  : Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.book)),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                    stops: [0.5, 1.0], // Sharper gradient for text
                  ),
                ),
              ),
            ),
            if (isFav)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4)),
                  child: const Icon(Icons.favorite,
                      color: Colors.redAccent, size: 14),
                ),
              ),
            if (rating > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(4)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, size: 10, color: Colors.black87),
                      const SizedBox(width: 2),
                      Text(rating.toString(),
                          style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black87,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    height: 1.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.collections_bookmark_outlined,
              size: 48, color: Theme.of(context).disabledColor),
          const SizedBox(height: 12),
          Text(message,
              style: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
