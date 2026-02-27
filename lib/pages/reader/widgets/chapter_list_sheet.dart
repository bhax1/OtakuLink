import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/core/cache/local_cache_service.dart';

class ChapterListSheet extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> chapters;
  final int currentIndex;
  final Function(int) onChapterTap;

  const ChapterListSheet({
    super.key,
    required this.chapters,
    required this.currentIndex,
    required this.onChapterTap,
  });

  @override
  ConsumerState<ChapterListSheet> createState() => _ChapterListSheetState();
}

class _ChapterListSheetState extends ConsumerState<ChapterListSheet> {
  final Set<String> _readChapterIds = {};
  bool _isLoadingReads = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadReadStates());
  }

  Future<void> _loadReadStates() async {
    final box = await LocalCacheService.getHistoryBox();
    if (mounted) {
      setState(() {
        _readChapterIds.addAll(box.keys.map((k) => k.toString()));
        _isLoadingReads = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("Select Chapter",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: _isLoadingReads
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    controller: controller,
                    itemCount: widget.chapters.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: Colors.white24, height: 1),
                    itemBuilder: (context, index) {
                      final ch = widget.chapters[index];
                      final isSelected = index == widget.currentIndex;
                      final isRead =
                          _readChapterIds.contains(ch['id'].toString());

                      return ListTile(
                        title: Text(
                          "Chapter ${ch['chapter']}",
                          style: TextStyle(
                            color: isSelected
                                ? Colors.orange
                                : (isRead ? Colors.grey : Colors.white),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          ch['title'] ?? '',
                          style: TextStyle(
                              color:
                                  isRead ? Colors.grey[700] : Colors.grey[400],
                              fontSize: 12),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: Colors.orange)
                            : null,
                        onTap: () => widget.onChapterTap(index),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
