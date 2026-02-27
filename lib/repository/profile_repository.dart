import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/core/models/user_model.dart';
import 'package:otakulink/services/user_service.dart';

// --- RIVERPOD PROVIDERS ---
final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(
    auth: ref.watch(firebaseAuthProvider),
    db: ref.watch(firestoreProvider),
    userService: ref.watch(userServiceProvider),
  );
});

// THE NEW EFFICIENT RAM CACHE PROVIDER
final userProfileFutureProvider =
    FutureProvider.family<UserModel?, String>((ref, uid) async {
  if (uid.isEmpty || uid == 'system') return null;
  return ref.read(profileRepositoryProvider).getUserProfileById(uid);
});

final userProfileStreamProvider =
    StreamProvider.family<UserModel?, String>((ref, uid) {
  return ref.watch(profileRepositoryProvider).getUserProfileStream(uid);
});

final recentActivityStreamProvider =
    StreamProvider.family<QuerySnapshot, String>((ref, uid) {
  return ref.watch(profileRepositoryProvider).getRecentActivityStream(uid);
});

// --- REPOSITORY ---
class ProfileRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final UserService _userService;

  ProfileRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore db,
    required UserService userService,
  })  : _auth = auth,
        _db = db,
        _userService = userService;

  String get _currentUid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception("No authenticated user found.");
    return uid;
  }

  // Gets the current user's profile
  Future<UserModel?> getUserProfile() async {
    return getUserProfileById(_currentUid);
  }

  // NEW: Gets ANY user's profile with built-in caching
  Future<UserModel?> getUserProfileById(String uid) async {
    try {
      final cachedUser = await _userService.getUserProfile(uid);
      if (cachedUser != null) return cachedUser;

      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();

      if (doc.exists && doc.data() != null) {
        final user = UserModel.fromMap(doc.data() as Map<String, dynamic>, uid);
        _userService.updateCachedUser(uid, user);
        return user;
      }
      return null;
    } catch (e) {
      throw Exception("Error fetching profile: $e");
    }
  }

  Future<void> updateUserProfile({
    required String displayName,
    required String bio,
    required String avatarUrl,
    required String bannerUrl,
  }) async {
    try {
      final currentUid = _currentUid;

      await _db.collection('users').doc(currentUid).update({
        'displayName': displayName,
        'bio': bio,
        'avatarUrl': avatarUrl,
        'bannerUrl': bannerUrl,
      });

      final currentUserModel = await _userService.getUserProfile(currentUid);
      if (currentUserModel != null) {
        final updatedUser = currentUserModel.copyWith(
          displayName: displayName,
          bio: bio,
          avatarUrl: avatarUrl,
          bannerUrl: bannerUrl,
        );
        _userService.updateCachedUser(currentUid, updatedUser);
      }
    } catch (e) {
      throw Exception("Failed to update profile: $e");
    }
  }

  Future<void> updateTopPicks(List<TopPickItem> picks) async {
    try {
      final picksData = picks.map((e) => e.toMap()).toList();
      await _db.collection('users').doc(_currentUid).update({
        'topPicks': picksData,
      });

      final currentUserModel = await _userService.getUserProfile(_currentUid);
      if (currentUserModel != null) {
        _userService.updateCachedUser(
            _currentUid, currentUserModel.copyWith(topPicks: picks));
      }
    } catch (e) {
      throw Exception("Failed to update top picks: $e");
    }
  }

  Stream<UserModel?> getUserProfileStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        final user =
            UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        _userService.updateCachedUser(doc.id, user);
        return user;
      }
      return null;
    });
  }

  Stream<QuerySnapshot> getRecentActivityStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('library')
        .orderBy('updatedAt', descending: true)
        .limit(10)
        .snapshots();
  }

  Stream<QuerySnapshot> getLibraryStream({
    required String uid,
    String? status,
    bool favoritesOnly = false,
    String sortBy = 'updatedAt',
    bool ascending = false,
    required int limit,
  }) {
    Query query = _db.collection('users').doc(uid).collection('library');

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    if (favoritesOnly) {
      query = query.where('isFavorite', isEqualTo: true);
    }

    String sortField = 'updatedAt';
    if (sortBy == 'Title') sortField = 'title';
    if (sortBy == 'Rating') sortField = 'rating';

    query = query.orderBy(sortField, descending: !ascending);
    return query.limit(limit).snapshots();
  }

  Stream<QuerySnapshot> getReviewsStream(String uid, {required int limit}) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('library')
        .where('commentary', isNotEqualTo: '')
        .orderBy('commentary')
        .limit(limit)
        .snapshots();
  }
}
