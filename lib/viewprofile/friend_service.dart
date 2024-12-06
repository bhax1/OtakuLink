import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

class FriendService {
  static Stream<String> getFriendStatusStream(
      String userId, String? currentUserId) {
    var sentByStream = FirebaseFirestore.instance
        .collection('friends')
        .where('user1Id', isEqualTo: currentUserId)
        .where('user2Id', isEqualTo: userId)
        .snapshots();

    var receivedByStream = FirebaseFirestore.instance
        .collection('friends')
        .where('user2Id', isEqualTo: currentUserId)
        .where('user1Id', isEqualTo: userId)
        .snapshots();

    return Rx.combineLatest2(sentByStream, receivedByStream,
        (QuerySnapshot sentBySnapshot, QuerySnapshot receivedBySnapshot) {
      var combinedDocs = [...sentBySnapshot.docs, ...receivedBySnapshot.docs];

      if (combinedDocs.isNotEmpty) {
        final data = combinedDocs.first.data() as Map<String, dynamic>;
        final status = data['status'] ?? 'none';
        final sentByCurrentUser = data['user1Id'] == currentUserId;
        if (status == 'pending' && sentByCurrentUser) {
          return 'sent';
        } else if (status == 'pending') {
          return 'received';
        } else {
          return status;
        }
      } else {
        return 'none';
      }
    });
  }

  static Future<void> sendFriendRequest(
      String userId, String? currentUserId) async {
    await FirebaseFirestore.instance.collection('friends').add({
      'user1Id': currentUserId,
      'user2Id': userId,
      'status': 'pending',
    });

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notification')
        .add({
      'senderId': currentUserId,
      'receiverId': userId,
      'message': 'New friend request from username.',
      'timestamp': FieldValue.serverTimestamp(),
      'edited': false,
      'isRead': false,
    });
  }

  static Future<void> cancelRequest(
      String userId, String? currentUserId, String decision) async {
    try {
      // Delete the friend request for both users
      final query1 = await FirebaseFirestore.instance
          .collection('friends')
          .where('user1Id', isEqualTo: currentUserId)
          .where('user2Id', isEqualTo: userId)
          .get();

      for (var doc in query1.docs) {
        await doc.reference.delete();
      }

      final query2 = await FirebaseFirestore.instance
          .collection('friends')
          .where('user1Id', isEqualTo: userId)
          .where('user2Id', isEqualTo: currentUserId)
          .get();

      for (var doc in query2.docs) {
        await doc.reference.delete();
      }

      if (decision == 'cancelled') {
        final notifQuery = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('notification')
            .where('senderId', isEqualTo: currentUserId)
            .where('receiverId', isEqualTo: userId)
            .get();

        for (var doc in notifQuery.docs) {
          await doc.reference.delete();
        }
      } else if (decision == 'declined') {
        final notifQuery = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('notification')
            .where('senderId', isEqualTo: userId)
            .where('receiverId', isEqualTo: currentUserId)
            .get();

        for (var doc in notifQuery.docs) {
          await doc.reference.update({
            'message': 'Declined friend request from username.',
            'timestamp': FieldValue.serverTimestamp(),
            'edited': true,
            'type': 'friend_request',
          });
        }
      }
    } catch (e) {
      print('Error cancelling friend request: $e');
    }
  }

  static Future<void> acceptFriendRequest(
      String userId, String? currentUserId) async {
    try {
      final query1 = await FirebaseFirestore.instance
          .collection('friends')
          .where('user2Id', isEqualTo: currentUserId)
          .where('user1Id', isEqualTo: userId)
          .get();

      for (var doc in query1.docs) {
        await doc.reference.update({
          'status': 'friends',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      final query2 = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('notification')
          .where('userId', isEqualTo: currentUserId)
          .where('senderId', isEqualTo: userId)
          .get();

      for (var doc in query2.docs) {
        await doc.reference.update({
          'message': 'Accepted friend request from username.',
          'timestamp': FieldValue.serverTimestamp(),
          'edited': true
        });
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .update({
        'friendsCount': FieldValue.increment(1),
      });

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'friendsCount': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error accepting friend request: $e');
    }
  }

  static Future<void> unfriend(String userId, String? currentUserId) async {
    // Implement unfriend logic
  }
}
