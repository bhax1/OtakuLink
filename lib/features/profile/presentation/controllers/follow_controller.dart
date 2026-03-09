import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/follow_repository.dart';

class FollowController extends FamilyAsyncNotifier<bool, String> {
  @override
  FutureOr<bool> build(String arg) {
    // Watch the repository so this controller rebuilds when the user changes
    ref.watch(followRepositoryProvider);
    return _fetchFollowStatus(arg);
  }

  Future<bool> _fetchFollowStatus(String targetUserId) async {
    final repo = ref.read(followRepositoryProvider);
    // Listen to the stream once to get the current state
    final stream = repo.isFollowing(targetUserId);
    return await stream.first;
  }

  Future<void> follow() async {
    final targetUserId = arg;
    final repo = ref.read(followRepositoryProvider);

    // Optimistic update
    state = const AsyncValue.data(true);

    try {
      await repo.followUser(targetUserId);
    } catch (e) {
      // Rollback on failure
      state = const AsyncValue.data(false);
      rethrow;
    }
  }

  Future<void> unfollow() async {
    final targetUserId = arg;
    final repo = ref.read(followRepositoryProvider);

    // Optimistic update
    state = const AsyncValue.data(false);

    try {
      await repo.unfollowUser(targetUserId);
    } catch (e) {
      // Rollback on failure
      state = const AsyncValue.data(true);
      rethrow;
    }
  }
}

final followControllerProvider =
    AsyncNotifierProvider.family<FollowController, bool, String>(() {
      return FollowController();
    });
