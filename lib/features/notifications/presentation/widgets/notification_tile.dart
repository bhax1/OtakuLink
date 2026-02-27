import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/core/models/user_model.dart';
import 'package:otakulink/services/user_service.dart';

class NotificationTile extends ConsumerWidget {
  final Map<String, dynamic> data;
  final void Function(String resolvedName) onTap;
  final VoidCallback onLongPress;
  final Widget? trailingButton;

  const NotificationTile({
    super.key,
    required this.data,
    required this.onTap,
    required this.onLongPress,
    this.trailingButton,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final bool isRead = data['isRead'] ?? false;
    final String senderId = data['senderId'] ?? '';
    final String message = data['message'] ?? '';
    final Timestamp? ts = data['timestamp'];
    final String type = data['type'] ?? 'unknown';
    final String? reactionEmoji = data['reactionEmoji'];

    IconData typeIcon = Icons.info;
    Color typeColor = Colors.grey;

    if (type == 'reply') {
      typeIcon = Icons.reply;
      typeColor = Colors.blue;
    } else if (type == 'mention') {
      typeIcon = Icons.alternate_email;
      typeColor = Colors.orange;
    } else if (type == 'reaction') {
      typeIcon = Icons.favorite;
      typeColor = Colors.pink;
    } else if (type == 'follow') {
      typeIcon = Icons.person_add;
      typeColor = Colors.blueAccent;
    } else if (type == 'friend_request') {
      typeIcon = Icons.people;
      typeColor = colorScheme.primary;
    }

    final Color tileColor =
        isRead ? Colors.transparent : colorScheme.primary.withOpacity(0.08);

    // Fetch dynamic profile via cache
    return FutureBuilder<UserModel?>(
        future: ref.read(userServiceProvider).getUserProfile(senderId),
        builder: (context, snapshot) {
          // Safety Fallbacks
          String senderName = 'Loading...';
          String photoUrl = '';

          if (snapshot.connectionState == ConnectionState.done) {
            // Strongly typed access! No more map keys.
            senderName = snapshot.data?.username ?? '[Deleted User]';
            photoUrl = snapshot.data?.avatarUrl ?? '';
          }

          return Material(
            color: tileColor,
            child: InkWell(
              onTap: () {
                if (snapshot.connectionState == ConnectionState.done) {
                  onTap(senderName);
                }
              },
              onLongPress: onLongPress,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                              ? Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    image: DecorationImage(
                                      image: NetworkImage(photoUrl),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                )
                              : Icon(Icons.person, color: theme.disabledColor),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                                color: colorScheme.surface,
                                shape: BoxShape.circle),
                            child: (type == 'reaction' && reactionEmoji != null)
                                ? Text(reactionEmoji,
                                    style: const TextStyle(fontSize: 12))
                                : Icon(typeIcon, size: 14, color: typeColor),
                          ),
                        )
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
                                        fontWeight: FontWeight.bold)),
                                TextSpan(text: message),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatTimestamp(ts),
                            style: textTheme.bodySmall
                                ?.copyWith(color: theme.disabledColor),
                          ),
                          if (trailingButton != null) ...[
                            const SizedBox(height: 8),
                            trailingButton!,
                          ]
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
                            color: colorScheme.primary, shape: BoxShape.circle),
                      ),
                  ],
                ),
              ),
            ),
          );
        });
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "Just now";
    final diff = DateTime.now().difference(timestamp.toDate());
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${diff.inDays}d ago";
  }
}
