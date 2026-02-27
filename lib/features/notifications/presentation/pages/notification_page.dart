import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:otakulink/features/notifications/data/notification_repository.dart';
import 'package:otakulink/features/notifications/presentation/widgets/notification_tile.dart';
import 'package:otakulink/pages/profile/profile_widgets/follow_button.dart';
import 'package:otakulink/services/user_service.dart';

class NotificationPage extends ConsumerStatefulWidget {
  const NotificationPage({super.key});

  @override
  ConsumerState<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends ConsumerState<NotificationPage> {
  NotificationRepository get _repository =>
      ref.watch(notificationRepositoryProvider);

  String? get _currentUserId => ref.read(userServiceProvider).currentUserId;

  final ScrollController _scrollController = ScrollController();
  int _currentLimit = 20;
  int _currentDocumentCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_currentDocumentCount >= _currentLimit) {
        setState(() {
          _currentLimit += 20;
        });
      }
    }
  }

  Future<void> _handleNotificationTap(
      DocumentSnapshot doc, String resolvedSenderName) async {
    final data = doc.data() as Map<String, dynamic>;

    if (data['isRead'] == false) {
      await _repository.markAsRead(doc.id);
    }

    if (!mounted) return;

    final String type = data['type'] ?? '';

    if (['reply', 'mention', 'reaction'].contains(type)) {
      final int? mangaId = data['mangaId'];
      final String? mangaName = data['mangaName'];
      final String? commentId = data['commentId'];

      if (mangaId != null && _currentUserId != null) {
        context.push('/manga/$mangaId/discussion', extra: {
          'mangaId': mangaId,
          'mangaName': mangaName,
          // ✅ Passing your actual ID retrieved from the service
          'userId': _currentUserId,
          'commentId': commentId,
        });
      }
    } else if (type == 'follow') {
      final String? senderId = data['senderId'];

      if (senderId != null) {
        context.push(
          '/profile/$resolvedSenderName',
          extra: {'targetUserId': senderId},
        );
      }
    }
  }

  void _showNotificationOptions(BuildContext context, DocumentSnapshot doc) {
    // ... [Unchanged from your previous code]
    final data = doc.data() as Map<String, dynamic>;
    final bool isRead = data['isRead'] ?? false;
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
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
                    borderRadius: BorderRadius.circular(2)),
              ),
              ListTile(
                leading: Icon(
                    isRead ? Icons.mark_email_unread : Icons.mark_email_read,
                    color: colorScheme.primary),
                title: Text(isRead ? 'Mark as unread' : 'Mark as read'),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  if (isRead) {
                    _repository.markAsUnread(doc.id);
                  } else {
                    _repository.markAsRead(doc.id);
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: colorScheme.error),
                title: Text('Delete notification',
                    style: TextStyle(color: colorScheme.error)),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _repository.deleteNotification(doc.id, wasUnread: !isRead);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showClearConfirmation() async {
    // ... [Unchanged from your previous code]
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Notifications?'),
        content:
            const Text('This will permanently delete all your notifications.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Delete All',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error))),
        ],
      ),
    );
    if (confirmed == true) {
      await _repository.clearAllNotifications();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notifications cleared.')));
      }
    }
  }

  Widget _buildLoadingSkeleton(ThemeData theme) {
    // ... [Unchanged from your previous code]
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
                decoration:
                    BoxDecoration(color: baseColor, shape: BoxShape.circle),
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: colorScheme.primary,
        centerTitle: true,
        actions: [
          if (_currentUserId != null) ...[
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: "Mark all read",
              onPressed: () async {
                await _repository.markAllAsRead();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('All marked as read.')));
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: "Clear all",
              onPressed: _showClearConfirmation,
            ),
          ]
        ],
      ),
      body: _currentUserId == null
          ? Center(
              child: Text("Please login to view notifications",
                  style: theme.textTheme.bodyLarge))
          : StreamBuilder<QuerySnapshot>(
              stream: _repository.getNotificationsStream(limit: _currentLimit),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return _buildLoadingSkeleton(theme);
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined,
                            size: 60, color: theme.disabledColor),
                        const SizedBox(height: 10),
                        Text("No notifications yet",
                            style: theme.textTheme.bodyLarge
                                ?.copyWith(color: theme.disabledColor)),
                      ],
                    ),
                  );
                }

                _currentDocumentCount = snapshot.data!.docs.length;

                return ListView.separated(
                  controller: _scrollController,
                  itemCount: snapshot.data!.docs.length,
                  separatorBuilder: (ctx, i) =>
                      Divider(height: 1, color: Colors.grey[500]),
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final String type = data['type'] ?? '';
                    final String? senderId = data['senderId'];

                    Widget? trailing;
                    if (type == 'follow' && senderId != null) {
                      trailing = FollowButton(targetUserId: senderId);
                    }

                    return NotificationTile(
                      data: data,
                      onTap: (resolvedName) =>
                          _handleNotificationTap(doc, resolvedName),
                      onLongPress: () => _showNotificationOptions(context, doc),
                      trailingButton: trailing,
                    );
                  },
                );
              },
            ),
    );
  }
}
