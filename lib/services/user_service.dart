import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/core/models/user_model.dart'; // Import your model

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // The cache is now strongly typed!
  final Map<String, UserModel> _userCache = {};

  String? get currentUserId => _auth.currentUser?.uid;

  // Returns UserModel instead of Map
  Future<UserModel?> getUserProfile(String userId,
      {bool forceRefresh = false}) async {
    if (!forceRefresh && _userCache.containsKey(userId)) {
      return _userCache[userId];
    }

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;

        // Convert to UserModel before caching
        final user = UserModel.fromMap(data, doc.id);
        _userCache[userId] = user;

        return user;
      }
    } catch (e) {
      print("Error fetching user profile: $e");
    }
    return null;
  }

  Future<String?> getUserIdByUsername(String username) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return query.docs.first.id;
      }
    } catch (e) {
      print("Error finding mentioned user: $e");
    }
    return null;
  }

  void invalidateUserCache(String userId) {
    _userCache.remove(userId);
  }

  // Uses copyWith for safe, immutable updates
  void updateCachedUser(String userId, UserModel newData) {
    if (_userCache.containsKey(userId)) {
      _userCache[userId] = newData;
    } else {
      _userCache[userId] = newData;
    }
  }

  UserModel? getCachedUserSync(String userId) {
    return _userCache[userId];
  }

  void clearAllCache() {
    _userCache.clear();
  }
}

final userServiceProvider = Provider<UserService>((ref) {
  return UserService();
});

final userProfileProvider =
    FutureProvider.family<UserModel?, String>((ref, userId) async {
  final userService = ref.watch(userServiceProvider);
  return await userService.getUserProfile(userId);
});
