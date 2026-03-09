import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:otakulink/features/profile/domain/entities/profile_entities.dart';
import 'package:otakulink/features/profile/data/repositories/profile_repository.dart';
import 'package:otakulink/core/providers/supabase_provider.dart';
import 'package:otakulink/core/utils/secure_logger.dart';

// --- RIVERPOD PROVIDERS ---

final followRepositoryProvider = Provider<FollowRepository>((ref) {
  return FollowRepository(
    client: ref.watch(supabaseClientProvider),
    profileRepo: ref.watch(profileRepositoryProvider),
  );
});

final isFollowingProvider = StreamProvider.family<bool, String>((
  ref,
  targetUserId,
) {
  return ref.watch(followRepositoryProvider).isFollowing(targetUserId);
});

final isFollowedByProvider = StreamProvider.family<bool, String>((
  ref,
  targetUserId,
) {
  return ref.watch(followRepositoryProvider).isFollowedBy(targetUserId);
});

final followersListProvider =
    FutureProvider.family<List<ProfileEntity>, String>((ref, userId) {
      return ref.watch(followRepositoryProvider).getFollowers(userId);
    });

final followingListProvider =
    FutureProvider.family<List<ProfileEntity>, String>((ref, userId) {
      return ref.watch(followRepositoryProvider).getFollowing(userId);
    });

final mutualIdsFutureProvider = FutureProvider.family<List<String>, String>((
  ref,
  userId,
) {
  return ref.watch(followRepositoryProvider).getMutualIds(userId);
});

class FollowRepository {
  final SupabaseClient _client;
  final ProfileRepository _profileRepo;

  FollowRepository({
    required SupabaseClient client,
    required ProfileRepository profileRepo,
  }) : _client = client,
       _profileRepo = profileRepo;

  String get _currentUid {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw Exception("No authenticated user found.");
    return uid;
  }

  Future<void> followUser(String targetUserId) async {
    final currentUid = _currentUid;
    if (currentUid == targetUserId) {
      throw Exception("You cannot follow yourself.");
    }

    await _client.from('user_follows').upsert({
      'follower_id': currentUid,
      'following_id': targetUserId,
    });

    _sendFollowNotification(currentUid, targetUserId);
  }

  Future<void> unfollowUser(String targetUserId) async {
    final currentUid = _currentUid;
    await _client
        .from('user_follows')
        .delete()
        .eq('follower_id', currentUid)
        .eq('following_id', targetUserId);
  }

  Stream<bool> isFollowing(String targetUserId) {
    if (_client.auth.currentUser == null) return Stream.value(false);

    return _client
        .from('user_follows')
        .stream(primaryKey: ['follower_id', 'following_id'])
        .eq('follower_id', _currentUid)
        .map((docs) => docs.any((doc) => doc['following_id'] == targetUserId));
  }

  Stream<bool> isFollowedBy(String targetUserId) {
    if (_client.auth.currentUser == null) return Stream.value(false);

    return _client
        .from('user_follows')
        .stream(primaryKey: ['follower_id', 'following_id'])
        .eq('follower_id', targetUserId)
        .map((docs) => docs.any((doc) => doc['following_id'] == _currentUid));
  }

  Future<void> _sendFollowNotification(
    String currentUid,
    String targetUserId,
  ) async {
    try {
      await _client.from('notifications').insert({
        'user_id': targetUserId,
        'actor_id': currentUid,
        'type': 'follow',
      });
    } catch (e, stack) {
      SecureLogger.logError(
        "FollowRepository _sendFollowNotification",
        e,
        stack,
      );
    }
  }

  Future<List<ProfileEntity>> getFollowers(String targetUserId) async {
    final response = await _client
        .from('user_follows')
        .select('follower_id')
        .eq('following_id', targetUserId)
        .order('created_at', ascending: false)
        .limit(50);

    if (response.isEmpty) return [];

    final userFutures = response.map((row) async {
      return await _profileRepo.getUserProfileById(
        row['follower_id'] as String,
      );
    });

    final users = await Future.wait(userFutures);
    return users.whereType<ProfileEntity>().toList();
  }

  Future<List<ProfileEntity>> getFollowing(String targetUserId) async {
    final response = await _client
        .from('user_follows')
        .select('following_id')
        .eq('follower_id', targetUserId)
        .order('created_at', ascending: false)
        .limit(50);

    if (response.isEmpty) return [];

    final userFutures = response.map((row) async {
      return await _profileRepo.getUserProfileById(
        row['following_id'] as String,
      );
    });

    final users = await Future.wait(userFutures);
    return users.whereType<ProfileEntity>().toList();
  }

  Future<List<String>> getMutualIds(String targetUserId) async {
    final followingSnap = await _client
        .from('user_follows')
        .select('following_id')
        .eq('follower_id', targetUserId);

    final followingIds = followingSnap
        .map((row) => row['following_id'] as String)
        .toSet();
    if (followingIds.isEmpty) return [];

    final followersSnap = await _client
        .from('user_follows')
        .select('follower_id')
        .eq('following_id', targetUserId);

    final followerIds = followersSnap
        .map((row) => row['follower_id'] as String)
        .toSet();
    final mutuals = followingIds.intersection(followerIds);

    return mutuals.toList();
  }
}
