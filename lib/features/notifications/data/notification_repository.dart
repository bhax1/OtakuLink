import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/services/user_service.dart';

class NotificationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _userId;

  NotificationRepository(this._userId);

  Stream<QuerySnapshot> getNotificationsStream({required int limit}) {
    if (_userId == null) return const Stream.empty();
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('notification')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();
  }

  Stream<int> getUnreadCountStream() {
    if (_userId == null) return Stream.value(0);

    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('meta')
        .doc('notifications')
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return 0;
      final data = snapshot.data();
      final count = (data?['unreadCount'] as num?)?.toInt() ?? 0;
      // Safeguard: Never emit a negative number to the UI
      return count < 0 ? 0 : count;
    }).handleError((error) {
      debugPrint("Unread Count Stream Error: $error");
      return 0;
    });
  }

  Future<void> markAsRead(String notificationId) async {
    if (_userId == null) return;

    final userRef = _firestore.collection('users').doc(_userId);
    final notifRef = userRef.collection('notification').doc(notificationId);
    final metaRef = userRef.collection('meta').doc('notifications');

    // Run a transaction to ensure we don't decrement below 0
    await _firestore.runTransaction((transaction) async {
      final metaSnapshot = await transaction.get(metaRef);
      final currentCount =
          (metaSnapshot.data()?['unreadCount'] as num?)?.toInt() ?? 0;

      transaction.update(notifRef, {'isRead': true});

      final newCount = currentCount > 0 ? currentCount - 1 : 0;
      transaction.set(
          metaRef, {'unreadCount': newCount}, SetOptions(merge: true));
    });
  }

  Future<void> markAsUnread(String notificationId) async {
    if (_userId == null) return;

    final userRef = _firestore.collection('users').doc(_userId);
    final notifRef = userRef.collection('notification').doc(notificationId);
    final metaRef = userRef.collection('meta').doc('notifications');

    final batch = _firestore.batch();
    batch.update(notifRef, {'isRead': false});
    batch.set(metaRef, {'unreadCount': FieldValue.increment(1)},
        SetOptions(merge: true));

    await batch.commit();
  }

  Future<void> markAllAsRead() async {
    if (_userId == null) return;

    final userRef = _firestore.collection('users').doc(_userId);
    final metaRef = userRef.collection('meta').doc('notifications');

    final snapshots = await userRef
        .collection('notification')
        .where('isRead', isEqualTo: false)
        .get();

    if (snapshots.docs.isEmpty) return;

    await metaRef.set({'unreadCount': 0}, SetOptions(merge: true));

    await _processBatchInChunks(snapshots.docs,
        (batch, doc) => batch.update(doc.reference, {'isRead': true}));
  }

  Future<void> clearAllNotifications() async {
    if (_userId == null) return;

    final userRef = _firestore.collection('users').doc(_userId);
    final metaRef = userRef.collection('meta').doc('notifications');

    final snapshots = await userRef.collection('notification').get();

    if (snapshots.docs.isEmpty) return;

    await metaRef.set({'unreadCount': 0}, SetOptions(merge: true));

    await _processBatchInChunks(
        snapshots.docs, (batch, doc) => batch.delete(doc.reference));
  }

  Future<void> _processBatchInChunks(
    List<QueryDocumentSnapshot> docs,
    Function(WriteBatch, QueryDocumentSnapshot) action,
  ) async {
    const int batchLimit = 500;

    for (var i = 0; i < docs.length; i += batchLimit) {
      final batch = _firestore.batch();
      final end = (i + batchLimit < docs.length) ? i + batchLimit : docs.length;
      final chunk = docs.sublist(i, end);

      for (var doc in chunk) {
        action(batch, doc);
      }
      await batch.commit();
    }
  }

  Future<void> deleteNotification(String notificationId,
      {bool wasUnread = false}) async {
    if (_userId == null) return;

    final userRef = _firestore.collection('users').doc(_userId);
    final notifRef = userRef.collection('notification').doc(notificationId);
    final metaRef = userRef.collection('meta').doc('notifications');

    if (wasUnread) {
      // Use transaction to prevent negative count on delete
      await _firestore.runTransaction((transaction) async {
        final metaSnapshot = await transaction.get(metaRef);
        final currentCount =
            (metaSnapshot.data()?['unreadCount'] as num?)?.toInt() ?? 0;

        transaction.delete(notifRef);

        final newCount = currentCount > 0 ? currentCount - 1 : 0;
        transaction.set(
            metaRef, {'unreadCount': newCount}, SetOptions(merge: true));
      });
    } else {
      await notifRef.delete();
    }
  }
}

// ✅ Create a Provider for the repository
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final currentUserId = ref.watch(userServiceProvider).currentUserId;
  return NotificationRepository(currentUserId);
});
