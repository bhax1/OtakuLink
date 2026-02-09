import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:otakulink/services/mangadex_service.dart';
import 'package:otakulink/services/reading_history_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart'; 

enum ReadingMode { vertical, horizontalLTR, horizontalRTL }

class ReaderPage extends StatefulWidget {
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
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  late int _currentIndex;
  late Future<List<String>> _pagesFuture;
  
  ReadingMode _mode = ReadingMode.vertical;
  bool _hideUI = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable(); // Keep screen on
    _currentIndex = widget.initialChapterIndex;
    _loadChapter(_currentIndex);
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  void _loadChapter(int index) {
    setState(() {
      _currentIndex = index;
      final chapterData = widget.allChapters[index];
      final chapterId = chapterData['id'].toString();
      final chapterNum = chapterData['chapter'].toString();

      ReadingHistoryService.markAsRead(
        chapterId: chapterId,
        mangaId: widget.mangaId,
        mangaTitle: widget.mangaTitle,
        coverUrl: widget.mangaCover,
        chapterNum: chapterNum,
      );

      _pagesFuture = MangaDexService.getChapterPages(chapterId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentChapter = widget.allChapters[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. CONTENT LAYER
          GestureDetector(
            onTap: () => setState(() => _hideUI = !_hideUI),
            child: FutureBuilder<List<String>>(
              future: _pagesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }
                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.white, size: 40),
                        const SizedBox(height: 10),
                        const Text("Error loading pages.", style: TextStyle(color: Colors.white)),
                        TextButton(
                          onPressed: () => _loadChapter(_currentIndex),
                          child: const Text("Retry"),
                        )
                      ],
                    )
                  );
                }

                final pages = snapshot.data!;
                
                if (_mode == ReadingMode.vertical) {
                  return _buildVerticalList(pages);
                } else {
                  return _buildPageView(pages);
                }
              },
            ),
          ),

          // 2. TOP BAR
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            top: _hideUI ? -100 : 0,
            left: 0, right: 0,
            child: Container(
              color: Colors.black.withOpacity(0.9),
              padding: EdgeInsets.fromLTRB(10, MediaQuery.of(context).padding.top, 10, 10),
              child: Row(
                children: [
                  const BackButton(color: Colors.white),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Chapter ${currentChapter['chapter']}",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          currentChapter['title'] ?? '',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white),
                    onPressed: _showSettingsModal,
                  ),
                ],
              ),
            ),
          ),

          // 3. BOTTOM BAR
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            bottom: _hideUI ? -120 : 0,
            left: 0, right: 0,
            child: Container(
              color: Colors.black.withOpacity(0.9),
              padding: const EdgeInsets.all(16),
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous, color: Colors.white),
                      onPressed: _currentIndex > 0 
                          ? () => _loadChapter(_currentIndex - 1) 
                          : null,
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.list),
                      label: const Text("Chapters"),
                      onPressed: _showChapterListModal,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        foregroundColor: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next, color: Colors.white),
                      onPressed: _currentIndex < widget.allChapters.length - 1 
                          ? () => _loadChapter(_currentIndex + 1) 
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalList(List<String> pages) {
    return ListView.builder(
      itemCount: pages.length,
      cacheExtent: 5000, // Preload lots of pages
      itemBuilder: (context, index) => _buildImage(pages[index]),
    );
  }

  Widget _buildPageView(List<String> pages) {
    return PageView.builder(
      reverse: _mode == ReadingMode.horizontalRTL, 
      itemCount: pages.length,
      itemBuilder: (context, index) => Center(child: _buildImage(pages[index])),
    );
  }

  Widget _buildImage(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      httpHeaders: const {'User-Agent': 'OtakuLink/1.0 (dev@otakulink.app)'},
      fit: BoxFit.fitWidth,
      placeholder: (context, url) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Center(child: CircularProgressIndicator(color: Colors.grey[800]))
      ),
      errorWidget: (context, url, error) => const SizedBox(
        height: 300, 
        child: Center(child: Icon(Icons.broken_image, color: Colors.grey))
      ),
    );
  }

  void _showSettingsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text("Reading Mode", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  _buildSettingOption(
                    title: "Long Strip (Webtoon)",
                    icon: Icons.view_day,
                    isSelected: _mode == ReadingMode.vertical,
                    onTap: () {
                      setModalState(() => _mode = ReadingMode.vertical);
                      setState(() {});
                      Navigator.pop(context);
                    },
                  ),
                  _buildSettingOption(
                    title: "Left to Right (Comic)",
                    icon: Icons.arrow_forward,
                    isSelected: _mode == ReadingMode.horizontalLTR,
                    onTap: () {
                      setModalState(() => _mode = ReadingMode.horizontalLTR);
                      setState(() {});
                      Navigator.pop(context);
                    },
                  ),
                  _buildSettingOption(
                    title: "Right to Left (Manga)",
                    icon: Icons.arrow_back,
                    isSelected: _mode == ReadingMode.horizontalRTL,
                    onTap: () {
                      setModalState(() => _mode = ReadingMode.horizontalRTL);
                      setState(() {});
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  void _showChapterListModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Column(
          children: [
             const Padding(
               padding: EdgeInsets.all(16.0),
               child: Text("Select Chapter", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
             ),
             Expanded(
               child: ListView.separated(
                 controller: controller,
                 itemCount: widget.allChapters.length,
                 separatorBuilder: (_,__) => const Divider(color: Colors.white24, height: 1),
                 itemBuilder: (context, index) {
                   final ch = widget.allChapters[index];
                   final isSelected = index == _currentIndex;
                   final isRead = ReadingHistoryService.isRead(ch['id'].toString());

                   return ListTile(
                     title: Text(
                       "Chapter ${ch['chapter']}", 
                        style: TextStyle(
                          // Current: Orange, Read: Grey, Unread: White
                          color: isSelected ? Colors.orange : (isRead ? Colors.grey : Colors.white), 
                          fontWeight: FontWeight.bold
                        )
                     ),
                     subtitle: Text(
                       ch['title'] ?? '', 
                       style: TextStyle(color: isRead ? Colors.grey[700] : Colors.grey[400], fontSize: 12)
                     ),
                     trailing: isSelected ? const Icon(Icons.check, color: Colors.orange) : null,
                     onTap: () {
                       Navigator.pop(context); 
                       _loadChapter(index); 
                     },
                   );
                 },
               ),
             ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingOption({required String title, required IconData icon, required bool isSelected, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.orange : Colors.white),
      title: Text(title, style: TextStyle(color: isSelected ? Colors.orange : Colors.white)),
      trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.orange) : null,
      onTap: onTap,
    );
  }
}