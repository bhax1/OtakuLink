import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/audit_service.dart';
import '../../../../core/utils/secure_logger.dart';
import '../../data/notification_repository.dart';
import '../../domain/notification_entity.dart';

class NotificationController extends AsyncNotifier<List<NotificationEntity>> {
  int _currentLimit = 20;

  @override
  FutureOr<List<NotificationEntity>> build() {
    // Watch the repository so this controller rebuilds when the user changes
    ref.watch(notificationRepositoryProvider);
    return _fetchNotifications();
  }

  Future<List<NotificationEntity>> _fetchNotifications() async {
    final repo = ref.read(notificationRepositoryProvider);
    // We use a future-based fetch instead of a stream for the controller's core state
    // to allow for easy manual state manipulation (optimistic updates).
    // The repository stream can still be used if we wanted realtime,
    // but here we prioritize responsive UI actions.

    // Note: Since repository only has Stream, I'll use the stream's first value
    // or ideally I'd add a fetch method to repo.
    // For now, I will simulate the fetch using the repository's client directly if needed,
    // or just listen to the stream once.

    // Actually, let's look at the repository again.
    // getNotificationsStream uses asyncMap which is basically what we want.

    final stream = repo.getNotificationsStream(limit: _currentLimit);
    return await stream.first;
  }

  Future<void> loadMore() async {
    _currentLimit += 20;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchNotifications());
  }

  Future<void> deleteNotification(String id) async {
    final repo = ref.read(notificationRepositoryProvider);

    // Optimistic update
    final previousState = state;
    if (state.hasValue) {
      final newList = state.value!.where((n) => n.id != id).toList();
      state = AsyncValue.data(newList);
    }

    try {
      await repo.deleteNotification(id);
    } catch (e, stack) {
      // Rollback on failure
      state = previousState;
      SecureLogger.logError(
        'NotificationController.deleteNotification',
        e,
        stack,
      );
      rethrow;
    }
  }

  Future<void> markAsRead(String id) async {
    final repo = ref.read(notificationRepositoryProvider);

    // Optimistic update
    if (state.hasValue) {
      final newList = state.value!.map((n) {
        if (n.id == id) {
          return NotificationEntity(
            id: n.id,
            userId: n.userId,
            type: n.type,
            mangaId: n.mangaId,
            chapterId: n.chapterId,
            chapterNumber: n.chapterNumber,
            discussionId: n.discussionId,
            reactionEmoji: n.reactionEmoji,
            actorId: n.actorId,
            isRead: true,
            createdAt: n.createdAt,
            mangaTitle: n.mangaTitle,
            actorName: n.actorName,
            actorAvatar: n.actorAvatar,
            discussionContent: n.discussionContent,
          );
        }
        return n;
      }).toList();
      state = AsyncValue.data(newList);
    }

    try {
      await repo.markAsRead(id);
    } catch (e, stack) {
      SecureLogger.logError('NotificationController.markAsRead', e, stack);
    }
  }

  Future<void> markAllAsRead() async {
    final repo = ref.read(notificationRepositoryProvider);

    if (state.hasValue) {
      final newList = state.value!.map((n) {
        return NotificationEntity(
          id: n.id,
          userId: n.userId,
          type: n.type,
          mangaId: n.mangaId,
          chapterId: n.chapterId,
          chapterNumber: n.chapterNumber,
          discussionId: n.discussionId,
          reactionEmoji: n.reactionEmoji,
          actorId: n.actorId,
          isRead: true,
          createdAt: n.createdAt,
          mangaTitle: n.mangaTitle,
          actorName: n.actorName,
          actorAvatar: n.actorAvatar,
          discussionContent: n.discussionContent,
        );
      }).toList();
      state = AsyncValue.data(newList);
    }

    try {
      await repo.markAllAsRead();
    } catch (e, stack) {
      SecureLogger.logError('NotificationController.markAllAsRead', e, stack);
    }
  }

  Future<void> clearAll() async {
    final repo = ref.read(notificationRepositoryProvider);
    final previousState = state;

    state = const AsyncValue.data([]);

    try {
      await repo.clearAllNotifications();
      ref.read(auditServiceProvider).logAction(action: 'clear_notifications');
    } catch (e, stack) {
      state = previousState;
      SecureLogger.logError('NotificationController.clearAll', e, stack);
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchNotifications());
  }
}

final notificationControllerProvider =
    AsyncNotifierProvider<NotificationController, List<NotificationEntity>>(() {
      return NotificationController();
    });
