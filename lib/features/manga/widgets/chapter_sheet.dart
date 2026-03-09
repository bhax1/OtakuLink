import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/core/services/reading_history_service.dart';

class ChapterSheet extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> chapters;
  final Function(int index) onChapterTap;
  final String? lastReadId;

  const ChapterSheet({
    super.key,
    required this.chapters,
    required this.onChapterTap,
    this.lastReadId,
  });

  @override
  ConsumerState<ChapterSheet> createState() => _ChapterSheetState();
}

class _ChapterSheetState extends ConsumerState<ChapterSheet> {
  final Set<String> _readChapterIds = {};
  bool _isLoadingReads = true;
  bool _isDescending = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadReadStates());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReadStates() async {
    final historyService = ref.read(readingHistoryServiceProvider);
    final readIds = await historyService.getAllReadChapterIds();

    if (mounted) {
      setState(() {
        _readChapterIds.addAll(readIds);
        _isLoadingReads = false;
      });
    }
  }

  List<MapEntry<int, Map<String, dynamic>>> _getFilteredChapters() {
    // Keep track of original index using MapEntry
    Iterable<MapEntry<int, Map<String, dynamic>>> indexedChapters = widget
        .chapters
        .asMap()
        .entries;

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      indexedChapters = indexedChapters.where((entry) {
        final chNum = entry.value['chapter']?.toString().toLowerCase() ?? '';
        final title = entry.value['title']?.toString().toLowerCase() ?? '';
        return chNum.contains(_searchQuery.toLowerCase()) ||
            title.contains(_searchQuery.toLowerCase());
      });
    }

    // Sort
    final sortedList = indexedChapters.toList();
    if (_isDescending) {
      // MangaDex lists are usually ascending, so reverse for descending
      return sortedList.reversed.toList();
    }
    return sortedList;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredEntries = _getFilteredChapters();

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
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Chapters",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          setState(() => _isDescending = !_isDescending),
                      icon: Icon(
                        _isDescending ? Icons.sort_by_alpha : Icons.sort,
                        color: theme.colorScheme.primary,
                      ),
                      tooltip: _isDescending ? "Newest First" : "Oldest First",
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: "Search chapter number or title...",
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Powered by MangaDex",
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
                Text(
                  "${filteredEntries.length} Chapters",
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoadingReads
                ? const Center(child: CircularProgressIndicator())
                : filteredEntries.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: scrollController,
                    itemCount: filteredEntries.length,
                    itemBuilder: (ctx, i) {
                      final entry = filteredEntries[i];
                      final originalIndex = entry.key;
                      final ch = entry.value;

                      final String chapterId = ch['id'].toString();
                      final bool isRead = _readChapterIds.contains(chapterId);
                      final bool isCurrent = widget.lastReadId == chapterId;
                      // Latest is the one with the highest index in the original list
                      final bool isLatest =
                          originalIndex == widget.chapters.length - 1;

                      final rawChapter = ch['chapter'];
                      final chapterText =
                          (rawChapter != null &&
                              rawChapter.toString().trim().isNotEmpty &&
                              rawChapter.toString() != 'null')
                          ? rawChapter.toString()
                          : 'Oneshot';

                      return InkWell(
                        onTap: () => widget.onChapterTap(originalIndex),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? theme.colorScheme.primary.withOpacity(0.1)
                                : (isRead
                                      ? theme
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withOpacity(0.2)
                                      : Colors.transparent),
                            border: Border(
                              bottom: BorderSide(
                                color: theme.dividerColor.withOpacity(0.1),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? theme.colorScheme.primary
                                      : (isRead
                                            ? Colors.grey.withOpacity(0.5)
                                            : (isLatest
                                                  ? Colors.orange
                                                  : theme.colorScheme.primary
                                                        .withOpacity(0.3))),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          "Chapter $chapterText",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: isCurrent
                                                ? theme.colorScheme.primary
                                                : (isRead
                                                      ? Colors.grey
                                                      : theme
                                                            .textTheme
                                                            .bodyLarge
                                                            ?.color),
                                          ),
                                        ),
                                        if (isCurrent) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primary,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              "RESUME",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
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
                                isCurrent
                                    ? Icons.play_circle_fill
                                    : (isRead
                                          ? Icons.check_circle
                                          : Icons.play_circle_outline),
                                color: isCurrent
                                    ? theme.colorScheme.primary
                                    : (isRead
                                          ? Colors.green.withOpacity(0.5)
                                          : theme.colorScheme.primary
                                                .withOpacity(0.7)),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.menu_book,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? "No matching chapters."
                  : "No chapters available.",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? "Try searching for a different chapter number."
                  : "This usually happens if the manga only has official licensed releases, which are not hosted directly on MangaDex.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
