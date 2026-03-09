import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:otakulink/core/utils/app_snackbar.dart';

class MessageOptionsModal extends StatelessWidget {
  final bool isMine;
  final String messageText;
  final Function(String) onReaction;
  final VoidCallback onReply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const MessageOptionsModal({
    super.key,
    required this.isMine,
    required this.messageText,
    required this.onReaction,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
  });

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
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: emojis.map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      onReaction(emoji);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                }).toList(),
              ),
            ),
            Divider(
              height: 1,
              color: theme.dividerColor.withValues(alpha: 0.2),
            ),
            _buildActionTile(
              icon: Icons.reply_rounded,
              title: 'Reply',
              color: theme.colorScheme.onSurface,
              onTap: () {
                Navigator.pop(context);
                onReply();
              },
            ),
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
                AppSnackBar.show(
                  context,
                  "Copied to clipboard",
                  type: SnackBarType.success,
                );
              },
            ),
            if (isMine) ...[
              Divider(
                height: 1,
                color: theme.dividerColor.withValues(alpha: 0.2),
              ),
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
