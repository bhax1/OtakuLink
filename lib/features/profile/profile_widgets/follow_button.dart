import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/controllers/follow_controller.dart';
import 'package:otakulink/core/utils/app_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:otakulink/core/utils/secure_logger.dart';
import 'package:go_router/go_router.dart';

class FollowButton extends ConsumerStatefulWidget {
  final String targetUserId;

  const FollowButton({super.key, required this.targetUserId});

  @override
  ConsumerState<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<FollowButton> {
  bool _isLoading = false;

  Future<void> _handleFollowToggle(bool isCurrentlyFollowing) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      AppSnackBar.show(
        context,
        'You must be logged in to follow users.',
        type: SnackBarType.warning,
      );
      context.push('/login');
      return;
    }

    if (isCurrentlyFollowing) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unfollow user?'),
          content: const Text('Are you sure you want to unfollow this user?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Unfollow',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
    }

    setState(() => _isLoading = true);
    final controller = ref.read(
      followControllerProvider(widget.targetUserId).notifier,
    );

    try {
      if (isCurrentlyFollowing) {
        await controller.unfollow();
      } else {
        await controller.follow();
      }
    } catch (e, stack) {
      SecureLogger.logError("FollowButton _handleFollowToggle", e, stack);
      if (mounted) {
        AppSnackBar.show(context, 'Error: $e', type: SnackBarType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = Supabase.instance.client.auth.currentUser;

    if (currentUser == null) {
      return ElevatedButton(
        onPressed: () {
          AppSnackBar.show(
            context,
            'You must be logged in to follow users.',
            type: SnackBarType.warning,
          );
          context.push('/login');
        },
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
          minimumSize: const Size(100, 36),
        ),
        child: const Text(
          'Follow',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      );
    }

    final isFollowingAsync = ref.watch(
      followControllerProvider(widget.targetUserId),
    );

    return isFollowingAsync.when(
      loading: () => const SizedBox(
        width: 100,
        height: 36,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (err, stack) => const SizedBox(),
      data: (isFollowing) {
        return ElevatedButton(
          onPressed: _isLoading ? null : () => _handleFollowToggle(isFollowing),
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: isFollowing
                ? theme.colorScheme.surfaceContainerHighest
                : theme.colorScheme.primary,
            foregroundColor: isFollowing
                ? theme.colorScheme.secondary
                : theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
            minimumSize: const Size(100, 36),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  isFollowing ? 'Following' : 'Follow',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
        );
      },
    );
  }
}
