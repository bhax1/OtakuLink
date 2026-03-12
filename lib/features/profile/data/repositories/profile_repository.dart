import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:otakulink/core/providers/supabase_provider.dart';
import 'package:otakulink/core/utils/secure_logger.dart';
import 'package:otakulink/features/profile/domain/entities/profile_entities.dart';
import 'package:otakulink/features/profile/domain/repositories/profile_repository_interface.dart';

// --- RIVERPOD PROVIDERS ---
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(client: ref.watch(supabaseClientProvider));
});

final userProfileFutureProvider = FutureProvider.family<ProfileEntity?, String>(
  (ref, uid) async {
    if (uid.isEmpty || uid == 'system') return null;
    return ref.read(profileRepositoryProvider).getUserProfileById(uid);
  },
);

final userProfileStreamProvider = StreamProvider.family<ProfileEntity?, String>(
  (ref, uid) {
    if (uid.isEmpty || uid == 'system') return Stream.value(null);
    return ref.watch(profileRepositoryProvider).getUserProfileStream(uid);
  },
);

final recentActivityStreamProvider =
    StreamProvider.family<List<LibraryEntryEntity>, String>((ref, uid) {
      return ref.watch(profileRepositoryProvider).getRecentActivityStream(uid);
    });

// --- REPOSITORY ---
class ProfileRepository implements ProfileRepositoryInterface {
  final SupabaseClient _client;

  ProfileRepository({required SupabaseClient client}) : _client = client;

  @override
  String get currentUid {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception("No authenticated user found.");
    return uid;
  }

  @override
  Future<ProfileEntity?> getUserProfile() async {
    return getUserProfileById(currentUid);
  }

  @override
  Future<ProfileEntity?> getUserProfileById(String uid) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();

