import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/core/utils/secure_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:otakulink/features/auth/presentation/controllers/auth_controller.dart';
import 'package:otakulink/core/providers/supabase_provider.dart';
import 'package:otakulink/features/notifications/domain/notification_entity.dart';

class NotificationRepository {
  final SupabaseClient _client;
  final String? _userId;

  NotificationRepository(this._client, this._userId);

  Stream<List<NotificationEntity>> getNotificationsStream({
    required int limit,
  }) {
    if (_userId == null) return const Stream.empty();

    // Stream the table, but on every change, fetch the fully joined data.
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .limit(limit)
        .asyncMap((_) async {
          try {
            final response = await _client
                .from('notifications')
                .select(
                  '*, mangas(*), profiles!notifications_actor_id_fkey(*), discussions(*)',
                )
                .eq('user_id', _userId)
                .order('created_at', ascending: false)
                .limit(limit);

            return response.map((e) => NotificationEntity.fromJson(e)).toList();
          } catch (e, stack) {
            SecureLogger.logError(
              "NotificationRepository getNotificationsStream",
              e,
              stack,
            );
            return [];
          }
        });
  }

  Stream<int> getUnreadCountStream() {
    if (_userId == null) return Stream.value(0);

    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId)
        .map((data) => data.where((n) => n['is_read'] == false).length)
        .handleError((error) {
          SecureLogger.logError(
            "NotificationRepository getUnreadCountStream",
            error,
          );
          return 0;
        });
  }

  Future<void> markAsRead(String notificationId) async {
    if (_userId == null) return;
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId)
          .eq('user_id', _userId);
    } catch (e) {
      SecureLogger.logError("NotificationRepository markAsRead", e);
    }
  }

  Future<void> markAsUnread(String notificationId) async {
    if (_userId == null) return;
    try {
      await _client
          .from('notifications')
          .update({'is_read': false})
          .eq('id', notificationId)
          .eq('user_id', _userId);
    } catch (e) {
      SecureLogger.logError("NotificationRepository markAsUnread", e);
    }
  }

  Future<void> markAllAsRead() async {
    if (_userId == null) return;
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', _userId)
          .eq('is_read', false);
    } catch (e) {
      SecureLogger.logError("NotificationRepository markAllAsRead", e);
    }
  }

  Future<void> clearAllNotifications() async {
    if (_userId == null) return;
    try {
      await _client.from('notifications').delete().eq('user_id', _userId);
    } catch (e) {
      SecureLogger.logError("NotificationRepository clearAllNotifications", e);
    }
  }

  Future<void> deleteNotification(
    String notificationId, {
    bool wasUnread = false,
  }) async {
    if (_userId == null) return;
    try {
      await _client
          .from('notifications')
          .delete()
          .eq('id', notificationId)
          .eq('user_id', _userId);
    } catch (e) {
      SecureLogger.logError("NotificationRepository deleteNotification", e);
    }
  }
}

// Provide the repository
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final currentUserId = ref.watch(authControllerProvider).valueOrNull?.id;
  final client = ref.watch(supabaseClientProvider);
  return NotificationRepository(client, currentUserId);
});
