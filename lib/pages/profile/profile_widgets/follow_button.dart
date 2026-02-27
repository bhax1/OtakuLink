import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otakulink/repository/follow_repository.dart';

class FollowButton extends ConsumerStatefulWidget {
  final String targetUserId;

  const FollowButton({super.key, required this.targetUserId});

  @override
  ConsumerState<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<FollowButton> {
  bool _isLoading = false;

  Future<void> _toggleFollow(bool isCurrentlyFollowing) async {
    setState(() => _isLoading = true);
    final repo = ref.read(followRepositoryProvider);

    try {
      if (isCurrentlyFollowing) {
        await repo.unfollowUser(widget.targetUserId);
      } else {
        await repo.followUser(widget.targetUserId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFollowingAsync =
        ref.watch(isFollowingProvider(widget.targetUserId));

    return isFollowingAsync.when(
      loading: () => const SizedBox(
        width: 100,
        height: 36,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (err, stack) => const SizedBox(),
      data: (isFollowing) {
        return ElevatedButton(
          onPressed: _isLoading ? null : () => _toggleFollow(isFollowing),
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: isFollowing
                ? theme.colorScheme.surfaceContainerHighest
                : theme.colorScheme.primary,
            foregroundColor: isFollowing
                ? theme.colorScheme.secondary
                : theme.colorScheme.onPrimary,
            // Changed from StadiumBorder to sharp RoundedRectangle
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
            minimumSize: const Size(100, 36),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(
                  isFollowing ? 'Following' : 'Follow',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
        );
      },
    );
  }
}
