import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class MessageBubble extends StatelessWidget {
  final String message;
  final bool isMine;
  final String friendProfilePic;
  final String friendName;
  final bool showAvatar;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMine,
    required this.friendProfilePic,
    required this.friendName,
    required this.showAvatar,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Using slightly muted colors rather than aggressive primary colors
    // helps readability for long reading sessions.
    final backgroundColor = isMine
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5);

    final textColor = isMine
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;

    return Row(
      mainAxisAlignment:
          isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
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
                image: friendProfilePic.isNotEmpty
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(friendProfilePic),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: friendProfilePic.isEmpty
                  ? Center(
                      child: Text(
                        friendName.isNotEmpty ? friendName[0] : '?',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface),
                      ),
                    )
                  : null,
            )
          else
            const SizedBox(width: 32),
          const SizedBox(width: 12),
        ],
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border.all(
                color: isMine
                    ? theme.colorScheme.primary.withOpacity(0.3)
                    : theme.dividerColor.withOpacity(0.2),
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
        ),
      ],
    );
  }
}
