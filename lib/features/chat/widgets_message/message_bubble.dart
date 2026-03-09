import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class MessageBubble extends StatelessWidget {
  final String message;
  final bool isMine;
  final String? senderProfilePic;
  final String? senderName;
  final bool showAvatar;
  final bool isGroup;
  final String? replyToText;
  final String? replyToSenderName;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.senderProfilePic,
    this.senderName,
    required this.showAvatar,
    this.isGroup = false,
    this.replyToText,
    this.replyToSenderName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Using slightly muted colors rather than aggressive primary colors
    // helps readability for long reading sessions.
    final backgroundColor = isMine
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);

    final textColor = isMine
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;

    return Row(
      mainAxisAlignment: isMine
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isMine) ...[
          if (showAvatar)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(6), // Squared avatar
                image:
                    (senderProfilePic != null && senderProfilePic!.isNotEmpty)
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(senderProfilePic!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: (senderProfilePic == null || senderProfilePic!.isEmpty)
                  ? Center(
                      child: Text(
                        (senderName != null && senderName!.isNotEmpty)
                            ? senderName![0]
                            : '?',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    )
                  : null,
            )
          else
            const SizedBox(width: 32),
          const SizedBox(width: 12),
        ],
        Flexible(
          child: Column(
            crossAxisAlignment: isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (!isMine && isGroup && senderName != null && showAvatar)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Text(
                    senderName!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (replyToText != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        replyToSenderName ?? "User",
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        replyToText!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  border: Border.all(
                    color: isMine
                        ? theme.colorScheme.primary.withValues(alpha: 0.3)
                        : theme.dividerColor.withValues(alpha: 0.2),
                    width: 1,
                  ),
                  // Manga panels use sharper corners. Only slight rounding.
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(12),
                    topRight: const Radius.circular(12),
                    bottomLeft: isMine
                        ? const Radius.circular(12)
                        : const Radius.circular(4),
                    bottomRight: isMine
                        ? const Radius.circular(4)
                        : const Radius.circular(12),
                  ),
                ),
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    fontSize: 15,
                    height: 1.4, // Better line height for reading
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
