import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:otakulink/services/notification_service.dart'; // Adjust your import path

class FollowService {
  static final NotificationService _notificationService = NotificationService();

  static Stream<String> getFollowStatusStream(String? currentUserId, String targetUserId) {
    return FirebaseFirestore.instance
        .collection('follows')
        .doc('follow_${currentUserId}_$targetUserId')
        .snapshots()
        .map((snapshot) => snapshot.exists ? 'following' : 'not_following');
  }

  static Future<void> followUser(String? followerId, String followedId) async {
    if (followerId == null) return;
    final timestamp = FieldValue.serverTimestamp();

    // 1. Create Follow Document
    await FirebaseFirestore.instance
        .collection('follows')
        .doc('follow_${followerId}_$followedId')
        .set({
      'followerId': followerId,
      'followedId': followedId,
      'timestamp': timestamp,
    });

    // 2. Add to 'following' subcollection
    await FirebaseFirestore.instance
        .collection('users')
        .doc(followerId)
        .collection('following')
        .doc('following_$followedId')
        .set({'followedId': followedId, 'timestamp': timestamp});

    // 3. Add to 'followers' subcollection
    await FirebaseFirestore.instance
        .collection('users')
        .doc(followedId)
        .collection('followers')
        .doc('follower_$followerId')
        .set({'followerId': followerId, 'timestamp': timestamp});

    // 4. Increment Count
    await FirebaseFirestore.instance.collection('users').doc(followedId).update({
      'followersCount': FieldValue.increment(1),
    });

    // 5. Send Notification via Service
    try {
      DocumentSnapshot followerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(followerId)
          .get();
          
      String followerName = followerDoc['username'] ?? 'Someone';
      String? followerPhoto = followerDoc['photoURL'];

      await _notificationService.sendNotification(
        currentUserId: followerId,
        targetUserId: followedId,
        type: 'follow',
        senderName: followerName,
        senderPhoto: followerPhoto,
        message: 'started following you.',
      );
    } catch (e) {
      print("Error sending follow notification: $e");
    }
  }

  static Future<void> unfollowUser(String? followerId, String followedId) async {
    await FirebaseFirestore.instance
        .collection('follows')
        .doc('follow_${followerId}_$followedId')
        .delete();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(followerId)
        .collection('following')
        .doc('following_$followedId')
        .delete();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(followedId)
        .collection('followers')
        .doc('follower_$followerId')
        .delete();

    await FirebaseFirestore.instance.collection('users').doc(followedId).update({
      'followersCount': FieldValue.increment(-1),
    });
  }
}