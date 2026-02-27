import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> sendNotification({
    required String currentUserId,
    required String targetUserId,
    required String type,
    required String message,
    int? mangaId,
    String? mangaName,
    String? commentId,
    String? reactionEmoji,
  }) async {
    if (targetUserId == currentUserId) return;

    try {
      final data = {
        'type': type,
        'senderId': currentUserId,
        'message': message,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
        if (mangaId != null) 'mangaId': mangaId,
        if (mangaName != null) 'mangaName': mangaName,
        if (commentId != null) 'commentId': commentId,
        if (reactionEmoji != null) 'reactionEmoji': reactionEmoji,
      };

      final batch = _firestore.batch();
      final notifRef = _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('notification')
          .doc();

      final metaRef = _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('meta')
          .doc('notifications');

      batch.set(notifRef, data);
      batch.set(metaRef, {'unreadCount': FieldValue.increment(1)},
          SetOptions(merge: true));

      await batch.commit();
    } catch (e) {
      debugPrint("Error sending notification: $e");
    }
  }

  Future<void> processMentions({
    required String text,
    required String senderId,
    required String currentUserName,
    required int mangaId,
    required String mangaName,
    required String commentId,
    String? replyToUserName,
  }) async {
    final RegExp mentionRegex = RegExp(r"@(\w+)");
    final Iterable<Match> matches = mentionRegex.allMatches(text);
    if (matches.isEmpty) return;

    final Set<String> mentionedNames = matches.map((m) => m.group(1)!).toSet();

    mentionedNames.remove(currentUserName);
    if (replyToUserName != null) mentionedNames.remove(replyToUserName);

    if (mentionedNames.isEmpty) return;

    final namesList = mentionedNames.toList();

    for (var i = 0; i < namesList.length; i += 10) {
      final chunk = namesList.sublist(
          i, i + 10 > namesList.length ? namesList.length : i + 10);

      final userQuery = await _firestore
          .collection('users')
          .where('username', whereIn: chunk)
          .get();

      for (var doc in userQuery.docs) {
        sendNotification(
          currentUserId: senderId,
          targetUserId: doc.id,
          type: 'mention',
          mangaId: mangaId,
          mangaName: mangaName,
          commentId: commentId,
          message: 'mentioned you in $mangaName',
        ).catchError((e) => debugPrint("Mention notif error: $e"));
      }
    }
  }

  Future<void> removeFriendRequestNotification({
    required String targetUserId,
    required String senderId,
  }) async {
    try {
      final userRef = _firestore.collection('users').doc(targetUserId);
      final query = await userRef
          .collection('notification')
          .where('senderId', isEqualTo: senderId)
          .where('type', isEqualTo: 'friend_request')
          .get();

      if (query.docs.isEmpty) return;

      int unreadDeleted = 0;
      final batch = _firestore.batch();

      for (var doc in query.docs) {
        if (doc.data()['isRead'] == false) unreadDeleted++;
        batch.delete(doc.reference);
      }

      if (unreadDeleted > 0) {
        final metaRef = userRef.collection('meta').doc('notifications');
        // Using a transaction here in the future would prevent negative counts,
        // but this works for now.
        batch.set(
            metaRef,
            {'unreadCount': FieldValue.increment(-unreadDeleted)},
            SetOptions(merge: true));
      }

      await batch.commit();
    } catch (e) {
      debugPrint("Error deleting notification: $e");
    }
  }

  Future<void> updateFriendRequestStatus({
    required String targetUserId,
    required String senderId,
    required String newMessage,
  }) async {
    try {
      final userRef = _firestore.collection('users').doc(targetUserId);
      final query = await userRef
          .collection('notification')
          .where('senderId', isEqualTo: senderId)
          .where('type', isEqualTo: 'friend_request')
          .get();

      if (query.docs.isEmpty) return;

      int unreadMarkedRead = 0;
      final batch = _firestore.batch();

      for (var doc in query.docs) {
        if (doc.data()['isRead'] == false) unreadMarkedRead++;

        batch.update(doc.reference, {
          'message': newMessage,
          'isRead': true,
          'timestamp': FieldValue.serverTimestamp(),
          'edited': true,
        });
      }

      if (unreadMarkedRead > 0) {
        final metaRef = userRef.collection('meta').doc('notifications');
        batch.set(
            metaRef,
            {'unreadCount': FieldValue.increment(-unreadMarkedRead)},
            SetOptions(merge: true));
      }

      await batch.commit();
    } catch (e) {
      debugPrint("Error updating notification: $e");
    }
  }
}

// ✅ Provider definition
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
