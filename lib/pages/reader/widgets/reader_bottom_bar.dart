import 'package:flutter/material.dart';
import '../providers/reading_mode_provider.dart';

class ReaderBottomBar extends StatelessWidget {
  final bool isHidden;
  final int totalPages;
  final int currentPageIndex;
  final ValueNotifier<double> progressNotifier;
  final ReadingMode currentMode;
  final bool hasPreviousChapter;
  final bool hasNextChapter;
  final VoidCallback onPreviousChapter;
  final VoidCallback onNextChapter;
  final VoidCallback onShowChapterList;
  final ValueChanged<double> onSliderChanged;

  const ReaderBottomBar({
    super.key,
    required this.isHidden,
    required this.totalPages,
    required this.currentPageIndex,
    required this.progressNotifier,
    required this.currentMode,
    required this.hasPreviousChapter,
    required this.hasNextChapter,
    required this.onPreviousChapter,
    required this.onNextChapter,
    required this.onShowChapterList,
    required this.onSliderChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      bottom: isHidden ? -150 : 0,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.black.withOpacity(0.9),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (totalPages > 0)
                ValueListenableBuilder<double>(
                  valueListenable: progressNotifier,
                  builder: (context, verticalProgress, child) {
                    return Row(
                      children: [
                        Text(
                          currentMode == ReadingMode.vertical
                              ? "${(verticalProgress * 100).toInt()}%"
                              : "${currentPageIndex + 1}",
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                        Expanded(
                          child: Slider(
                            value: currentMode == ReadingMode.vertical
                                ? verticalProgress
                                : currentPageIndex.toDouble(),
                            min: 0,
                            max: currentMode == ReadingMode.vertical
                                ? 1.0
                                : (totalPages <= 1
                                    ? 1.0
                                    : (totalPages - 1).toDouble()),
                            divisions: currentMode == ReadingMode.vertical
                                ? 100
                                : (totalPages <= 1 ? 1 : totalPages - 1),
                            activeColor: Colors.orange,
                            inactiveColor: Colors.grey[700],
                            onChanged: onSliderChanged,
                          ),
                        ),
                        Text(
                          currentMode == ReadingMode.vertical
                              ? "100%"
                              : "$totalPages",
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    );
                  },
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous, color: Colors.white),
                    onPressed: hasPreviousChapter ? onPreviousChapter : null,
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.list),
                    label: const Text("Chapters"),
                    onPressed: onShowChapterList,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      foregroundColor: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, color: Colors.white),
                    onPressed: hasNextChapter ? onNextChapter : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
