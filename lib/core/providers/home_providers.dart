import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/core/api/anilist_queries.dart';
import 'package:otakulink/core/api/anilist_service.dart';
import 'package:otakulink/core/providers/settings_provider.dart';

final authUserProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// --- LISTS (No .family modifier) ---
final trendingMangaProvider = FutureProvider<List<dynamic>>((ref) async {
  // Synchronously watch the memory cache
  final isNsfw = ref.watch(settingsProvider).value?.isNsfw ?? false;
  return AniListService.fetchStandardList(
    query: AniListQueries.queryTrendingCarousel,
    cacheKey: 'anilist_trending_carousel',
    forceRefresh: false,
    isNsfw: isNsfw,
  );
});

final newReleasesProvider = FutureProvider<List<dynamic>>((ref) async {
  final isNsfw = ref.watch(settingsProvider).value?.isNsfw ?? false;
  int currentYear = DateTime.now().year;

  return AniListService.fetchStandardList(
    query: AniListQueries.queryNewReleases,
    cacheKey: 'anilist_new_season',
    forceRefresh: false,
    isNsfw: isNsfw,
    variables: {'year': currentYear * 10000},
  );
});

final trendingListProvider = FutureProvider<List<dynamic>>((ref) async {
  final isNsfw = ref.watch(settingsProvider).value?.isNsfw ?? false;
  return AniListService.fetchStandardList(
    query: AniListQueries.queryTrendingList,
    cacheKey: 'anilist_trending_list',
    forceRefresh: false,
    isNsfw: isNsfw,
  );
});

final hallOfFameProvider = FutureProvider<List<dynamic>>((ref) async {
  final isNsfw = ref.watch(settingsProvider).value?.isNsfw ?? false;
  return AniListService.fetchStandardList(
    query: AniListQueries.queryHallOfFame,
    cacheKey: 'anilist_hall_of_fame',
    forceRefresh: false,
    isNsfw: isNsfw,
  );
});

final fanFavoritesProvider = FutureProvider<List<dynamic>>((ref) async {
  final isNsfw = ref.watch(settingsProvider).value?.isNsfw ?? false;
  return AniListService.fetchStandardList(
    query: AniListQueries.queryFanFavorites,
    cacheKey: 'anilist_fan_favorites',
    forceRefresh: false,
    isNsfw: isNsfw,
  );
});

final manhwaProvider = FutureProvider<List<dynamic>>((ref) async {
  final isNsfw = ref.watch(settingsProvider).value?.isNsfw ?? false;
  return AniListService.fetchStandardList(
    query: AniListQueries.queryManhwa,
    cacheKey: 'anilist_manhwa',
    forceRefresh: false,
    isNsfw: isNsfw,
  );
});
