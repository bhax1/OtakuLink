import 'package:flutter/material.dart';

class ReaderTopBar extends StatelessWidget {
  final bool isHidden;
  final String chapterName;
  final String chapterTitle;
  final VoidCallback onSettingsTap;
  final VoidCallback onDiscussionTap;

  const ReaderTopBar({
    super.key,
    required this.isHidden,
    required this.chapterName,
    required this.chapterTitle,
    required this.onSettingsTap,
    required this.onDiscussionTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      top: isHidden ? -100 : 0,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.black.withOpacity(0.9),
        padding: EdgeInsets.fromLTRB(
          10,
          MediaQuery.of(context).padding.top,
          10,
          10,
        ),
        child: Row(
          children: [
            const BackButton(color: Colors.white),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Chapter $chapterName",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    chapterTitle,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
              onPressed: onDiscussionTap,
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              onPressed: onSettingsTap,
            ),
          ],
        ),
      ),
    );
  }
}
