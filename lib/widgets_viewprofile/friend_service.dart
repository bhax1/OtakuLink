import 'package:cloud_firestore/cloud_firestore.dart';

class FriendService {
  static String _getFriendId(String userId, String friendId) {
    List<String> sortedIds = [userId, friendId]..sort();
    return 'friend_${sortedIds[0]}_${sortedIds[1]}';
  }

  static Stream<String> getFriendStatusStream(
      String userId, String? currentUserId) {
    String friendId = _getFriendId(currentUserId!, userId);
    var friendStatusStream = FirebaseFirestore.instance
        .collection('friends')
        .doc(friendId)
        .snapshots();

    return friendStatusStream.map((docSnapshot) {
      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        final status = data['status'] ?? 'none';
        if (status == 'pending' && data['user1Id'] == currentUserId) {
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
    try {
      String friendId = _getFriendId(currentUserId!, userId);

      // Retrieve the sender's username
      DocumentSnapshot senderDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      String senderUsername = senderDoc['username'] ?? 'Unknown';

      // Add the friend request to the 'friends' collection
      await FirebaseFirestore.instance.collection('friends').doc(friendId).set({
        'user1Id': currentUserId,
        'user2Id': userId,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Add the notification to the receiver's collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notification')
          .add({
        'senderId': currentUserId,
        'receiverId': userId,
        'message': 'New friend request from $senderUsername.',
        'timestamp': FieldValue.serverTimestamp(),
        'edited': false,
        'isRead': false,
        'type': 'friend_request',
      });
    } catch (e) {
      print('Error sending friend request: $e');
    }
  }

  static Future<void> cancelRequest(
      String userId, String? currentUserId, String decision) async {
    try {
      String friendId = _getFriendId(currentUserId!, userId);

      // Delete the friend request from the 'friends' collection
      await FirebaseFirestore.instance
          .collection('friends')
          .doc(friendId)
          .delete();

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
        DocumentSnapshot senderDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .get();
        String senderUsername = senderDoc['username'] ?? 'Unknown';

        final notifQuery = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('notification')
            .where('senderId', isEqualTo: userId)
            .where('receiverId', isEqualTo: currentUserId)
            .where('edited', isEqualTo: false)
            .where('type', isEqualTo: 'friend_request')
            .get();

        for (var doc in notifQuery.docs) {
          await doc.reference.update({
            'message': 'Declined friend request from $senderUsername.',
            'timestamp': FieldValue.serverTimestamp(),
            'edited': true,
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
      String friendId = _getFriendId(currentUserId!, userId);

      // Update the status to 'friends'
      await FirebaseFirestore.instance
          .collection('friends')
          .doc(friendId)
          .update({
        'status': 'friends',
        'timestamp': FieldValue.serverTimestamp(),
      });

      DocumentSnapshot senderDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      String senderUsername = senderDoc['username'] ?? 'Unknown';

      // Update notification
      final query = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('notification')
          .where('senderId', isEqualTo: userId)
          .where('receiverId', isEqualTo: currentUserId)
          .where('edited', isEqualTo: false)
          .where('type', isEqualTo: 'friend_request')
          .get();

      for (var doc in query.docs) {
        await doc.reference.update({
          'message': 'Accepted friend request from $senderUsername',
          'timestamp': FieldValue.serverTimestamp(),
          'edited': true
        });
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .update({
        'friendsCount': FieldValue.increment(1),
        'friends': FieldValue.arrayUnion([userId]),
      });

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'friendsCount': FieldValue.increment(1),
        'friends': FieldValue.arrayUnion([currentUserId]),
      });
    } catch (e) {
      print('Error accepting friend request: $e');
    }
  }

  static Future<void> unfriend(String userId, String? currentUserId) async {
    try {
      String friendId = _getFriendId(currentUserId!, userId);

      // Delete the friendship document
      await FirebaseFirestore.instance
          .collection('friends')
          .doc(friendId)
          .delete();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .update({
        'friendsCount': FieldValue.increment(-1),
        'friends': FieldValue.arrayRemove([userId]),
      });

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'friendsCount': FieldValue.increment(-1),
        'friends': FieldValue.arrayRemove([currentUserId]),
      });

    } catch (e) {
      print('Error unfriending user: $e');
    }
  }
}
