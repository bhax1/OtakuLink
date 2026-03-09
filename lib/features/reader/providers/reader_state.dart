import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReaderState {
  final int currentIndex;
  final AsyncValue<List<String>> pages;
  final double savedVerticalPixels;
  final int savedHorizontalPage;

  const ReaderState({
    required this.currentIndex,
    required this.pages,
    this.savedVerticalPixels = 0.0,
    this.savedHorizontalPage = 0,
  });

  ReaderState copyWith({
    int? currentIndex,
    AsyncValue<List<String>>? pages,
    double? savedVerticalPixels,
    int? savedHorizontalPage,
  }) {
    return ReaderState(
      currentIndex: currentIndex ?? this.currentIndex,
      pages: pages ?? this.pages,
      savedVerticalPixels: savedVerticalPixels ?? this.savedVerticalPixels,
      savedHorizontalPage: savedHorizontalPage ?? this.savedHorizontalPage,
    );
  }
}