      if (response != null) {
        return _mapJsonToProfileEntity(response);
      }
      return null;
    } catch (e, stack) {
      SecureLogger.logError("ProfileRepository getUserProfileById", e, stack);
      throw Exception("Error fetching profile: $e");
    }
  }

  @override
  Future<void> updateUserProfile({
    required String displayName,
    required String bio,
    required String avatarUrl,
    required String bannerUrl,
  }) async {
    try {
      await _client
          .from('profiles')
          .update({
            'display_name': displayName,
            'bio': bio,
            'avatar_url': avatarUrl,
            'banner_url': bannerUrl,
          })
          .eq('id', currentUid);
    } catch (e, stack) {
      SecureLogger.logError("ProfileRepository updateUserProfile", e, stack);
      throw Exception("Failed to update profile: $e");
    }
  }

  @override
  Future<void> updateTopPicks(List<TopPickEntity> picks) async {
    try {
      final picksData = picks
          .map(
            (e) => {
              'mangaId': e.mangaId,
              'title': e.title,
              'coverUrl': e.coverUrl,
            },
          )
          .toList();

      await _client
          .from('profiles')
          .update({'top_picks': picksData})
          .eq('id', currentUid);
    } catch (e, stack) {
      SecureLogger.logError("ProfileRepository updateTopPicks", e, stack);
      throw Exception("Failed to update top picks: $e");
    }
  }

  @override
  Stream<ProfileEntity?> getUserProfileStream(String uid) {
    return _client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', uid)
        .map((docs) {
          if (docs.isNotEmpty) {
            return _mapJsonToProfileEntity(docs.first);
          }
          return null;
        });
  }

  @override
  Stream<List<LibraryEntryEntity>> getRecentActivityStream(String uid) {
    return _client
        .from('user_manga_list')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('updated_at')
        .limit(10)
        .asyncMap((event) async {
          if (event.isEmpty) return [];

          final mangaIds = event.map((e) => e['manga_id'] as int).toList();
          final mangaData = await _client
              .from('mangas')
              .select('id, title, cover_url')
              .inFilter('id', mangaIds);

          final mangaMap = {for (var m in mangaData) m['id'] as int: m};

          return event.map((e) {
            final mangaInfo = mangaMap[e['manga_id']];
            return LibraryEntryEntity(
              id: e['manga_id'].toString(),
              mangaId: e['manga_id'].toString(),
              title: mangaInfo?['title'] ?? 'Unknown',
              imageUrl: mangaInfo?['cover_url'],
              rating: (e['rating'] as num?)?.toDouble() ?? 0.0,
              isFavorite: e['is_favorite'] == true,
              status: e['status'] as String? ?? 'Reading',
              lastChapterRead:
                  (e['last_chapter_num'] as num?)?.toDouble() ?? 0.0,
              updatedAt: DateTime.parse(
                e['updated_at'] ?? DateTime.now().toIso8601String(),
              ),
            );
          }).toList();
        });
  }

  @override
  Stream<List<LibraryEntryEntity>> getLibraryStream({
    required String uid,
    String? status,
    bool favoritesOnly = false,
    String sortBy = 'updated_at',
    bool ascending = false,
    required int limit,
  }) {
    return _client
        .from('user_manga_list')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .asyncMap((event) async {
          var filtered = event.where((e) {
            if (status != null && e['status'] != status) return false;
            if (favoritesOnly && e['is_favorite'] != true) return false;
            return true;
          }).toList();

          if (filtered.isEmpty) return [];

          final mangaIds = filtered.map((e) => e['manga_id'] as int).toList();
          final mangaData = await _client
              .from('mangas')
              .select('id, title, cover_url')
              .inFilter('id', mangaIds);

          final mangaMap = {for (var m in mangaData) m['id'] as int: m};

          var results = filtered.map((e) {
            final mangaInfo = mangaMap[e['manga_id']];
            return LibraryEntryEntity(
              id: e['manga_id'].toString(),
              mangaId: e['manga_id'].toString(),
              title: mangaInfo?['title'] ?? 'Unknown',
              imageUrl: mangaInfo?['cover_url'],
              rating: (e['rating'] as num?)?.toDouble() ?? 0.0,
              isFavorite: e['is_favorite'] == true,
              status: e['status'] as String? ?? 'Reading',
              lastChapterRead:
                  (e['last_chapter_num'] as num?)?.toDouble() ?? 0.0,
              updatedAt: DateTime.parse(
                e['updated_at'] ?? DateTime.now().toIso8601String(),
              ),
            );
          }).toList();

          // Apply manual sorting since stream ordering is limited
          if (sortBy == 'Title') {
            results.sort((a, b) => a.title.compareTo(b.title));
          } else if (sortBy == 'Rating') {
            results.sort((a, b) => a.rating.compareTo(b.rating));
          } else {
            results.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
          }

          if (!ascending) {
            results = results.reversed.toList();
          }

          return results.take(limit).toList();
        });
  }

  @override
  Future<List<LibraryEntryEntity>> getLibrary({
    required String uid,
    String? status,
    bool favoritesOnly = false,
    String sortBy = 'updated_at',
    bool ascending = false,
    required int limit,
  }) async {
    try {
      var query = _client
          .from('user_manga_list')
          .select('*, mangas(id, title, cover_url)')
          .eq('user_id', uid);

      if (status != null) {
        query = query.eq('status', status);
      }

      if (favoritesOnly) {
        query = query.eq('is_favorite', true);
      }

      // Supabase sorting
      String dbSortField = 'updated_at';
      if (sortBy == 'Title') {
        // Unfortunately sorting by joined table column in Supabase is tricky via select
        // We might still need to sort in memory if sortBy is title
      } else if (sortBy == 'Rating') {
        dbSortField = 'rating';
      }

      final List data = await query
          .order(dbSortField, ascending: ascending)
          .limit(limit);

      if (data.isEmpty) {
        return [];
      }

      var results = data.map((e) {
        final mangaInfo = e['mangas'];
        return LibraryEntryEntity(
          id: e['id'].toString(),
          mangaId: e['manga_id'].toString(),
          title: mangaInfo != null
              ? mangaInfo['title'] ?? 'Unknown'
              : 'Unknown',
          imageUrl: mangaInfo != null ? mangaInfo['cover_url'] : null,
          rating: double.tryParse(e['rating']?.toString() ?? '0') ?? 0.0,
          isFavorite: e['is_favorite'] == true,
          status: e['status'] as String? ?? 'Reading',
          lastChapterRead:
              double.tryParse(e['last_chapter_num']?.toString() ?? '0') ?? 0.0,
          updatedAt: DateTime.parse(
            e['updated_at'] ?? DateTime.now().toIso8601String(),
          ),
        );
      }).toList();

      // Memory sort for Title if requested
      if (sortBy == 'Title') {
        results.sort((a, b) => a.title.compareTo(b.title));
        if (!ascending) results = results.reversed.toList();
      }

      return results;
    } catch (e, stack) {
      SecureLogger.logError("ProfileRepository.getLibrary", e, stack);
      return [];
    }
  }

  @override
  Stream<List<LibraryEntryEntity>> getReviewsStream(
    String uid, {
    required int limit,
  }) {
    return _client
        .from('user_manga_notes')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .asyncMap((event) async {
          var filtered = event
              .where(
                (e) =>
                    e['notes'] != null &&
                    e['notes'].toString().trim().isNotEmpty,
              )
              .toList();

          if (filtered.isEmpty) return [];

          final mangaIds = filtered.map((e) => e['manga_id'] as int).toList();
          final mangaData = await _client
              .from('mangas')
              .select('id, title, cover_url')
              .inFilter('id', mangaIds);

          final mangaMap = {for (var m in mangaData) m['id'] as int: m};

          // We also need the user_manga_list data for ratings and status
          final listData = await _client
              .from('user_manga_list')
              .select('manga_id, rating, status')
              .eq('user_id', uid)
              .inFilter('manga_id', mangaIds);

          final listMap = {for (var l in listData) l['manga_id'] as int: l};

          return filtered.map((e) {
            final mangaInfo = mangaMap[e['manga_id']];
            final libInfo = listMap[e['manga_id']];
            return LibraryEntryEntity(
              id: e['id'].toString(),
              mangaId: e['manga_id'].toString(),
              title: mangaInfo?['title'] ?? 'Review',
              imageUrl: mangaInfo?['cover_url'],
              rating:
                  double.tryParse(libInfo?['rating']?.toString() ?? '0') ?? 0.0,
              status: libInfo?['status'] as String? ?? 'Reading',
              updatedAt: DateTime.parse(
                e['updated_at'] ?? DateTime.now().toIso8601String(),
              ),
              commentary: e['notes'],
            );
          }).toList();
        });
  }

  @override
  Future<List<LibraryEntryEntity>> getReviews(
    String uid, {
    required int limit,
  }) async {
    try {
      // 1. Fetch reviews (notes) and manga metadata
      final notesResponse = await _client
          .from('user_manga_notes')
          .select('*, mangas(id, title, cover_url)')
          .eq('user_id', uid)
          .not('notes', 'is', null)
          .order('updated_at', ascending: false)
          .limit(limit);

      if ((notesResponse as List).isEmpty) return [];

      final List filtered = notesResponse as List;
      final mangaIds = filtered.map((e) => e['manga_id'] as int).toList();

      // 2. Fetch corresponding library stats (rating, status)
      final listData = await _client
          .from('user_manga_list')
          .select('manga_id, rating, status')
          .eq('user_id', uid)
          .inFilter('manga_id', mangaIds);

      final listMap = {for (var l in listData) l['manga_id'] as int: l};

      // 3. Combine in memory
      return filtered.map((e) {
        final mangaInfo = e['mangas'];
        final libInfo = listMap[e['manga_id']];
        return LibraryEntryEntity(
          id: e['id'].toString(),
          mangaId: e['manga_id'].toString(),
          title: mangaInfo?['title'] ?? 'Review',
          imageUrl: mangaInfo?['cover_url'],
          rating: double.tryParse(libInfo?['rating']?.toString() ?? '0') ?? 0.0,
          status: libInfo?['status'] as String? ?? 'Reading',
          updatedAt: DateTime.parse(
            e['updated_at'] ?? DateTime.now().toIso8601String(),
          ),
          commentary: e['notes'],
        );
      }).toList();
    } catch (e, stack) {
      SecureLogger.logError("ProfileRepository.getReviews", e, stack);
      return [];
    }
  }

  // --- MAPPERS ---
  ProfileEntity _mapJsonToProfileEntity(Map<String, dynamic> json) {
    return ProfileEntity(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? 'User',
      username: json['username'] as String? ?? 'user',
      bio: json['bio'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
      bannerUrl: json['banner_url'] as String? ?? '',
      followerCount: json['follower_count'] as int? ?? 0,
      followingCount: json['following_count'] as int? ?? 0,
      chaptersRead: json['chapters_read'] as int? ?? 0,
      completed: json['completed'] as int? ?? 0,
      reading: json['reading'] as int? ?? 0,
      dropped: json['dropped'] as int? ?? 0,
      onHold: json['on_hold'] as int? ?? 0,
      planned: json['planned'] as int? ?? 0,
      topGenres:
          (json['top_genres'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      topPicks:
          (json['top_picks'] as List<dynamic>?)?.map((p) {
            return TopPickEntity(
              mangaId: p['mangaId']?.toString() ?? '',
              title: p['title']?.toString() ?? '',
              coverUrl: p['coverUrl']?.toString() ?? '',
            );
          }).toList() ??
          [],
    );
  }
}
