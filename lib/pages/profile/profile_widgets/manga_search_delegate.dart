import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:otakulink/core/api/anilist_queries.dart';
import 'package:otakulink/core/api/anilist_service.dart';
import 'package:otakulink/core/models/user_model.dart';

class MangaSearchDelegate extends SearchDelegate<TopPickItem?> {
  final bool isNsfw;
  final bool isDataSaver;

  MangaSearchDelegate({required this.isNsfw, required this.isDataSaver});

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme
          .copyWith(elevation: 0, backgroundColor: theme.colorScheme.surface),
      inputDecorationTheme: const InputDecorationTheme(
          border: InputBorder.none, hintStyle: TextStyle(fontSize: 16)),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null));
  }

  @override
  Widget buildResults(BuildContext context) => _buildSearchLogic(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchLogic(context);

  Widget _buildSearchLogic(BuildContext context) {
    if (query.length < 3)
      return Center(
          child: Text("Type at least 3 characters...",
              style: TextStyle(color: Theme.of(context).hintColor)));

    return FutureBuilder<List<dynamic>>(
      future: AniListService.fetchStandardList(
        query: AniListQueries.search,
        cacheKey: 'search_delegate_$query',
        forceRefresh: false,
        isNsfw: isNsfw,
        variables: {
          'search': query,
          'sort': ['SEARCH_MATCH'],
          'type': 'MANGA'
        },
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(child: Text("Error: ${snapshot.error}"));
        if (!snapshot.hasData || snapshot.data!.isEmpty)
          return const Center(child: Text("No manga found."));

        final results = snapshot.data!;
        final theme = Theme.of(context);

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: results.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = results[index];
            final title = item['title']['english'] ??
                item['title']['romaji'] ??
                'Unknown';
            final coverMap = item['coverImage'];
            final String cover = isDataSaver
                ? (coverMap['medium'] ?? coverMap['large'] ?? '')
                : (coverMap['large'] ?? coverMap['medium'] ?? '');
            final id = item['id'].toString();
            final year = item['year']?.toString() ?? '-';

            return InkWell(
              onTap: () => close(context,
                  TopPickItem(mangaId: id, title: title, coverUrl: cover)),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border:
                      Border.all(color: theme.dividerColor.withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 68,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: theme.dividerColor.withOpacity(0.1)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: CachedNetworkImage(
                          imageUrl: cover,
                          fit: BoxFit.cover,
                          memCacheHeight: isDataSaver ? 150 : 250,
                          errorWidget: (_, __, ___) =>
                              const Icon(Icons.broken_image, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(year,
                              style: TextStyle(
                                  color: theme.hintColor, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
