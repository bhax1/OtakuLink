import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:otakulink/services/notification_service.dart'; // Adjust your import path

class FriendService {
  static final NotificationService _notificationService = NotificationService();

  static String _getFriendId(String userId, String friendId) {
    List<String> sortedIds = [userId, friendId]..sort();
    return 'friend_${sortedIds[0]}_${sortedIds[1]}';
  }

  static Stream<String> getFriendStatusStream(String userId, String? currentUserId) {
    if (currentUserId == null) return const Stream.empty();
    
    String friendId = _getFriendId(currentUserId, userId);
    return FirebaseFirestore.instance
        .collection('friends')
        .doc(friendId)
        .snapshots()
        .map((docSnapshot) {
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

  static Future<void> sendFriendRequest(String userId, String? currentUserId) async {
    if (currentUserId == null) return;
    try {
      String friendId = _getFriendId(currentUserId, userId);

      // 1. Get Sender Info
      DocumentSnapshot senderDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
      String senderUsername = senderDoc['username'] ?? 'Unknown';
      String? senderPhoto = senderDoc['photoURL'];

      // 2. Create Friend Doc
      await FirebaseFirestore.instance.collection('friends').doc(friendId).set({
        'user1Id': currentUserId,
        'user2Id': userId,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 3. Send Notification via Service
      await _notificationService.sendNotification(
        currentUserId: currentUserId,
        targetUserId: userId,
        type: 'friend_request',
        senderName: senderUsername,
        senderPhoto: senderPhoto,
        message: 'sent you a friend request.',
      );
    } catch (e) {
      print('Error sending friend request: $e');
    }
  }

  static Future<void> cancelRequest(String userId, String? currentUserId, String decision) async {
    if (currentUserId == null) return;
    try {
      String friendId = _getFriendId(currentUserId, userId);
      await FirebaseFirestore.instance.collection('friends').doc(friendId).delete();

      if (decision == 'cancelled') {
        // I cancelled my request to them -> Remove the notification I sent to THEM
        await _notificationService.removeFriendRequestNotification(
          senderId: currentUserId, 
        );
      } else if (decision == 'declined') {
        // I declined their request -> Update the notification THEY sent ME
        await _notificationService.updateFriendRequestStatus(
          targetUserId: currentUserId, // The notification is in MY notification collection
          senderId: userId, // THEY sent it
          newMessage: 'friend request declined.',
        );
      }
    } catch (e) {
      print('Error cancelling friend request: $e');
    }
  }

  static Future<void> acceptFriendRequest(String userId, String? currentUserId) async {
    if (currentUserId == null) return;
    try {
      String friendId = _getFriendId(currentUserId, userId);

      // 1. Update Friend Doc
      await FirebaseFirestore.instance.collection('friends').doc(friendId).update({
        'status': 'friends',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 2. Update Counts & Lists
      final batch = FirebaseFirestore.instance.batch();
      
      batch.update(FirebaseFirestore.instance.collection('users').doc(currentUserId), {
        'friendsCount': FieldValue.increment(1),
        'friends': FieldValue.arrayUnion([userId]),
      });
      
      batch.update(FirebaseFirestore.instance.collection('users').doc(userId), {
        'friendsCount': FieldValue.increment(1),
        'friends': FieldValue.arrayUnion([currentUserId]),
      });
      
      await batch.commit();

      // 3. Update the original request notification to say "is now your friend"
      await _notificationService.updateFriendRequestStatus(
        targetUserId: currentUserId,
        senderId: userId,
        newMessage: 'is now your friend.',
      );

      // 4. Send a NEW notification to the other person saying I accepted
      DocumentSnapshot myDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
      String myName = myDoc['username'] ?? 'Unknown';
      String? myPhoto = myDoc['photoURL'];

      await _notificationService.sendNotification(
        currentUserId: currentUserId,
        targetUserId: userId,
        type: 'friend_accept',
        senderName: myName,
        senderPhoto: myPhoto,
        message: 'accepted your friend request.',
      );

    } catch (e) {
      print('Error accepting friend request: $e');
    }
  }

  static Future<void> unfriend(String userId, String? currentUserId) async {
    if (currentUserId == null) return;
    try {
      String friendId = _getFriendId(currentUserId, userId);
      await FirebaseFirestore.instance.collection('friends').doc(friendId).delete();
      
      final batch = FirebaseFirestore.instance.batch();
      
      batch.update(FirebaseFirestore.instance.collection('users').doc(currentUserId), {
        'friendsCount': FieldValue.increment(-1),
        'friends': FieldValue.arrayRemove([userId]),
      });

      batch.update(FirebaseFirestore.instance.collection('users').doc(userId), {
        'friendsCount': FieldValue.increment(-1),
        'friends': FieldValue.arrayRemove([currentUserId]),
      });

      await batch.commit();
    } catch (e) {
      print('Error unfriending user: $e');
    }
  }
}