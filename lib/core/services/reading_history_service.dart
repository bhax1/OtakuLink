import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:otakulink/core/providers/shared_prefs_provider.dart';

class ReadingHistoryService {
  final SharedPreferences _prefs;
  static const String _keyPrefix = 'reading_history_';

  ReadingHistoryService(this._prefs);

  /// Get the resume point (last read chapter) for a specific manga
  Future<Map<String, dynamic>?> getResumePoint(String mangaId) async {
    final String? data = _prefs.getString('$_keyPrefix$mangaId');
    if (data == null) return null;
    return json.decode(data) as Map<String, dynamic>;
  }

  /// Save or update the resume point locally
  Future<void> saveResumePoint({
    required String mangaId,
    required String lastReadId,
    required String lastChapterNum,
  }) async {
    final Map<String, dynamic> data = {
      'lastReadId': lastReadId,
      'lastChapterNum': lastChapterNum,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await _prefs.setString('$_keyPrefix$mangaId', json.encode(data));
  }

  /// Get all read chapter IDs across all manga (used by ChapterSheet)
  Future<Set<String>> getAllReadChapterIds() async {
    final Set<String> allReadIds = {};
    final keys = _prefs.getKeys().where((k) => k.startsWith('read_chapters_'));
    for (final key in keys) {
      final List<String>? ids = _prefs.getStringList(key);
      if (ids != null) {
        allReadIds.addAll(ids);
      }
    }
    return allReadIds;
  }

  /// Mark chapters as read locally
  Future<void> markChaptersAsRead({
    required String mangaId,
    required List<String> chapterIds,
  }) async {
    final String key = 'read_chapters_$mangaId';
    final List<String> existing = _prefs.getStringList(key) ?? [];
    final Set<String> updated = {...existing, ...chapterIds};
    await _prefs.setStringList(key, updated.toList());
  }

  /// Mark a single chapter as read
  Future<void> markAsRead({
    required String chapterId,
    required String mangaId,
    required String title,
    required String image,
    required String chapterNum,
  }) async {
    await markChaptersAsRead(mangaId: mangaId, chapterIds: [chapterId]);
    await saveResumePoint(
      mangaId: mangaId,
      lastReadId: chapterId,
      lastChapterNum: chapterNum,
    );
  }

  /// Save the last read page for a chapter
  Future<void> savePageProgress(String chapterId, int pageIndex) async {
    await _prefs.setInt('page_progress_$chapterId', pageIndex);
  }

  /// Get the last read page for a chapter
  Future<int> getSavedPage(String chapterId) async {
    return _prefs.getInt('page_progress_$chapterId') ?? 0;
  }

  /// Save vertical scroll position for a chapter
  Future<void> saveVerticalProgress(String chapterId, double pixels) async {
    await _prefs.setDouble('vertical_progress_$chapterId', pixels);
  }

  /// Get vertical scroll position for a chapter
  Future<double> getSavedVerticalProgress(String chapterId) async {
    return _prefs.getDouble('vertical_progress_$chapterId') ?? 0.0;
  }

  /// Sync remote resume point into local storage (for logged in users)
  Future<void> syncMangaReadHistory({
    required String mangaId,
    String? remoteLastReadId,
    String? remoteLastChapterNum,
    int? remoteLastReadPage,
  }) async {
    if (remoteLastReadId != null && remoteLastChapterNum != null) {
      await saveResumePoint(
        mangaId: mangaId,
        lastReadId: remoteLastReadId,
        lastChapterNum: remoteLastChapterNum,
      );
      if (remoteLastReadPage != null) {
        await savePageProgress(remoteLastReadId, remoteLastReadPage);
      }
    }
  }
}

final readingHistoryServiceProvider = Provider<ReadingHistoryService>((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  return ReadingHistoryService(prefs);
});
