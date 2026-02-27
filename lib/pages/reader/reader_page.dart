import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/pages/reader/providers/reader_state.dart';
import 'package:otakulink/services/reading_history_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'providers/reading_mode_provider.dart';
import 'providers/reader_controller.dart';
import 'physics/webtoon_scroll_physics.dart';
import 'widgets/chapter_list_sheet.dart';
import 'widgets/reader_top_bar.dart';
import 'widgets/reader_bottom_bar.dart';
import 'widgets/reading_modes_modal.dart';
import 'widgets/volume_navigation_wrapper.dart';
import 'widgets/reader_image_item.dart';

class ReaderPage extends ConsumerStatefulWidget {
  final int initialChapterIndex;
  final List<Map<String, dynamic>> allChapters;
  final String mangaId;
  final String mangaTitle;
  final String mangaCover;

  const ReaderPage({
    super.key,
    required this.initialChapterIndex,
    required this.allChapters,
    required this.mangaId,
    required this.mangaTitle,
    required this.mangaCover,
  });

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  // State variables kept local to the UI
  int _currentPageIndex = 0;
  bool _hideUI = false;
  bool _isZoomedIn = false;

  // Controllers
  late PageController _pageController;
  late ScrollController _scrollController;
  late FocusNode _focusNode;

  final ValueNotifier<double> _progressNotifier = ValueNotifier(0.0);
  Timer? _debounceTimer;

  // Cache settings recovery
  late final int _originalCacheSize;
  late final int _originalCacheSizeBytes;

