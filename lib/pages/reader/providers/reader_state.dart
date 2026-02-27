import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReaderState {
  final int currentIndex;
  final AsyncValue<List<String>> pages;
  final bool isPreloadingNextChapter;
  final int? preloadedChapterIndex;
  final double savedVerticalPixels;
  final int savedHorizontalPage;

  const ReaderState({
    required this.currentIndex,
    required this.pages,
    this.isPreloadingNextChapter = false,
    this.preloadedChapterIndex,
    this.savedVerticalPixels = 0.0,
    this.savedHorizontalPage = 0,
  });

  ReaderState copyWith({
    int? currentIndex,
    AsyncValue<List<String>>? pages,
    bool? isPreloadingNextChapter,
    int? preloadedChapterIndex,
    double? savedVerticalPixels,
    int? savedHorizontalPage,
  }) {
    return ReaderState(
      currentIndex: currentIndex ?? this.currentIndex,
      pages: pages ?? this.pages,
      isPreloadingNextChapter:
          isPreloadingNextChapter ?? this.isPreloadingNextChapter,
      preloadedChapterIndex:
          preloadedChapterIndex ?? this.preloadedChapterIndex,
      savedVerticalPixels: savedVerticalPixels ?? this.savedVerticalPixels,
      savedHorizontalPage: savedHorizontalPage ?? this.savedHorizontalPage,
    );
  }
}
