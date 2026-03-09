import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../controllers/notification_controller.dart';
import '../../domain/notification_entity.dart';
import '../widgets/notification_tile.dart';
import 'package:otakulink/features/auth/presentation/controllers/auth_controller.dart';
import 'package:otakulink/core/utils/app_snackbar.dart';

class NotificationPage extends ConsumerStatefulWidget {
  const NotificationPage({super.key});

  @override
  ConsumerState<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends ConsumerState<NotificationPage> {
  String? get _currentUserId =>
      ref.read(authControllerProvider).valueOrNull?.id;

  Future<void> _handleNotificationTap(NotificationEntity notification) async {
    if (!notification.isRead) {
      ref
          .read(notificationControllerProvider.notifier)
          .markAsRead(notification.id);
    }

    if (!mounted) return;

    if (notification.type == 'reply' ||
        notification.type == 'mention' ||
        notification.type == 'reaction') {
      final int? mangaId = notification.mangaId;
      final String? mangaTitle = notification.mangaTitle;
      final String? chapterId = notification.chapterId;
      final String? discussionId = notification.discussionId;

      if (mangaId != null && _currentUserId != null) {
        context.push(
          '/manga/$mangaId/discussion',
          extra: {
            'mangaId': mangaId,
            'mangaName': mangaTitle ?? 'Unknown Manga',
            'chapterId': chapterId,
            'highlightedCommentId': discussionId,
          },
        );
      }
    } else if (notification.type == 'new_chapter') {
      final int? mangaId = notification.mangaId;
      if (mangaId != null) {
        context.push('/manga/$mangaId', extra: {'mangaId': mangaId});
      }
    } else if (notification.type == 'follow') {
      final String? actorId = notification.actorId;
      final String? actorName = notification.actorName;
      if (actorId != null && actorName != null) {
        context.push('/profile/$actorName', extra: {'targetUserId': actorId});
      }
    }
  }

  void _showNotificationOptions(
    BuildContext context,
    NotificationEntity notification,
  ) {
    final bool isRead = notification.isRead;
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(
                  isRead ? Icons.mark_email_unread : Icons.mark_email_read,
                  color: colorScheme.primary,
                ),
                title: Text(isRead ? 'Mark as unread' : 'Mark as read'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  if (isRead) {
                    // Logic for unread might need adding to controller if desired
                    // For now keeping it simple as typical apps don't mark as unread often
                  } else {
                    ref
                        .read(notificationControllerProvider.notifier)
                        .markAsRead(notification.id);
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: colorScheme.error),
                title: Text(
                  'Delete notification',
                  style: TextStyle(color: colorScheme.error),
                ),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  ref
                      .read(notificationControllerProvider.notifier)
                      .deleteNotification(notification.id);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showMarkAllReadConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark all as read?'),
        content: const Text('This will mark all notifications as read.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(notificationControllerProvider.notifier).markAllAsRead();
      if (mounted) {
        AppSnackBar.show(
          context,
          'All marked as read.',
          type: SnackBarType.success,
        );
      }
    }
  }

  Future<void> _showClearConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Notifications?'),
        content: const Text(
          'This will permanently delete all your notifications.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete All',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(notificationControllerProvider.notifier).clearAll();
      if (mounted) {
        AppSnackBar.show(
          context,
          'Notifications cleared.',
          type: SnackBarType.success,
        );
      }
    }
  }

  Widget _buildLoadingSkeleton(ThemeData theme) {
    final baseColor = theme.colorScheme.onSurface.withOpacity(0.08);
    return ListView.builder(
      itemCount: 10,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: baseColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 14,
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 150,
                      height: 12,
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final notificationState = ref.watch(notificationControllerProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: colorScheme.primary,
        centerTitle: true,
        actions: [
          if (_currentUserId != null) ...[
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: "Mark all read",
              onPressed: _showMarkAllReadConfirmation,
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: "Clear all",
              onPressed: _showClearConfirmation,
            ),
          ],
        ],
      ),
      body: _currentUserId == null
          ? Center(
              child: Text(
                "Please login to view notifications",
                style: theme.textTheme.bodyLarge,
              ),
            )
          : notificationState.when(
              loading: () => _buildLoadingSkeleton(theme),
              error: (err, stack) => Center(child: Text("Error: $err")),
              data: (notifications) {
                if (notifications.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 60,
                          color: theme.disabledColor,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "No notifications yet",
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.disabledColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => ref
                      .read(notificationControllerProvider.notifier)
                      .refresh(),
                  child: ListView.separated(
                    itemCount: notifications.length + 1,
                    separatorBuilder: (ctx, i) =>
                        Divider(height: 1, color: Colors.grey[500]),
                    itemBuilder: (context, index) {
                      if (index == notifications.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: OutlinedButton(
                              onPressed: () => ref
                                  .read(notificationControllerProvider.notifier)
                                  .loadMore(),
                              child: const Text("Load More"),
                            ),
                          ),
                        );
                      }

                      final notification = notifications[index];
                      return NotificationTile(
                        notification: notification,
                        onTap: () => _handleNotificationTap(notification),
                        onLongPress: () =>
                            _showNotificationOptions(context, notification),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
