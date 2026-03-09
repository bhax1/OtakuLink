import 'package:flutter/material.dart';

class ReadActionButtons extends StatelessWidget {
  final Map? resumePoint;
  final VoidCallback onMainAction;
  final VoidCallback onOpenList;

  const ReadActionButtons({
    super.key,
    required this.resumePoint,
    required this.onMainAction,
    required this.onOpenList,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            icon:
                Icon(resumePoint == null ? Icons.play_arrow : Icons.menu_book),
            label: Text(
              resumePoint == null
                  ? 'START READING'
                  : 'CONTINUE CH ${resumePoint!['lastChapterNum']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.secondary,
              foregroundColor: theme.colorScheme.onSecondary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onMainAction,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 56,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: theme.colorScheme.secondary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onOpenList,
            child: Icon(
              Icons.list,
              color: theme.colorScheme.secondary,
            ),
          ),
        ),
      ],
    );
  }
}
