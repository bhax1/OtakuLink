import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;

  /// General method to send a notification
  Future<void> sendNotification({
    required String currentUserId,
    required String targetUserId,
    required String type,
    required String senderName,
    required String? senderPhoto,
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
        'senderName': senderName,
        'senderPhoto': senderPhoto,
        'message': message,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
        // Add optional fields only if they exist
        if (mangaId != null) 'mangaId': mangaId,
        if (mangaName != null) 'mangaName': mangaName,
        if (commentId != null) 'commentId': commentId,
        if (reactionEmoji != null) 'reactionEmoji': reactionEmoji,
      };

      await _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('notification')
          .add(data);
    } catch (e) {
      print("Error sending notification: $e");
    }
  }

  Future<void> processMentions({
    required String text,
    required String senderName,
    required String senderId,
    required String? senderPhoto,
    required int mangaId,
    required String mangaName,
    required String commentId,
    String? replyToUserName,
  }) async {
    final RegExp mentionRegex = RegExp(r"@(\w+)");
    final Iterable<Match> matches = mentionRegex.allMatches(text);
    if (matches.isEmpty) return;

    final Set<String> mentionedNames = matches.map((m) => m.group(1)!).toSet();

    for (String targetUserName in mentionedNames) {
      // Avoid double notification if already replying to them directly
      if (replyToUserName != null && targetUserName == replyToUserName) continue;
      if (targetUserName == senderName) continue;

      final userQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: targetUserName)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        final targetUserId = userQuery.docs.first.id;
        await sendNotification(
          currentUserId: senderId,
          targetUserId: targetUserId,
          type: 'mention',
          senderName: senderName,
          senderPhoto: senderPhoto,
          mangaId: mangaId,
          mangaName: mangaName,
          commentId: commentId,
          message: 'mentioned you in $mangaName',
        );
      }
    }
  }

  /// Helper: Cancel a pending friend request notification
  Future<void> removeFriendRequestNotification({
    required String senderId,
  }) async {
    try {
      final query = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('notification')
          .where('senderId', isEqualTo: senderId)
          .where('type', isEqualTo: 'friend_request')
          .get();

      for (var doc in query.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print("Error deleting notification: $e");
    }
  }

  /// Helper: Update a notification message (e.g., when Declined or Accepted)
  Future<void> updateFriendRequestStatus({
    required String targetUserId, // The person who HAS the notification
    required String senderId, // The person who SENT the notification
    required String newMessage,
  }) async {
    try {
      final query = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('notification')
          .where('senderId', isEqualTo: senderId)
          .where('type', isEqualTo: 'friend_request')
          .get();

      for (var doc in query.docs) {
        await doc.reference.update({
          'message': newMessage,
          'timestamp': FieldValue.serverTimestamp(),
          'edited': true,
        });
      }
    } catch (e) {
      print("Error updating notification: $e");
    }
  }
}