  @override
  void initState() {
    super.initState();
    _initServices();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(readerControllerProvider.notifier).init(
            initialIndex: widget.initialChapterIndex,
            allChapters: widget.allChapters,
            mangaId: widget.mangaId,
            mangaTitle: widget.mangaTitle,
            mangaCover: widget.mangaCover,
          );
    });
  }

  void _initServices() {
    WakelockPlus.enable();
    _focusNode = FocusNode();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _originalCacheSize = PaintingBinding.instance.imageCache.maximumSize;
    _originalCacheSizeBytes =
        PaintingBinding.instance.imageCache.maximumSizeBytes;
    PaintingBinding.instance.imageCache.maximumSize = 40;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 1024 * 1024 * 60;

    _pageController = PageController();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _cleanupServices();
    super.dispose();
  }

  void _cleanupServices() {
    _pageController.dispose();
    _scrollController.dispose();
    _progressNotifier.dispose();
    _debounceTimer?.cancel();
    _focusNode.dispose();

    WakelockPlus.disable();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    PaintingBinding.instance.imageCache.maximumSize = _originalCacheSize;
    PaintingBinding.instance.imageCache.maximumSizeBytes =
        _originalCacheSizeBytes;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _toggleUI() {
    setState(() => _hideUI = !_hideUI);
    SystemChrome.setEnabledSystemUIMode(
      _hideUI ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  void _handleScrollForward() {
    final currentMode = ref.read(readingModeProvider);

    if (currentMode == ReadingMode.vertical) {
      if (!_scrollController.hasClients) return;
      final scrollAmount = MediaQuery.of(context).size.height * 0.8;
      _scrollController.animateTo(
        (_scrollController.offset + scrollAmount)
            .clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      if (_pageController.hasClients) {
        _pageController.nextPage(
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    }
  }

  void _handleScrollBackward() {
    final currentMode = ref.read(readingModeProvider);

    if (currentMode == ReadingMode.vertical) {
      if (!_scrollController.hasClients) return;
      final scrollAmount = MediaQuery.of(context).size.height * 0.8;
      _scrollController.animateTo(
        (_scrollController.offset - scrollAmount)
            .clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      if (_pageController.hasClients) {
        _pageController.previousPage(
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    }
  }

  void _handleScreenTap(TapUpDetails details) {
    final currentMode = ref.read(readingModeProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final tapX = details.globalPosition.dx;
    final edgeMargin = screenWidth * 0.30;

    if (currentMode == ReadingMode.vertical) {
      _toggleUI();
      return;
    }

    if (tapX < edgeMargin) {
      currentMode == ReadingMode.horizontalLTR
          ? _handleScrollBackward()
          : _handleScrollForward();
    } else if (tapX > screenWidth - edgeMargin) {
      currentMode == ReadingMode.horizontalLTR
          ? _handleScrollForward()
          : _handleScrollBackward();
    } else {
      _toggleUI();
    }
  }

  void _showSettingsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (_) => const ReadingModesModal(),
    );
  }

  void _showChapterListModal(int currentIndex) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      builder: (context) => ChapterListSheet(
        chapters: widget.allChapters,
        currentIndex: currentIndex,
        onChapterTap: (index) {
          Navigator.pop(context);
          ref.read(readerControllerProvider.notifier).loadChapter(index);
        },
      ),
    );
  }

  Widget _buildVerticalList(List<String> pages) {
    // Removed the PostFrameCallback jump logic from here
    return InteractiveViewer(
      minScale: 1.0,
      maxScale: 4.0,
      panAxis: PanAxis.horizontal,
      panEnabled: true,
      scaleEnabled: true,
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          final pixels = scrollInfo.metrics.pixels;
          final maxScroll = scrollInfo.metrics.maxScrollExtent;

          if (maxScroll > 0) {
            _progressNotifier.value = (pixels / maxScroll).clamp(0.0, 1.0);
          }

          if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
          _debounceTimer = Timer(const Duration(milliseconds: 500), () {
            final currentState = ref.read(readerControllerProvider);
            final chapterId =
                widget.allChapters[currentState.currentIndex]['id'].toString();
            ref
                .read(readingHistoryServiceProvider)
                .saveVerticalProgress(chapterId, pixels);
          });

          return false;
        },
        child: ListView.builder(
          controller: _scrollController,
          physics: const WebtoonScrollPhysics(),
          itemCount: pages.length,
          cacheExtent: 1500.0,
          itemBuilder: (context, index) => ReaderImageItem(
            imageUrl: pages[index],
            mode: ReadingMode.vertical,
            onTapUp: _handleScreenTap,
          ),
        ),
      ),
    );
  }

  Widget _buildPageView(List<String> pages) {
    final currentMode = ref.watch(readingModeProvider);
    // Removed the PostFrameCallback jump logic from here

    return PageView.builder(
      controller: _pageController,
      allowImplicitScrolling: true,
      physics: _isZoomedIn
          ? const NeverScrollableScrollPhysics()
          : const PageScrollPhysics(),
      reverse: currentMode == ReadingMode.horizontalRTL,
      onPageChanged: (index) {
        ref.read(readerControllerProvider.notifier).preloadNextPages(index);
        setState(() => _currentPageIndex = index);

        final currentState = ref.read(readerControllerProvider);
        final chapterId =
            widget.allChapters[currentState.currentIndex]['id'].toString();
        ref
            .read(readingHistoryServiceProvider)
            .savePageProgress(chapterId, index);
      },
      itemCount: pages.length,
      itemBuilder: (context, index) => Center(
        child: ReaderImageItem(
          imageUrl: pages[index],
          mode: currentMode,
          onTapUp: _handleScreenTap,
          onZoomChanged: (isZoomed) {
            setState(() => _isZoomedIn = isZoomed);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final readerState = ref.watch(readerControllerProvider);
    final currentMode = ref.watch(readingModeProvider);
    final currentChapter = widget.allChapters[readerState.currentIndex];

    // NEW: Listen for when pages are loaded so we can jump exactly ONCE per chapter
    ref.listen<ReaderState>(readerControllerProvider, (previous, next) {
      final wasLoading = previous?.pages.isLoading ?? true;
      final isLoaded = next.pages.hasValue && !next.pages.isLoading;
      final chapterChanged = previous?.currentIndex != next.currentIndex;

      if ((wasLoading && isLoaded) || (chapterChanged && isLoaded)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Handle Horizontal Jump
          if (_pageController.hasClients) {
            _pageController.jumpToPage(next.savedHorizontalPage);
            if (mounted) {
              setState(() => _currentPageIndex = next.savedHorizontalPage);
            }
          }
          // Handle Vertical Jump
          if (_scrollController.hasClients && next.savedVerticalPixels > 0) {
            _scrollController.jumpTo(next.savedVerticalPixels);
          }
        });
      }
    });

    return VolumeNavigationWrapper(
      focusNode: _focusNode,
      onVolumeDown: _handleScrollForward,
      onVolumeUp: _handleScrollBackward,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 1. Content Layer
            readerState.pages.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: Colors.white)),
              error: (err, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.white, size: 40),
                    const SizedBox(height: 10),
                    const Text("Error loading pages.",
                        style: TextStyle(color: Colors.white)),
                    TextButton(
                      onPressed: () => ref
                          .read(readerControllerProvider.notifier)
                          .loadChapter(readerState.currentIndex),
                      child: const Text("Retry"),
                    )
                  ],
                ),
              ),
              data: (pages) {
                if (pages.isEmpty) {
                  return const Center(
                      child: Text("No pages found.",
                          style: TextStyle(color: Colors.white)));
                }
                // Notice we no longer pass the initialScroll/initialPage here
                return currentMode == ReadingMode.vertical
                    ? _buildVerticalList(pages)
                    : _buildPageView(pages);
              },
            ),

            // 2. Top Bar
            ReaderTopBar(
              isHidden: _hideUI,
              chapterName: currentChapter['chapter']?.toString() ?? 'Oneshot',
              chapterTitle: currentChapter['title'] ?? '',
              onSettingsTap: _showSettingsModal,
            ),

            // 3. Bottom Bar
            readerState.pages.maybeWhen(
              data: (pages) => ReaderBottomBar(
                isHidden: _hideUI,
                totalPages: pages.length,
                currentPageIndex: _currentPageIndex,
                progressNotifier: _progressNotifier,
                currentMode: currentMode,
                hasPreviousChapter: readerState.currentIndex > 0,
                hasNextChapter:
                    readerState.currentIndex < widget.allChapters.length - 1,
                onPreviousChapter: () => ref
                    .read(readerControllerProvider.notifier)
                    .loadChapter(readerState.currentIndex - 1),
                onNextChapter: () => ref
                    .read(readerControllerProvider.notifier)
                    .loadChapter(readerState.currentIndex + 1),
                onShowChapterList: () =>
                    _showChapterListModal(readerState.currentIndex),
                onSliderChanged: (val) {
                  if (currentMode == ReadingMode.vertical) {
                    if (_scrollController.hasClients) {
                      final max = _scrollController.position.maxScrollExtent;
                      _scrollController.jumpTo(val * max);
                    }
                  } else {
                    _pageController.jumpToPage(val.toInt());
                  }
                },
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
