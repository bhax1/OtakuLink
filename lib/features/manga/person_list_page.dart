import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/core/utils/secure_logger.dart';
import 'package:otakulink/features/manga/widgets/person_card.dart';
import 'package:otakulink/core/services/anilist_service.dart';
import 'package:otakulink/features/manga/domain/entities/manga_entities.dart';
import 'package:otakulink/features/manga/data/models/manga_models.dart';

class PersonListPage extends ConsumerStatefulWidget {
  final int mangaId;
  final String title;
  final bool isStaff;
  final List<dynamic>? initialItems;

  const PersonListPage({
    super.key,
    required this.mangaId,
    required this.title,
    required this.isStaff,
    this.initialItems,
  });

  @override
  ConsumerState<PersonListPage> createState() => _PersonListPageState();
}

class _PersonListPageState extends ConsumerState<PersonListPage>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();

  final List<PersonEntity> _items = [];
  final Set<int> _existingIds = {};

  bool _isLoading = false;
  bool _hasNextPage = true;
  int _currentPage = 1;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    if (widget.initialItems != null) {
      for (var item in widget.initialItems!) {
        if (item is PersonEntity) {
          if (!_existingIds.contains(item.id)) {
            _items.add(item);
            _existingIds.add(item.id);
          }
        } else if (item is Map) {
          final node = item['node'];
          final role = item['role']?.toString();
          if (node != null) {
            final id = node['id'] as int;
            if (!_existingIds.contains(id)) {
              final person = widget.isStaff
                  ? PersonModel.fromAniListStaff(node)
                  : PersonModel.fromAniListCharacter(node);

              // Override basic role from node with contextual role from edge!
              final refinedPerson = person.copyWith(role: role);

              _items.add(refinedPerson);
              _existingIds.add(id);
            }
          }
        }
      }
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (_items.isEmpty) {
      _fetchNextPage();
    }

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasNextPage) {
      _fetchNextPage();
    }
  }

  Future<void> _fetchNextPage() async {
    if (!_hasNextPage || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      final data = await AniListService.getFullPersonList(
        mediaId: widget.mangaId,
        isStaff: widget.isStaff,
        page: _currentPage,
      );

      if (mounted) {
        setState(() {
          if (data != null) {
            final newItems = data['edges'] as List;
            for (var item in newItems) {
              final node = item['node'] as Map<String, dynamic>?;
              final role = item['role']?.toString();
              if (node != null) {
                final id = node['id'] as int;
                if (!_existingIds.contains(id)) {
                  final person = widget.isStaff
                      ? PersonModel.fromAniListStaff(node)
                      : PersonModel.fromAniListCharacter(node);

                  final refinedPerson = person.copyWith(role: role);

                  _items.add(refinedPerson);
                  _existingIds.add(id);
                }
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
    } catch (e, stack) {
      if (mounted) setState(() => _isLoading = false);
      SecureLogger.logError("PersonListPage _fetchInitialItems", e, stack);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        elevation: 0,
        title: Text(
          widget.title,
          style: const TextStyle(
            fontSize: 16,
            overflow: TextOverflow.ellipsis,
            color: Colors.white,
          ),
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
                  return FadeTransition(
                    opacity: _pulseAnimation,
                    child: _buildStaticSkeletonItem(theme),
                  );
                }

                final person = _items[index];
                final personId = person.id;

                final String prefix = widget.isStaff ? 'staff' : 'person';
                final String heroTag = '${prefix}_${widget.mangaId}_$personId';

                // --- APPLY DATA SAVER LOGIC ---
                final imageUrl = person.image ?? '';

                return PersonCard(
                  id: personId,
                  name: person.name,
                  role: person.role ?? (widget.isStaff ? 'Staff' : 'Character'),
                  imageUrl: imageUrl, // Passed dynamically!
                  isStaff: widget.isStaff,
                  heroTag: heroTag,
                );
              },
            ),
    );
  }

  // ... [_buildFullSkeletonGrid and _buildStaticSkeletonItem remain the same]
  Widget _buildFullSkeletonGrid() {
    final theme = Theme.of(context);
    return FadeTransition(
      opacity: _pulseAnimation,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 15,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.7,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemBuilder: (context, index) => _buildStaticSkeletonItem(theme),
      ),
    );
  }

  Widget _buildStaticSkeletonItem(ThemeData theme) {
    final baseColor = theme.colorScheme.surfaceContainerHighest;

    return Column(
      children: [
        Container(
          height: 80,
          width: 80,
          decoration: BoxDecoration(color: baseColor, shape: BoxShape.circle),
        ),
        const SizedBox(height: 10),
        Container(
          height: 10,
          width: 80,
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 8,
          width: 50,
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}
