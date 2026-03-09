import 'package:flutter/material.dart';
import 'package:otakulink/features/notifications/domain/notification_entity.dart';

class NotificationTile extends StatelessWidget {
  final NotificationEntity notification;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Widget? trailingButton;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onLongPress,
    this.trailingButton,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final bool isRead = notification.isRead;
    final String type = notification.type;

    String senderName = 'System';
    String message = '';
    IconData typeIcon = Icons.info;
    Color typeColor = Colors.grey;
    String photoUrl = '';

    final String? mangaTitle = notification.mangaTitle;
    final String? chapterNumber = notification.chapterNumber;
    final String targetInfo = mangaTitle != null
        ? (chapterNumber != null
              ? " on $mangaTitle – Chapter $chapterNumber"
              : " on $mangaTitle")
        : "";

    if (type == 'reply') {
      senderName = notification.actorName ?? '[Deleted User]';
      message = 'replied to your comment$targetInfo.';
      photoUrl = notification.actorAvatar ?? '';
      typeIcon = Icons.reply;
      typeColor = Colors.blue;
    } else if (type == 'new_chapter') {
      senderName = 'Chapter Update';
      message =
          'A new chapter of ${mangaTitle ?? 'a manga'}${chapterNumber != null ? " (Chapter $chapterNumber)" : ""} is out!';
      photoUrl = '';
      typeIcon = Icons.menu_book;
      typeColor = Colors.orange;
    } else if (type == 'mention') {
      senderName = notification.actorName ?? '[Deleted User]';
      message = 'mentioned you$targetInfo.';
      photoUrl = notification.actorAvatar ?? '';
      typeIcon = Icons.alternate_email;
      typeColor = Colors.purple;
    } else if (type == 'reaction') {
      senderName = notification.actorName ?? '[Deleted User]';
      message = 'reacted to your comment$targetInfo.';
      photoUrl = notification.actorAvatar ?? '';
      typeIcon = Icons.favorite;
      typeColor = Colors.red;
    } else if (type == 'follow') {
      senderName = notification.actorName ?? '[Deleted User]';
      message = 'started following you.';
      photoUrl = notification.actorAvatar ?? '';
      typeIcon = Icons.person_add;
      typeColor = Colors.green;
    }

    final Color tileColor = isRead
        ? Colors.transparent
        : colorScheme.primary.withOpacity(0.08);

    return Material(
      color: tileColor,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Avatar ---
              Stack(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.disabledColor.withOpacity(0.2),
                    ),
                    child: photoUrl.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, _, __) => Icon(
                                Icons.person,
                                color: theme.disabledColor,
                              ),
                            ),
                          )
                        : Icon(
                            type == 'new_chapter'
                                ? Icons.menu_book
                                : Icons.person,
                            color: theme.disabledColor,
                          ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        shape: BoxShape.circle,
                      ),
                      child:
                          type == 'reaction' &&
                              notification.reactionEmoji != null
                          ? Text(
                              notification.reactionEmoji!,
                              style: const TextStyle(fontSize: 12),
                            )
                          : Icon(typeIcon, size: 14, color: typeColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // --- Content ---
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: textTheme.bodyMedium,
                        children: [
                          TextSpan(
                            text: "$senderName ",
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(text: message),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTimestamp(notification.createdAt),
                      style: textTheme.bodySmall?.copyWith(
                        color: theme.disabledColor,
                      ),
                    ),
                    if (trailingButton != null) ...[
                      const SizedBox(height: 8),
                      trailingButton!,
                    ],
                  ],
                ),
              ),
              // --- Unread Dot ---
              if (!isRead)
                Container(
                  margin: const EdgeInsets.only(left: 8, top: 8),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${diff.inDays}d ago";
  }
}
