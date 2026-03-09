import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/core/providers/supabase_provider.dart';
import 'package:otakulink/core/services/reading_history_service.dart';
import 'package:otakulink/core/utils/secure_logger.dart';
import 'package:otakulink/features/reader/data/repositories/reader_repository.dart';
import 'reader_state.dart';

class ReaderController extends AutoDisposeNotifier<ReaderState> {
  late List<Map<String, dynamic>> _allChapters;
  late String _mangaId;
  late String _mangaTitle;
  late String _mangaCover;

  @override
  ReaderState build() {
    return const ReaderState(currentIndex: 0, pages: AsyncValue.loading());
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
    );

    try {
      final chapterData = _allChapters[index];
      final chapterId = chapterData['id'].toString();
      final rawChapter = chapterData['chapter'];
      final chapterNum =
          (rawChapter != null &&
              rawChapter.toString().trim().isNotEmpty &&
              rawChapter.toString() != 'null')
          ? rawChapter.toString()
          : 'Oneshot';

      final historyService = ref.read(readingHistoryServiceProvider);
      final repository = ref.read(readerRepositoryProvider);

      // Local save
      historyService.markAsRead(
        chapterId: chapterId,
        mangaId: _mangaId,
        title: _mangaTitle,
        image: _mangaCover,
        chapterNum: chapterNum,
      );

      // Supabase sync if logged in
      final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
      if (userId != null) {
        repository.syncProgress(
          userId: userId,
          mangaId: _mangaId,
          chapterId: chapterId,
          chapterNum: chapterNum,
        );
      }

      final progressFutures = await Future.wait([
        historyService.getSavedVerticalProgress(chapterId),
        historyService.getSavedPage(chapterId),
      ]);

      final pages = await repository.fetchChapterPages(chapterId);

      state = state.copyWith(
        pages: AsyncValue.data(pages),
        savedVerticalPixels: progressFutures[0] as double,
        savedHorizontalPage: progressFutures[1] as int,
      );
    } catch (e, st) {
      SecureLogger.logError("ReaderController loadChapter", e, st);
      state = state.copyWith(pages: AsyncValue.error(e, st));
    }
  }

  void saveProgress({int? pageIndex, double? verticalPixels}) {
    final currentState = state;
    if (!currentState.pages.hasValue) return;

    final chapterData = _allChapters[currentState.currentIndex];
    final chapterId = chapterData['id'].toString();
    final rawChapter = chapterData['chapter'];
    final chapterNum = (rawChapter != null && rawChapter.toString().isNotEmpty)
        ? rawChapter.toString()
        : 'Oneshot';

    final historyService = ref.read(readingHistoryServiceProvider);

    if (pageIndex != null) {
      historyService.savePageProgress(chapterId, pageIndex);
    }
    if (verticalPixels != null) {
      historyService.saveVerticalProgress(chapterId, verticalPixels);
    }

    // Sync to Supabase if logged in
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId != null) {
      ref
          .read(readerRepositoryProvider)
          .syncProgress(
            userId: userId,
            mangaId: _mangaId,
            chapterId: chapterId,
            chapterNum: chapterNum,
            pageIndex: pageIndex,
          );
    }
  }
}

final readerControllerProvider =
    NotifierProvider.autoDispose<ReaderController, ReaderState>(
      ReaderController.new,
    );
