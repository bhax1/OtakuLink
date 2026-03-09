import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:otakulink/features/chat/domain/entities/chat_room_entity.dart';
import 'package:otakulink/features/profile/data/repositories/profile_repository.dart';

class ChatPanelCard extends ConsumerWidget {
  final ChatRoomEntity chat;

  const ChatPanelCard({super.key, required this.chat});

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return "";
    final date = timestamp;
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0 && now.day == date.day) {
      return DateFormat('h:mm a').format(date);
    } else if (diff.inDays < 7) {
      return DateFormat('E').format(date);
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentUid = Supabase.instance.client.auth.currentUser?.id ?? '';

    final lastMessageText = chat.lastMessageText ?? '';
    final lastSenderId = chat.lastMessageSenderId ?? '';
    final timestamp = chat.updatedAt;

    final isMe = lastSenderId == currentUid;
    final unreadCount = chat.unreadCounts[currentUid] ?? 0;
    final isUnread = unreadCount > 0;

    String targetFetchId = chat.isGroup
        ? lastSenderId
        : chat.participants.firstWhere(
            (id) => id != currentUid,
            orElse: () => currentUid,
          );

    final userAsyncValue = ref.watch(userProfileFutureProvider(targetFetchId));

    return userAsyncValue.when(
      loading: () => const SizedBox(height: 72),
      error: (err, stack) => const SizedBox.shrink(),
      data: (targetUser) {
        String displayTitle = "Unknown User";
        String? displayPhotoUrl;

        if (chat.isGroup) {
          displayTitle = chat.groupName ?? 'Group Chat';
          displayPhotoUrl = chat.groupIconUrl;
        } else {
          displayTitle = targetUser?.username ?? 'Unknown User';
          displayPhotoUrl = targetUser?.avatarUrl;
        }

        String displayMessage = lastMessageText;
        if (lastSenderId == 'system') {
          displayMessage = lastMessageText;
        } else if (isMe) {
          displayMessage = "You: $lastMessageText";
        } else if (chat.isGroup && targetUser != null) {
          final shortName = targetUser.username.split(' ').first;
          displayMessage = "$shortName: $lastMessageText";
        }

        return InkWell(
          onTap: () {
            context.push(
              '/message/${chat.id}',
              extra: <String, dynamic>{
                'title': displayTitle,
                'profilePic': displayPhotoUrl ?? '',
                'isGroup': chat.isGroup,
              },
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isUnread
                  ? theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    )
                  : theme.colorScheme.surface,
              border: Border.all(
                color: isUnread
                    ? theme.colorScheme.primary.withValues(alpha: 0.5)
                    : theme.dividerColor.withValues(alpha: 0.2),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    image: DecorationImage(
                      image:
                          (displayPhotoUrl != null &&
                              displayPhotoUrl.isNotEmpty)
                          ? NetworkImage(displayPhotoUrl)
                          : const AssetImage('assets/pic/default_avatar.png')
                                as ImageProvider,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: isUnread
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTimestamp(timestamp),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isUnread
                                  ? theme.colorScheme.primary
                                  : theme.hintColor,
                              fontWeight: isUnread
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isUnread
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.onSurfaceVariant,
                                fontWeight: isUnread
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (isUnread)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                unreadCount.toString(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
