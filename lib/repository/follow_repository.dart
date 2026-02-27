import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/core/models/user_model.dart';
import 'package:otakulink/services/notification_service.dart';
import 'package:otakulink/services/user_service.dart';

// --- RIVERPOD PROVIDERS ---

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

// Update the provider to inject UserService
final followRepositoryProvider = Provider<FollowRepository>((ref) {
  return FollowRepository(
    auth: FirebaseAuth.instance,
    db: FirebaseFirestore.instance,
    notificationService: ref.watch(notificationServiceProvider),
    userService: ref.watch(userServiceProvider),
  );
});

final isFollowingProvider =
    StreamProvider.family<bool, String>((ref, targetUserId) {
  return ref.watch(followRepositoryProvider).isFollowing(targetUserId);
});

final isFollowedByProvider =
    StreamProvider.family<bool, String>((ref, targetUserId) {
  return ref.watch(followRepositoryProvider).isFollowedBy(targetUserId);
});

final followersListProvider =
    FutureProvider.family<List<UserModel>, String>((ref, userId) {
  return ref.watch(followRepositoryProvider).getFollowers(userId);
});

final followingListProvider =
    FutureProvider.family<List<UserModel>, String>((ref, userId) {
  return ref.watch(followRepositoryProvider).getFollowing(userId);
});

final mutualIdsFutureProvider =
    FutureProvider.family<List<String>, String>((ref, userId) {
  return ref.watch(followRepositoryProvider).getMutualIds(userId);
});

class FollowRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final NotificationService _notificationService;
  final UserService _userService; // Add to repository

  FollowRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore db,
    required NotificationService notificationService,
    required UserService userService, // Add to constructor
  })  : _auth = auth,
        _db = db,
        _notificationService = notificationService,
        _userService = userService;

  String get _currentUid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("No authenticated user found.");
    return uid;
  }

  Future<void> followUser(String targetUserId) async {
    final currentUid = _currentUid;
    if (currentUid == targetUserId)
      throw Exception("You cannot follow yourself.");

    final batch = _db.batch();
    final timestamp = FieldValue.serverTimestamp();

    final myFollowingRef = _db
        .collection('users')
        .doc(currentUid)
        .collection('following')
        .doc(targetUserId);
    batch.set(
        myFollowingRef, {'followedId': targetUserId, 'timestamp': timestamp});

    final targetFollowerRef = _db
        .collection('users')
        .doc(targetUserId)
        .collection('followers')
        .doc(currentUid);
    batch.set(
        targetFollowerRef, {'followerId': currentUid, 'timestamp': timestamp});

    final myUserRef = _db.collection('users').doc(currentUid);
    batch.update(myUserRef, {'followingCount': FieldValue.increment(1)});

    final targetUserRef = _db.collection('users').doc(targetUserId);
    batch.update(targetUserRef, {'followerCount': FieldValue.increment(1)});

    await batch.commit();
    _sendFollowNotification(currentUid, targetUserId);
  }

  Future<void> unfollowUser(String targetUserId) async {
    final currentUid = _currentUid;
    final batch = _db.batch();

    final myFollowingRef = _db
        .collection('users')
        .doc(currentUid)
        .collection('following')
        .doc(targetUserId);
    batch.delete(myFollowingRef);

    final targetFollowerRef = _db
        .collection('users')
        .doc(targetUserId)
        .collection('followers')
        .doc(currentUid);
    batch.delete(targetFollowerRef);

    final myUserRef = _db.collection('users').doc(currentUid);
    batch.update(myUserRef, {'followingCount': FieldValue.increment(-1)});

    final targetUserRef = _db.collection('users').doc(targetUserId);
    batch.update(targetUserRef, {'followerCount': FieldValue.increment(-1)});

    await batch.commit();
  }

  Stream<bool> isFollowing(String targetUserId) {
    if (_auth.currentUser == null) return Stream.value(false);

    return _db
        .collection('users')
        .doc(_currentUid)
        .collection('following')
        .doc(targetUserId)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  Stream<bool> isFollowedBy(String targetUserId) {
    if (_auth.currentUser == null) return Stream.value(false);

    return _db
        .collection('users')
        .doc(_currentUid)
        .collection('followers')
        .doc(targetUserId)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  Future<void> _sendFollowNotification(
      String currentUid, String targetUserId) async {
    try {
      await _notificationService.sendNotification(
        currentUserId: currentUid,
        targetUserId: targetUserId,
        type: 'follow',
        message: 'started following you.',
      );
    } catch (e) {
      print("Error sending follow notification: $e");
    }
  }

  Future<List<UserModel>> getFollowers(String targetUserId) async {
    final snapshot = await _db
        .collection('users')
        .doc(targetUserId)
        .collection('followers')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .get();

    if (snapshot.docs.isEmpty) return [];

    final userFutures = snapshot.docs.map((doc) async {
      final userModel = await _userService.getUserProfile(doc.id);
      return userModel;
    });

    final users = await Future.wait(userFutures);
    return users.whereType<UserModel>().toList();
  }

  Future<List<UserModel>> getFollowing(String targetUserId) async {
    final snapshot = await _db
        .collection('users')
        .doc(targetUserId)
        .collection('following')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .get();

    if (snapshot.docs.isEmpty) return [];

    final userFutures = snapshot.docs.map((doc) async {
      final userModel = await _userService.getUserProfile(doc.id);
      return userModel;
    });

    final users = await Future.wait(userFutures);
    return users.whereType<UserModel>().toList();
  }

  Future<List<String>> getMutualIds(String targetUserId) async {
    final followingSnap = await _db
        .collection('users')
        .doc(targetUserId)
        .collection('following')
        .get();

    final followingIds = followingSnap.docs.map((doc) => doc.id).toSet();
    if (followingIds.isEmpty) return [];

    final followersSnap = await _db
        .collection('users')
        .doc(targetUserId)
        .collection('followers')
        .get();

    final followerIds = followersSnap.docs.map((doc) => doc.id).toSet();
    final mutuals = followingIds.intersection(followerIds);

    return mutuals.toList();
  }
}
