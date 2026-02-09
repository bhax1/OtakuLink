import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/anilist_service.dart';

// --- PERSONALIZED ---
final personalizedProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  // 1. Fetch user's high-rated manga (8+) from Firestore
  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('manga_ratings')
      .where('rating', isGreaterThanOrEqualTo: 8)
      .get();

  if (snapshot.docs.isEmpty) return null;

  // 2. Pick random favorite
  final randomIndex = Random().nextInt(snapshot.docs.length);
  final selectedDoc = snapshot.docs[randomIndex];
  final sourceMangaId = int.tryParse(selectedDoc.id);
  
  if (sourceMangaId == null) return null;

  String? sourceTitle = selectedDoc.data().containsKey('title') 
      ? selectedDoc.get('title') 
      : null;

  // 3. Call Service
  return AniListService.fetchRecommendations(sourceMangaId, sourceTitle);
});

// --- LISTS ---
final trendingMangaProvider = FutureProvider.family<List<dynamic>, bool>((ref, forceRefresh) async {
  return AniListService.fetchStandardList(
    query: AniListService.queryTrendingCarousel,
    cacheKey: 'anilist_trending_carousel',
    forceRefresh: forceRefresh,
  );
});

final newReleasesProvider = FutureProvider.family<List<dynamic>, bool>((ref, forceRefresh) async {
  int currentYear = DateTime.now().year;
  return AniListService.fetchStandardList(
    query: AniListService.queryNewReleases,
    cacheKey: 'anilist_new_season',
    forceRefresh: forceRefresh,
    variables: {'year': currentYear * 10000},
  );
});

final trendingListProvider = FutureProvider.family<List<dynamic>, bool>((ref, forceRefresh) async {
  return AniListService.fetchStandardList(
    query: AniListService.queryTrendingList,
    cacheKey: 'anilist_trending_list',
    forceRefresh: forceRefresh,
  );
});

final hallOfFameProvider = FutureProvider.family<List<dynamic>, bool>((ref, forceRefresh) async {
  return AniListService.fetchStandardList(
    query: AniListService.queryHallOfFame,
    cacheKey: 'anilist_hall_of_fame',
    forceRefresh: forceRefresh,
  );
});

final fanFavoritesProvider = FutureProvider.family<List<dynamic>, bool>((ref, forceRefresh) async {
  return AniListService.fetchStandardList(
    query: AniListService.queryFanFavorites,
    cacheKey: 'anilist_fan_favorites',
    forceRefresh: forceRefresh,
  );
});

final manhwaProvider = FutureProvider.family<List<dynamic>, bool>((ref, forceRefresh) async {
  return AniListService.fetchStandardList(
    query: AniListService.queryManhwa,
    cacheKey: 'anilist_manhwa',
    forceRefresh: forceRefresh,
  );
});