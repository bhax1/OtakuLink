import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/core/cache/local_cache_service.dart';
import 'user_list_service.dart';

class ReadingHistoryService {
  final FirebaseAuth _auth;
  final UserListService _userService;
  bool _isSyncing = false;
  Timer? _syncDebounceTimer;

  ReadingHistoryService({
    required FirebaseAuth auth,
    required UserListService userService,
  })  : _auth = auth,
        _userService = userService;

  Future<void> init() async {
    await LocalCacheService.getHistoryBox();
    syncOfflineReads();
  }

  Future<void> markAsRead({
    required String chapterId,
    required String mangaId,
    required String title,
    required String image,
    required String chapterNum,
  }) async {
    final box = await LocalCacheService.getHistoryBox();

    // Fetch existing data so we don't overwrite saved scroll/page progress
    final existingData = box.get(chapterId);
    final Map<String, dynamic> dataToSave =
        existingData is Map ? Map<String, dynamic>.from(existingData) : {};

    dataToSave.addAll({
      'mangaId': mangaId,
      'title': title,
      'imageUrl': image,
      'lastReadId': chapterId,
      'lastChapterNum': chapterNum,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'synced': false,
    });

    await box.put(chapterId, dataToSave);

    if (_syncDebounceTimer?.isActive ?? false) _syncDebounceTimer!.cancel();
    _syncDebounceTimer = Timer(const Duration(seconds: 3), () {
      syncOfflineReads();
    });
  }

  Future<void> syncOfflineReads() async {
    if (_isSyncing) return;

    final user = _auth.currentUser;
    if (user == null) return;

    final box = await LocalCacheService.getHistoryBox();
    _isSyncing = true;

    try {
      final keys = box.keys.toList();
      for (final key in keys) {
        final data = box.get(key);

        if (data is Map && data['synced'] == false) {
          try {
            await _userService.trackChapterRead(
              userId: user.uid,
              mangaId: data['mangaId'].toString(),
              chapterId: key.toString(),
              mangaTitle: data['title'].toString(),
              chapterNum: data['lastChapterNum'].toString(),
              imageUrl: data['imageUrl']?.toString(),
            );

            data['synced'] = true;
            await box.put(key, data);
          } catch (e) {
            print("OtakuLink Sync Error: $e");
            break;
          }
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> syncMangaReadHistory({
    required String mangaId,
    required List<String> readChapterIds,
    String? remoteLastReadId,
    String? remoteLastChapterNum,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final box = await LocalCacheService.getHistoryBox();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (String chapterId in readChapterIds) {
      if (!box.containsKey(chapterId)) {
        final isLastRead = chapterId == remoteLastReadId;

        await box.put(chapterId, {
          'mangaId': mangaId,
          'synced': true,
          'updatedAt': isLastRead ? now + 1000 : now,
          'lastReadId': isLastRead ? remoteLastReadId : chapterId,
          'lastChapterNum': isLastRead ? remoteLastChapterNum : null,
        });
      }
    }
  }

  Future<List<String>> getAllReadChapterIds() async {
    final box = await LocalCacheService.getHistoryBox();
    return box.keys.map((k) => k.toString()).toList();
  }

  Future<bool> isRead(String chapterId) async {
    final box = await LocalCacheService.getHistoryBox();
    return box.containsKey(chapterId);
  }

  Future<Map?> getResumePoint(String mangaId) async {
    final box = await LocalCacheService.getHistoryBox();

    final mangaReads = box.values
        .where((item) => item is Map && item['mangaId'] == mangaId)
        .toList();

    if (mangaReads.isEmpty) return null;

    mangaReads
        .sort((a, b) => (b['updatedAt'] ?? 0).compareTo(a['updatedAt'] ?? 0));
    return mangaReads.first as Map;
  }

  Future<void> savePageProgress(String chapterId, int pageIndex) async {
    final box = await LocalCacheService.getHistoryBox();
    final data = box.get(chapterId);

    if (data is Map) {
      data['lastReadPage'] = pageIndex;
      await box.put(chapterId, data);
    }
  }

  Future<int> getSavedPage(String chapterId) async {
    final box = await LocalCacheService.getHistoryBox();
    final data = box.get(chapterId);

    if (data is Map && data.containsKey('lastReadPage')) {
      return data['lastReadPage'] as int;
    }
    return 0;
  }

  Future<void> saveVerticalProgress(String chapterId, double pixels) async {
    final box = await LocalCacheService.getHistoryBox();
    final data = box.get(chapterId);

    if (data is Map) {
      data['lastReadPixels'] = pixels;
      await box.put(chapterId, data);
    }
  }

  Future<double> getSavedVerticalProgress(String chapterId) async {
    final box = await LocalCacheService.getHistoryBox();
    final data = box.get(chapterId);

    if (data is Map && data.containsKey('lastReadPixels')) {
      return (data['lastReadPixels'] as num).toDouble();
    }
    return 0.0;
  }
}

final readingHistoryServiceProvider = Provider<ReadingHistoryService>((ref) {
  return ReadingHistoryService(
    auth: FirebaseAuth.instance,
    userService: ref.watch(userListServiceProvider),
  );
});
