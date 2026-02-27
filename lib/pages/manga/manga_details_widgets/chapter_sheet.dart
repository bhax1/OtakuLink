import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // ADD THIS
import 'package:otakulink/services/reading_history_service.dart'; // Ensure this points to your provider file

// Convert to ConsumerStatefulWidget
class ChapterSheet extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> chapters;
  final Function(int index) onChapterTap;

  const ChapterSheet({
    Key? key,
    required this.chapters,
    required this.onChapterTap,
  }) : super(key: key);

  @override
  ConsumerState<ChapterSheet> createState() => _ChapterSheetState();
}

class _ChapterSheetState extends ConsumerState<ChapterSheet> {
  final Set<String> _readChapterIds = {};
  bool _isLoadingReads = true;

  @override
  void initState() {
    super.initState();
    // Wrap in microtask to safely read the provider during init
    Future.microtask(() => _loadReadStates());
  }

  // Fetch all read IDs using the Riverpod Service
  Future<void> _loadReadStates() async {
    final historyService = ref.read(readingHistoryServiceProvider);

    // We added a new helper method to the service below to make this clean!
    final readIds = await historyService.getAllReadChapterIds();

    if (mounted) {
      setState(() {
        _readChapterIds.addAll(readIds);
        _isLoadingReads = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, scrollController) => Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Chapters",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            color: Colors.grey[100],
            child: const Text(
              "Powered by MangaDex",
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoadingReads
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: scrollController,
                    itemCount: widget.chapters.length,
                    itemBuilder: (ctx, i) {
                      final ch = widget.chapters[i];

                      // Performant O(1) synchronous check against the Set
                      final bool isRead =
                          _readChapterIds.contains(ch['id'].toString());

                      final bool isLatest = i == widget.chapters.length - 1;

                      final rawChapter = ch['chapter'];
                      final chapterText = (rawChapter != null &&
                              rawChapter.toString().trim().isNotEmpty &&
                              rawChapter.toString() != 'null')
                          ? rawChapter.toString()
                          : 'Oneshot';

                      return InkWell(
                        onTap: () => widget.onChapterTap(i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isRead
                                ? Colors.grey.withOpacity(0.05)
                                : Colors.transparent,
                            border: Border(
                                bottom:
                                    BorderSide(color: Colors.grey.shade200)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isRead
                                      ? Colors.grey
                                      : (isLatest
                                          ? Colors.orange
                                          : Colors.blueAccent),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Chapter $chapterText",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isRead
                                            ? Colors.grey
                                            : Theme.of(context)
                                                .textTheme
                                                .bodyLarge
                                                ?.color,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${ch['group']}${ch['title'] != null && ch['title'].isNotEmpty ? ' • ${ch['title']}' : ''}",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isRead
                                            ? Colors.grey[400]
                                            : Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                isRead
                                    ? Icons.check_circle
                                    : Icons.play_circle_outline,
                                color: isRead
                                    ? Colors.green[300]
                                    : Colors.blueAccent,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
