import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MessageOptionsModal extends StatelessWidget {
  final bool isMine;
  final String messageText;
  final Function(String) onReaction;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const MessageOptionsModal({
    Key? key,
    required this.isMine,
    required this.messageText,
    required this.onReaction,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final List<String> emojis = ['👍', '❤️', '😂', '😮', '😢', '😡'];

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16), // Floating distinct block
          border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: emojis.map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      onReaction(emoji);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withOpacity(0.4),
                        borderRadius:
                            BorderRadius.circular(8), // Square reaction buttons
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                }).toList(),
              ),
            ),
            Divider(height: 1, color: theme.dividerColor.withOpacity(0.2)),
            if (isMine) ...[
              _buildActionTile(
                icon: Icons.edit_outlined,
                title: 'Edit Text',
                color: theme.colorScheme.onSurface,
                onTap: () {
                  Navigator.pop(context);
                  onEdit();
                },
              ),
            ],
            _buildActionTile(
              icon: Icons.copy_rounded,
              title: 'Copy to Clipboard',
              color: theme.colorScheme.onSurface,
              onTap: () {
                Clipboard.setData(ClipboardData(text: messageText));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Copied to clipboard"),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
            if (isMine) ...[
              Divider(height: 1, color: theme.dividerColor.withOpacity(0.2)),
              _buildActionTile(
                icon: Icons.delete_outline,
                title: 'Delete Panel',
                color: theme.colorScheme.error,
                onTap: () {
                  Navigator.pop(context);
                  onDelete();
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
