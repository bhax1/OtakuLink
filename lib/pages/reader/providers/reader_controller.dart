import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/core/api/mangadex_service.dart';
import 'package:otakulink/core/cache/local_cache_service.dart';
import 'package:otakulink/services/reading_history_service.dart';
import 'reader_state.dart';

class ReaderController extends Notifier<ReaderState> {
  late List<Map<String, dynamic>> _allChapters;
  late String _mangaId;
  late String _mangaTitle;
  late String _mangaCover;

  @override
  ReaderState build() {
    return const ReaderState(
      currentIndex: 0,
      pages: AsyncValue.loading(),
    );
  }

  void init({
    required int initialIndex,
    required List<Map<String, dynamic>> allChapters,
    required String mangaId,
    required String mangaTitle,
    required String mangaCover,
  }) {
    _allChapters = allChapters;
    _mangaId = mangaId;
    _mangaTitle = mangaTitle;
    _mangaCover = mangaCover;

    loadChapter(initialIndex);
  }

  Future<void> loadChapter(int index) async {
    state = state.copyWith(
      currentIndex: index,
      pages: const AsyncValue.loading(),
      preloadedChapterIndex: null,
    );

    try {
      final chapterData = _allChapters[index];
      final chapterId = chapterData['id'].toString();
      final rawChapter = chapterData['chapter'];
      final chapterNum = (rawChapter != null &&
              rawChapter.toString().trim().isNotEmpty &&
              rawChapter.toString() != 'null')
          ? rawChapter.toString()
          : 'Oneshot';

      final historyService = ref.read(readingHistoryServiceProvider);

      historyService.markAsRead(
        chapterId: chapterId,
        mangaId: _mangaId,
        title: _mangaTitle,
        image: _mangaCover,
        chapterNum: chapterNum,
      );

      final progressFutures = await Future.wait([
        historyService.getSavedVerticalProgress(chapterId),
        historyService.getSavedPage(chapterId),
      ]);

      final pages = await MangaDexService.getChapterPages(chapterId);

      state = state.copyWith(
        pages: AsyncValue.data(pages),
        savedVerticalPixels: progressFutures[0] as double,
        savedHorizontalPage: progressFutures[1] as int,
      );

      if (pages.isNotEmpty) {
        preloadNextPages(0);
      }
    } catch (e, st) {
      state = state.copyWith(pages: AsyncValue.error(e, st));
    }
  }

  void preloadNextPages(int currentVisibleIndex) {
    if (!state.pages.hasValue) return;
    final pages = state.pages.value!;

    const int lookAhead = 3;

    for (int i = currentVisibleIndex + 1;
        i <= currentVisibleIndex + lookAhead && i < pages.length;
        i++) {
      final url = pages[i];
      LocalCacheService.pagesCache.downloadFile(
        url,
        key: url,
        authHeaders: const {
          'User-Agent': 'OtakuLink/1.0 (otakulink.dev@gmail.com)'
        },
      );
    }

    if (currentVisibleIndex >= pages.length - lookAhead) {
      _preloadNextChapter();
    }
  }

  Future<void> _preloadNextChapter() async {
    if (state.currentIndex >= _allChapters.length - 1) return;

    final nextChapterIndex = state.currentIndex + 1;

    if (state.isPreloadingNextChapter ||
        state.preloadedChapterIndex == nextChapterIndex) return;

    state = state.copyWith(isPreloadingNextChapter: true);

    try {
      final nextChapterId = _allChapters[nextChapterIndex]['id'].toString();
      final nextPages = await MangaDexService.getChapterPages(nextChapterId);

      if (nextPages.isEmpty) return;

      const int nextChapterLookAhead = 3;
      for (int i = 0; i < nextChapterLookAhead && i < nextPages.length; i++) {
        LocalCacheService.pagesCache.downloadFile(
          nextPages[i],
          key: nextPages[i],
          authHeaders: const {
            'User-Agent': 'OtakuLink/1.0 (otakulink.dev@gmail.com)'
          },
        );
      }

      state = state.copyWith(preloadedChapterIndex: nextChapterIndex);
    } catch (e) {
      // Silently fail
    } finally {
      state = state.copyWith(isPreloadingNextChapter: false);
    }
  }
}

final readerControllerProvider =
    NotifierProvider<ReaderController, ReaderState>(
  ReaderController.new,
  isAutoDispose: true,
);
