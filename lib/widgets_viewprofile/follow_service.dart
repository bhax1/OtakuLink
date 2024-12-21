import 'package:cloud_firestore/cloud_firestore.dart';

class FollowService {
  static Stream<String> getFollowStatusStream(
      String? currentUserId, String targetUserId) {
    final globalFollowStream = FirebaseFirestore.instance
        .collection('follows')
        .doc('follow_${currentUserId}_$targetUserId')
        .snapshots();

    return globalFollowStream.map((snapshot) {
      if (snapshot.exists) {
        return 'following';
      } else {
        return 'not_following';
      }
    });
  }

  static Future<void> followUser(String? followerId, String followedId) async {
    final timestamp = FieldValue.serverTimestamp();

    // Add to the global Follows collection
    await FirebaseFirestore.instance
        .collection('follows')
        .doc('follow_${followerId}_$followedId')
        .set({
      'followerId': followerId,
      'followedId': followedId,
      'timestamp': timestamp,
    });

    // Add to the follower's Following subcollection
    await FirebaseFirestore.instance
        .collection('users')
        .doc(followerId)
        .collection('following')
        .doc('following_$followedId')
        .set({
      'followedId': followedId,
      'timestamp': timestamp,
    });

    // Add to the followed user's Followers subcollection
    await FirebaseFirestore.instance
        .collection('users')
        .doc(followedId)
        .collection('followers')
        .doc('follower_$followerId')
        .set({
      'followerId': followerId,
      'timestamp': timestamp,
    });

    await FirebaseFirestore.instance
        .collection('users')
        .doc(followedId)
        .update({
      'followersCount': FieldValue.increment(1),
    });
  }

  static Future<void> unfollowUser(String? followerId, String followedId) async {
    // Remove from the global Follows collection
    await FirebaseFirestore.instance
        .collection('follows')
        .doc('follow_${followerId}_$followedId')
        .delete();

    // Remove from the follower's Following subcollection
    await FirebaseFirestore.instance
        .collection('users')
        .doc(followerId)
        .collection('following')
        .doc('following_$followedId')
        .delete();

    // Remove from the followed user's Followers subcollection
    await FirebaseFirestore.instance
        .collection('users')
        .doc(followedId)
        .collection('followers')
        .doc('follower_$followerId')
        .delete();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(followedId)
        .update({
      'followersCount': FieldValue.increment(-1),
    });
  }
}
