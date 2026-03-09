import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/anilist_queries.dart';
import '../../../../core/services/anilist_service.dart';
import '../../../settings/providers/settings_provider.dart';

enum CategoryType { newReleases, trending, manhwa, hallOfFame, favorites }

final trendingMangaProvider = FutureProvider<List<dynamic>>((ref) async {
  final isNsfw = ref.watch(settingsProvider).showAdultContent;
  return AniListService.fetchStandardList(
    query: AniListQueries.queryTrendingCarousel,
    cacheKey: 'anilist_trending_carousel',
    forceRefresh: false,
    isNsfw: isNsfw,
  );
});

final newReleasesProvider = FutureProvider<List<dynamic>>((ref) async {
  final isNsfw = ref.watch(settingsProvider).showAdultContent;
  final year = DateTime.now().year;
  return AniListService.fetchStandardList(
    query: AniListQueries.queryNewReleases,
    cacheKey: 'anilist_new_season',
    forceRefresh: false,
    isNsfw: isNsfw,
    variables: {'year': year * 10000},
  );
});

final trendingListProvider = FutureProvider<List<dynamic>>((ref) async {
  final isNsfw = ref.watch(settingsProvider).showAdultContent;
  return AniListService.fetchStandardList(
    query: AniListQueries.queryTrendingList,
    cacheKey: 'anilist_trending_list',
    forceRefresh: false,
    isNsfw: isNsfw,
  );
});

final manhwaProvider = FutureProvider<List<dynamic>>((ref) async {
  final isNsfw = ref.watch(settingsProvider).showAdultContent;
  return AniListService.fetchStandardList(
    query: AniListQueries.queryManhwa,
    cacheKey: 'anilist_manhwa',
    forceRefresh: false,
    isNsfw: isNsfw,
  );
});

final hallOfFameProvider = FutureProvider<List<dynamic>>((ref) async {
  final isNsfw = ref.watch(settingsProvider).showAdultContent;
  return AniListService.fetchStandardList(
    query: AniListQueries.queryHallOfFame,
    cacheKey: 'anilist_hall_of_fame',
    forceRefresh: false,
    isNsfw: isNsfw,
  );
});

final fanFavoritesProvider = FutureProvider<List<dynamic>>((ref) async {
  final isNsfw = ref.watch(settingsProvider).showAdultContent;
  return AniListService.fetchStandardList(
    query: AniListQueries.queryFanFavorites,
    cacheKey: 'anilist_fan_favorites',
    forceRefresh: false,
    isNsfw: isNsfw,
  );
});
